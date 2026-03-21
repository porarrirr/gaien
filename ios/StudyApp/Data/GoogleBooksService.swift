import Foundation

enum BookApiError: LocalizedError {
    case bookNotFound
    case rateLimited(retryAfter: TimeInterval?)
    case httpError(Int)
    case networkError(String)
    case parseError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .bookNotFound:
            return "書籍が見つかりませんでした"
        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                return "書籍検索が混み合っています。約\(Int(ceil(retryAfter)))秒待ってから再試行してください。"
            }
            return "書籍検索が混み合っています。少し待ってから再試行してください。"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        case .networkError(let message), .parseError(let message), .unknown(let message):
            return message
        }
    }
}

private actor GoogleBooksLookupStore {
    private struct CachedValue<T> {
        let value: T
        let expiresAt: Date
    }

    private var isbnCache: [String: CachedValue<BookInfo>] = [:]
    private var titleCache: [String: CachedValue<[BookInfo]>] = [:]
    private var isbnTasks: [String: Task<BookInfo, Error>] = [:]
    private var titleTasks: [String: Task<[BookInfo], Error>] = [:]
    private var rateLimitedUntil: Date?

    func cachedBook(for key: String, now: Date = Date()) -> BookInfo? {
        guard let cached = isbnCache[key], cached.expiresAt > now else {
            isbnCache[key] = nil
            return nil
        }
        return cached.value
    }

    func cachedBooks(for key: String, now: Date = Date()) -> [BookInfo]? {
        guard let cached = titleCache[key], cached.expiresAt > now else {
            titleCache[key] = nil
            return nil
        }
        return cached.value
    }

    func activeIsbnTask(for key: String) -> Task<BookInfo, Error>? {
        isbnTasks[key]
    }

    func activeTitleTask(for key: String) -> Task<[BookInfo], Error>? {
        titleTasks[key]
    }

    func storeIsbnTask(_ task: Task<BookInfo, Error>, for key: String) {
        isbnTasks[key] = task
    }

    func storeTitleTask(_ task: Task<[BookInfo], Error>, for key: String) {
        titleTasks[key] = task
    }

    func cacheBook(_ book: BookInfo, for key: String, ttl: TimeInterval, now: Date = Date()) {
        isbnCache[key] = CachedValue(value: book, expiresAt: now.addingTimeInterval(ttl))
    }

    func cacheBooks(_ books: [BookInfo], for key: String, ttl: TimeInterval, now: Date = Date()) {
        titleCache[key] = CachedValue(value: books, expiresAt: now.addingTimeInterval(ttl))
    }

    func clearIsbnTask(for key: String) {
        isbnTasks[key] = nil
    }

    func clearTitleTask(for key: String) {
        titleTasks[key] = nil
    }

    func currentRetryAfter(now: Date = Date()) -> TimeInterval? {
        guard let rateLimitedUntil, rateLimitedUntil > now else {
            self.rateLimitedUntil = nil
            return nil
        }
        return rateLimitedUntil.timeIntervalSince(now)
    }

    func setRateLimited(until date: Date?) {
        rateLimitedUntil = date
    }
}

final class GoogleBooksService: BookSearchRepository {
    private static let cacheTTL: TimeInterval = 60 * 30
    private static let fallbackRateLimitCooldown: TimeInterval = 15

    private let session: URLSession
    private let apiKey: String?
    private let lookupStore = GoogleBooksLookupStore()

    init(session: URLSession = .shared, apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_BOOKS_API_KEY"]) {
        self.session = session
        self.apiKey = apiKey
    }

    func searchByIsbn(_ isbn: String) async throws -> BookInfo {
        let normalizedIsbn = normalizeLookupToken(isbn)
        guard !normalizedIsbn.isEmpty else {
            throw BookApiError.parseError("ISBNを入力してください")
        }

        if let cached = await lookupStore.cachedBook(for: normalizedIsbn) {
            return cached
        }

        if let retryAfter = await lookupStore.currentRetryAfter() {
            throw BookApiError.rateLimited(retryAfter: retryAfter)
        }

        if let existingTask = await lookupStore.activeIsbnTask(for: normalizedIsbn) {
            return try await existingTask.value
        }

        let task = Task<BookInfo, Error> {
            defer { Task { await self.lookupStore.clearIsbnTask(for: normalizedIsbn) } }

            let query = "isbn:\(normalizedIsbn.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalizedIsbn)"
            let request = try self.makeRequest(query: query)
            let (data, response) = try await self.session.data(for: request)
            try await self.validate(response: response)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BookApiError.parseError("レスポンスの解析に失敗しました")
            }
            guard
                let items = json["items"] as? [[String: Any]],
                let first = items.first,
                let volumeInfo = first["volumeInfo"] as? [String: Any]
            else {
                throw BookApiError.bookNotFound
            }
            let book = try self.parseBookInfo(volumeInfo)
            await self.lookupStore.cacheBook(book, for: normalizedIsbn, ttl: Self.cacheTTL)
            return book
        }

        await lookupStore.storeIsbnTask(task, for: normalizedIsbn)
        return try await task.value
    }

    func searchByTitle(_ title: String) async throws -> [BookInfo] {
        let normalizedTitle = normalizeLookupToken(title)
        guard !normalizedTitle.isEmpty else {
            return []
        }

        if let cached = await lookupStore.cachedBooks(for: normalizedTitle) {
            return cached
        }

        if let retryAfter = await lookupStore.currentRetryAfter() {
            throw BookApiError.rateLimited(retryAfter: retryAfter)
        }

        if let existingTask = await lookupStore.activeTitleTask(for: normalizedTitle) {
            return try await existingTask.value
        }

        let task = Task<[BookInfo], Error> {
            defer { Task { await self.lookupStore.clearTitleTask(for: normalizedTitle) } }

            let query = "intitle:\(normalizedTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalizedTitle)"
            let request = try self.makeRequest(query: query, maxResults: 10)
            let (data, response) = try await self.session.data(for: request)
            try await self.validate(response: response)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BookApiError.parseError("レスポンスの解析に失敗しました")
            }
            guard let items = json["items"] as? [[String: Any]] else {
                await self.lookupStore.cacheBooks([], for: normalizedTitle, ttl: Self.cacheTTL)
                return []
            }
            let books: [BookInfo] = items.compactMap { item in
                guard let volumeInfo = item["volumeInfo"] as? [String: Any] else {
                    return nil
                }
                do {
                    return try self.parseBookInfo(volumeInfo)
                } catch {
                    print("[StudyApp] Skipping book entry during title search: \(error.localizedDescription)")
                    return nil
                }
            }
            await self.lookupStore.cacheBooks(books, for: normalizedTitle, ttl: Self.cacheTTL)
            return books
        }

        await lookupStore.storeTitleTask(task, for: normalizedTitle)
        return try await task.value
    }

    private func makeRequest(query: String, maxResults: Int? = nil) throws -> URLRequest {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        var items = [URLQueryItem(name: "q", value: query)]
        if let apiKey {
            items.append(URLQueryItem(name: "key", value: apiKey))
        }
        if let maxResults {
            items.append(URLQueryItem(name: "maxResults", value: "\(maxResults)"))
        }
        components?.queryItems = items
        guard let url = components?.url else {
            throw BookApiError.unknown("Google Books APIのURL生成に失敗しました")
        }
        return URLRequest(url: url)
    }

    private func validate(response: URLResponse) async throws {
        guard let http = response as? HTTPURLResponse else {
            throw BookApiError.networkError("通信に失敗しました")
        }
        if http.statusCode == 429 {
            let retryAfter = retryAfterInterval(from: http)
            let until = Date().addingTimeInterval(retryAfter ?? Self.fallbackRateLimitCooldown)
            await lookupStore.setRateLimited(until: until)
            throw BookApiError.rateLimited(retryAfter: retryAfter ?? Self.fallbackRateLimitCooldown)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BookApiError.httpError(http.statusCode)
        }
        await lookupStore.setRateLimited(until: nil)
    }

    private func parseBookInfo(_ volumeInfo: [String: Any]) throws -> BookInfo {
        let title = volumeInfo["title"] as? String ?? ""
        guard !title.isEmpty else {
            throw BookApiError.parseError("書籍タイトルを取得できませんでした")
        }

        let authors = volumeInfo["authors"] as? [String] ?? []
        let publisher = volumeInfo["publisher"] as? String
        let publishedDate = volumeInfo["publishedDate"] as? String
        let pageCount = volumeInfo["pageCount"] as? Int
        let imageLinks = volumeInfo["imageLinks"] as? [String: Any]
        let thumbnailURL = imageLinks?["thumbnail"] as? String

        return BookInfo(
            title: title,
            authors: authors,
            publisher: publisher,
            publishedDate: publishedDate,
            pageCount: pageCount.map { $0 > 0 ? $0 : nil } ?? nil,
            thumbnailURL: thumbnailURL
        )
    }

    private func normalizeLookupToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private func retryAfterInterval(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(value), seconds > 0 {
            return seconds
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else {
            return nil
        }
        return max(0, date.timeIntervalSinceNow)
    }
}
