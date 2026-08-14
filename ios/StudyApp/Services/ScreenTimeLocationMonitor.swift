import CoreLocation
import Foundation
import OSLog

/// Screen Time の場所ルール用ジオフェンス。
///
/// 拡張では位置を取れないので、入退の結果だけを App Group に書き、
/// 既存の `applyCurrentPolicy()` が読む。常時 GPS は使わず、
/// 起動・前面復帰と大きな移動のときだけ現在地で円の内外を確定する。
final class ScreenTimeLocationMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = ScreenTimeLocationMonitor()

    private static let logger = Logger(
        subsystem: "com.studyapp.ios",
        category: "ScreenTimeLocation"
    )
    private static let coordinatePresenceOverrideInterval: TimeInterval = 120
    private static let regionCoordinateEpsilon = 0.000001
    private static let refinementAccuracyMeters: CLLocationDistance = 40

    private let manager: CLLocationManager
    private let accessEngine = ScreenTimeAccessEngine()
    private var authorizationContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []
    private var currentLocationContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    private var lastCoordinatePresenceResolvedAt: Date?
    private var isRequestingLocation = false
    private var didRequestAccuracyRefinement = false

    private override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    var isMonitoringAvailable: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    }

    /// 終了状態からの領域イベントを取りこぼさないよう、起動直後に呼ぶ。
    func start() {
        syncFromSavedSettings()
    }

    func syncFromSavedSettings() {
        sync(settings: ScreenTimeFocusShared.loadSettings())
    }

    func sync(settings: ScreenTimeFocusSettings) {
        prunePresence(using: settings)

        let zones = settings.enabledLocationZones
        guard settings.isEnabled,
              settings.locationRestrictionEnabled,
              hasAlwaysAuthorization,
              isMonitoringAvailable,
              !zones.isEmpty else {
            stopSignificantChangeMonitoring()
            stopMonitoredRegions()
            lastCoordinatePresenceResolvedAt = nil
            didRequestAccuracyRefinement = false
            ScreenTimeFocusShared.clearLocationPresence()
            applyPolicy()
            return
        }

        ScreenTimeFocusShared.setLocationMonitoringArmed(true)

        let desiredIDs = Set(zones.map(\.regionIdentifier))
        for region in monitoredLocationRegions where !desiredIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }

        for zone in zones {
            let region = makeRegion(for: zone)
            if let existing = monitoredLocationRegions.first(where: { $0.identifier == region.identifier }),
               isSameRegion(existing, as: region) {
                continue
            }
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
        }

        startSignificantChangeMonitoringIfNeeded()
        requestCoordinatePresenceRefresh()
    }

    /// アプリが前面に戻ったとき、ジオフェンスの遅延を待たず現在地で判定し直す。
    func refreshPresenceFromCurrentLocation() async {
        guard ScreenTimeFocusShared.isLocationMonitoringArmed else { return }
        didRequestAccuracyRefinement = false
        _ = await requestCurrentLocation()
    }

    func requestAlwaysAuthorization() async -> CLAuthorizationStatus {
        let current = authorizationStatus
        switch current {
        case .authorizedAlways:
            return current
        case .denied, .restricted:
            return current
        case .notDetermined:
            let whenInUse = await requestAuthorization {
                self.manager.requestWhenInUseAuthorization()
            }
            if whenInUse == .authorizedAlways {
                return whenInUse
            }
            guard whenInUse == .authorizedWhenInUse else {
                return whenInUse
            }
            return await requestAuthorization {
                self.manager.requestAlwaysAuthorization()
            }
        case .authorizedWhenInUse:
            return await requestAuthorization {
                self.manager.requestAlwaysAuthorization()
            }
        @unknown default:
            return current
        }
    }

    func requestCurrentLocation() async -> CLLocation? {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        default:
            return nil
        }
        return await withCheckedContinuation { continuation in
            currentLocationContinuations.append(continuation)
            startOneShotLocationRequestIfNeeded()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        finishAuthorizationRequest(with: manager.authorizationStatus)
        syncFromSavedSettings()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        updatePresence(regionIdentifier: region.identifier, isInside: true)
        requestCoordinatePresenceRefresh()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        updatePresence(regionIdentifier: region.identifier, isInside: false)
        requestCoordinatePresenceRefresh()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        if let resolvedAt = lastCoordinatePresenceResolvedAt,
           Date().timeIntervalSince(resolvedAt) < Self.coordinatePresenceOverrideInterval {
            return
        }
        switch state {
        case .inside:
            updatePresence(regionIdentifier: region.identifier, isInside: true)
        case .outside:
            updatePresence(regionIdentifier: region.identifier, isInside: false)
        case .unknown:
            requestCoordinatePresenceRefresh()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        finishCurrentLocationRequest(with: location)
        if let location {
            applyCoordinatePresence(from: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Self.logger.error("Location monitor failed: \(error.localizedDescription, privacy: .public)")
        finishCurrentLocationRequest(with: nil)
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        Self.logger.error(
            """
            Region monitoring failed for \(region?.identifier ?? "unknown", privacy: .public): \
            \(error.localizedDescription, privacy: .public)
            """
        )
    }

    private func requestAuthorization(
        _ request: @escaping () -> Void
    ) async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            authorizationContinuations.append(continuation)
            request()
        }
    }

    private func finishAuthorizationRequest(with status: CLAuthorizationStatus) {
        let pending = authorizationContinuations
        authorizationContinuations.removeAll()
        pending.forEach { $0.resume(returning: status) }
    }

    private func requestCoordinatePresenceRefresh() {
        didRequestAccuracyRefinement = false
        startOneShotLocationRequestIfNeeded()
    }

    private func startOneShotLocationRequestIfNeeded() {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        default:
            return
        }
        guard !isRequestingLocation else { return }
        isRequestingLocation = true
        manager.requestLocation()
    }

    private func finishCurrentLocationRequest(with location: CLLocation?) {
        isRequestingLocation = false
        let pending = currentLocationContinuations
        currentLocationContinuations.removeAll()
        pending.forEach { $0.resume(returning: location) }
    }

    private var monitoredLocationRegions: [CLCircularRegion] {
        manager.monitoredRegions.compactMap { region in
            guard let circular = region as? CLCircularRegion,
                  circular.identifier.hasPrefix(ScreenTimeFocusShared.locationRegionIdentifierPrefix) else {
                return nil
            }
            return circular
        }
    }

    private func makeRegion(for zone: FocusLocationZone) -> CLCircularRegion {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude),
            radius: CLLocationDistance(zone.radiusMeters),
            identifier: zone.regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    private func isSameRegion(_ existing: CLCircularRegion, as desired: CLCircularRegion) -> Bool {
        abs(existing.center.latitude - desired.center.latitude) < Self.regionCoordinateEpsilon
            && abs(existing.center.longitude - desired.center.longitude) < Self.regionCoordinateEpsilon
            && abs(existing.radius - desired.radius) < 1
    }

    private func startSignificantChangeMonitoringIfNeeded() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    private func stopSignificantChangeMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    private func stopMonitoredRegions() {
        for region in monitoredLocationRegions {
            manager.stopMonitoring(for: region)
        }
    }

    private func prunePresence(using settings: ScreenTimeFocusSettings) {
        var presence = ScreenTimeFocusShared.loadLocationPresence()
        let validIDs = Set(settings.enabledLocationZones.map(\.id))
        let pruned = presence.insideZoneIDs.intersection(validIDs)
        guard pruned != presence.insideZoneIDs else { return }
        presence.insideZoneIDs = pruned
        presence.updatedAt = ScreenTimeDateMath.epochMilliseconds(for: Date())
        ScreenTimeFocusShared.saveLocationPresence(presence)
    }

    private func applyCoordinatePresence(from location: CLLocation) {
        let settings = ScreenTimeFocusShared.loadSettings()
        let zones = settings.enabledLocationZones
        guard settings.isEnabled, settings.locationRestrictionEnabled, !zones.isEmpty else {
            return
        }

        let previous = ScreenTimeFocusShared.loadLocationPresence().insideZoneIDs
        let nextIDs = FocusLocationPresenceResolver.insideZoneIDs(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            zones: zones,
            previous: previous
        )

        if let nextIDs {
            lastCoordinatePresenceResolvedAt = Date()
            replacePresence(insideZoneIDs: nextIDs)
        }

        let needsRefinement = nextIDs == nil || zones.contains { zone in
            FocusLocationPresenceResolver.membership(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                zone: zone
            ) == .uncertain
        }
        if needsRefinement, location.horizontalAccuracy > Self.refinementAccuracyMeters {
            requestAccuracyRefinementIfNeeded()
        } else {
            didRequestAccuracyRefinement = false
        }
    }

    private func requestAccuracyRefinementIfNeeded() {
        guard !didRequestAccuracyRefinement else { return }
        didRequestAccuracyRefinement = true
        startOneShotLocationRequestIfNeeded()
    }

    private func updatePresence(regionIdentifier: String, isInside: Bool) {
        guard let zoneID = FocusLocationZone.zoneID(fromRegionIdentifier: regionIdentifier) else {
            return
        }
        var next = ScreenTimeFocusShared.loadLocationPresence().insideZoneIDs
        if isInside {
            next.insert(zoneID)
        } else {
            next.remove(zoneID)
        }
        replacePresence(insideZoneIDs: next)
    }

    private func replacePresence(insideZoneIDs: Set<String>) {
        var presence = ScreenTimeFocusShared.loadLocationPresence()
        guard presence.insideZoneIDs != insideZoneIDs else { return }
        presence.insideZoneIDs = insideZoneIDs
        presence.updatedAt = ScreenTimeDateMath.epochMilliseconds(for: Date())
        ScreenTimeFocusShared.saveLocationPresence(presence)
        applyPolicy()
    }

    private func applyPolicy() {
        do {
            _ = try accessEngine.applyCurrentPolicy()
        } catch {
            Self.logger.error(
                "Failed to apply Screen Time policy after location change: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
