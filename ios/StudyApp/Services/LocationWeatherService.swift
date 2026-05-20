import CoreLocation
import Foundation

@MainActor
final class LocationWeatherService: NSObject {
    private let manager = CLLocationManager()
    private let weatherService: WeatherKitWeatherService
    private let userDefaults: UserDefaults
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private let cacheKey = "timerAmbientWeatherSnapshot"
    private let weatherFailureCooldownKey = "timerAmbientWeatherFailureCooldownUntil"
    private let cacheLifetime: TimeInterval = 6 * 60 * 60
    private let weatherFailureCooldown: TimeInterval = 30 * 60

    init(weatherService: WeatherKitWeatherService = WeatherKitWeatherService(), userDefaults: UserDefaults = .standard) {
        self.weatherService = weatherService
        self.userDefaults = userDefaults
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func resolve(mode: TimerVisualMode, force: Bool = false, now: Date = Date()) async -> TimerAmbientContext {
        guard mode == .auto else {
            return TimerAmbientResolver.resolve(mode: mode, snapshot: cachedSnapshot(), now: now)
        }

        if !force, let cached = cachedSnapshot(), now.timeIntervalSince(cached.fetchedAt) < cacheLifetime {
            return TimerAmbientResolver.resolve(mode: .auto, snapshot: cached, now: now, source: .cache)
        }

        if let cooldownUntil = weatherFailureCooldownUntil(), now < cooldownUntil {
            if let cached = cachedSnapshot() {
                return TimerAmbientResolver.resolve(
                    mode: .auto,
                    snapshot: cached,
                    now: now,
                    source: .cache,
                    errorMessage: LocationWeatherError.weatherTemporarilyUnavailable.localizedDescription
                )
            }
            return TimerAmbientResolver.resolve(
                mode: .auto,
                snapshot: nil,
                now: now,
                source: .clock,
                errorMessage: LocationWeatherError.weatherTemporarilyUnavailable.localizedDescription
            )
        }

        do {
            let location = try await requestCurrentLocation()
            let snapshot = try await weatherService.fetch(for: location)
            save(snapshot)
            clearWeatherFailureCooldown()
            return TimerAmbientResolver.resolve(mode: .auto, snapshot: snapshot, now: now, source: .weather)
        } catch {
            if Self.isWeatherAuthorizationError(error) {
                saveWeatherFailureCooldown(until: now.addingTimeInterval(weatherFailureCooldown))
            }
            if let cached = cachedSnapshot() {
                return TimerAmbientResolver.resolve(
                    mode: .auto,
                    snapshot: cached,
                    now: now,
                    source: .cache,
                    errorMessage: error.localizedDescription
                )
            }
            return TimerAmbientResolver.resolve(
                mode: .auto,
                snapshot: nil,
                now: now,
                source: .clock,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func requestCurrentLocation() async throws -> CLLocation {
        if let locationContinuation {
            locationContinuation.resume(throwing: LocationWeatherError.locationRequestAlreadyRunning)
            self.locationContinuation = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                finishLocationRequest(with: .failure(LocationWeatherError.permissionDenied))
            @unknown default:
                finishLocationRequest(with: .failure(LocationWeatherError.permissionDenied))
            }
        }
    }

    private func cachedSnapshot() -> TimerAmbientWeatherSnapshot? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(TimerAmbientWeatherSnapshot.self, from: data)
    }

    private func save(_ snapshot: TimerAmbientWeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    private func weatherFailureCooldownUntil() -> Date? {
        userDefaults.object(forKey: weatherFailureCooldownKey) as? Date
    }

    private func saveWeatherFailureCooldown(until date: Date) {
        userDefaults.set(date, forKey: weatherFailureCooldownKey)
    }

    private func clearWeatherFailureCooldown() {
        userDefaults.removeObject(forKey: weatherFailureCooldownKey)
    }

    private static func isWeatherAuthorizationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain.contains("WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors") && nsError.code == 2
    }

    private func finishLocationRequest(with result: Result<CLLocation, Error>) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension LocationWeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.manager.requestLocation()
            case .denied, .restricted:
                finishLocationRequest(with: .failure(LocationWeatherError.permissionDenied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        let altitude = locations.last?.altitude ?? 0
        let horizontalAccuracy = locations.last?.horizontalAccuracy ?? kCLLocationAccuracyThreeKilometers
        let verticalAccuracy = locations.last?.verticalAccuracy ?? -1
        let timestamp = locations.last?.timestamp ?? Date()
        Task { @MainActor in
            guard let coordinate else {
                finishLocationRequest(with: .failure(LocationWeatherError.locationUnavailable))
                return
            }
            let location = CLLocation(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: horizontalAccuracy,
                verticalAccuracy: verticalAccuracy,
                timestamp: timestamp
            )
            finishLocationRequest(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finishLocationRequest(with: .failure(LocationWeatherError.locationUnavailable))
        }
    }
}

enum LocationWeatherError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case locationRequestAlreadyRunning
    case weatherTemporarilyUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置情報の許可が必要です"
        case .locationUnavailable:
            return "現在地を取得できませんでした"
        case .locationRequestAlreadyRunning:
            return "現在地を取得中です"
        case .weatherTemporarilyUnavailable:
            return "天気情報を一時的に取得できません"
        }
    }
}
