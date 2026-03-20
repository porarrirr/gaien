import Foundation

enum BookApiError: LocalizedError {
    case bookNotFound
    case httpError(Int)
    case networkError(String)
    case parseError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .bookNotFound:
            return "書籍が見つかりませんでした"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        case .networkError(let message), .parseError(let message), .unknown(let message):
            return message
        }
    }
}

final class GoogleBooksService: BookSearchRepository {
    private let session: URLSession
    private let apiKey: String?

    init(session: URLSession = .shared, apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_BOOKS_API_KEY"]) {
        self.session = session
        self.apiKey = apiKey
    }

    func searchByIsbn(_ isbn: String) async throws -> BookInfo {
        let query = "isbn:\(isbn.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? isbn)"
        let request = try makeRequest(query: query)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
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
        return try parseBookInfo(volumeInfo)
    }

    func searchByTitle(_ title: String) async throws -> [BookInfo] {
        let query = "intitle:\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)"
        let request = try makeRequest(query: query, maxResults: 10)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BookApiError.parseError("レスポンスの解析に失敗しました")
        }
        guard let items = json["items"] as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item in
            guard let volumeInfo = item["volumeInfo"] as? [String: Any] else {
                return nil
            }
            return try? parseBookInfo(volumeInfo)
        }
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

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BookApiError.networkError("通信に失敗しました")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BookApiError.httpError(http.statusCode)
        }
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
}
