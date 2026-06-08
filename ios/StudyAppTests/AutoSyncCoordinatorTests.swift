import Combine
import XCTest
@testable import StudyApp

@MainActor
final class AutoSyncCoordinatorTests: XCTestCase {
    private var repository: MockSyncRepository!
    private var logger: AppLogger!
    private var coordinator: AutoSyncCoordinator!
    private var dataVersion = 0
    private var syncStatusChangedCount = 0

    // Keys that AutoSyncCoordinator persists against `UserDefaults.standard`.
    private let blockedKey = "studyapp.sync.autoSyncBlockedUntilLocalChange"
    private let lastLifecycleSyncKey = "studyapp.sync.lastLifecycleAutoSyncAt"

    override func setUp() async throws {
        try await super.setUp()
        clearCoordinatorDefaults()
        repository = MockSyncRepository()
        logger = AppLogger()
        dataVersion = 0
        syncStatusChangedCount = 0
        coordinator = AutoSyncCoordinator(
            syncRepository: repository,
            logger: logger,
            currentDataVersion: { [unowned self] in self.dataVersion },
            onSyncStatusChanged: { [unowned self] in self.syncStatusChangedCount += 1 }
        )
    }

    override func tearDown() async throws {
        clearCoordinatorDefaults()
        coordinator = nil
        repository = nil
        logger = nil
        try await super.tearDown()
    }

    // MARK: - Gating

    func test_schedule_whenNotAuthenticated_doesNothing() async throws {
        repository.status = SyncStatus(isAuthenticated: false)
        dataVersion = 1

        coordinator.schedule(reason: "data-version-1")

        // The guard returns synchronously, so a brief await is enough for any
        // stray Tasks. We still assert that no sync was dispatched.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(repository.syncNowCallCount, 0)
        XCTAssertEqual(syncStatusChangedCount, 0)
    }

    func test_schedule_withDataVersionReason_triggersSync_andMarksStatus() async throws {
        repository.status = authenticatedStatus()
        dataVersion = 5
        let expectation = XCTestExpectation(description: "syncNow called")
        repository.syncNowInvoked = { expectation.fulfill() }

        coordinator.schedule(reason: "data-version-5")
        await fulfillment(of: [expectation], timeout: 4.0)

        XCTAssertEqual(repository.syncNowCallCount, 1)
        XCTAssertEqual(syncStatusChangedCount, 1)
        XCTAssertGreaterThan(UserDefaults.standard.double(forKey: lastLifecycleSyncKey), 0)
    }

    func test_schedule_deduplicates_whenDataVersionUnchanged() async throws {
        repository.status = authenticatedStatus()
        dataVersion = 7
        let firstSync = XCTestExpectation(description: "first syncNow")
        repository.syncNowInvoked = { firstSync.fulfill() }

        coordinator.schedule(reason: "data-version-7")
        await fulfillment(of: [firstSync], timeout: 4.0)
        XCTAssertEqual(repository.syncNowCallCount, 1)

        // Second schedule with the same dataVersion and a non-lifecycle reason
        // must be a no-op because the coordinator already synced this version.
        coordinator.schedule(reason: "data-version-7")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(repository.syncNowCallCount, 1)
    }

    // MARK: - Block / unblock behaviour

    func test_blockUntilLocalChange_skipsLifecycleSync() async throws {
        repository.status = authenticatedStatus()
        dataVersion = 2

        coordinator.blockUntilLocalChange()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: blockedKey))

        coordinator.schedule(reason: "scene-active")

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(repository.syncNowCallCount, 0)
        XCTAssertTrue(
            UserDefaults.standard.bool(forKey: blockedKey),
            "A lifecycle schedule must not clear the block flag."
        )
    }

    func test_blockUntilLocalChange_isClearedByDataVersionSchedule_andSyncRuns() async throws {
        repository.status = authenticatedStatus()
        dataVersion = 3

        coordinator.blockUntilLocalChange()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: blockedKey))

        let expectation = XCTestExpectation(description: "syncNow after unblock")
        repository.syncNowInvoked = { expectation.fulfill() }

        coordinator.schedule(reason: "data-version-3")
        await fulfillment(of: [expectation], timeout: 4.0)

        XCTAssertEqual(repository.syncNowCallCount, 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: blockedKey))
    }

    func test_recordManualSyncApplied_clearsBlockFlag_andStampsLifecycleTime() {
        coordinator.blockUntilLocalChange()
        dataVersion = 99

        coordinator.recordManualSyncApplied()

        XCTAssertFalse(UserDefaults.standard.bool(forKey: blockedKey))
        let stored = UserDefaults.standard.double(forKey: lastLifecycleSyncKey)
        XCTAssertGreaterThan(stored, 0)
    }

    // MARK: - Lifecycle throttle

    func test_lifecycleSchedule_isThrottled_afterRecentSync() async throws {
        // Simulate a lastSyncAt + lastLifecycleAutoSyncAt that happened just now.
        let nowMs = Date().epochMilliseconds
        repository.status = authenticatedStatus(lastSyncAt: nowMs)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastLifecycleSyncKey)
        dataVersion = 5

        coordinator.schedule(reason: "scene-active")

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(
            repository.syncNowCallCount,
            0,
            "Lifecycle sync must be throttled when both lastSyncAt and lastLifecycleAutoSyncAt are recent."
        )
    }

    func test_lifecycleSchedule_withoutRecentSync_runsSync() async throws {
        repository.status = authenticatedStatus(lastSyncAt: nil)
        dataVersion = 8

        let expectation = XCTestExpectation(description: "syncNow for lifecycle reason")
        repository.syncNowInvoked = { expectation.fulfill() }

        coordinator.schedule(reason: "app-load")
        await fulfillment(of: [expectation], timeout: 4.0)

        XCTAssertEqual(repository.syncNowCallCount, 1)
    }

    // MARK: - Error handling

    func test_syncNowFailure_doesNotCallOnSyncStatusChanged() async throws {
        repository.status = authenticatedStatus()
        dataVersion = 11
        struct TestError: Error {}
        repository.syncNowShouldThrow = TestError()

        let expectation = XCTestExpectation(description: "syncNow invoked (and throws)")
        repository.syncNowInvoked = { expectation.fulfill() }

        coordinator.schedule(reason: "data-version-11")
        await fulfillment(of: [expectation], timeout: 4.0)

        // Give the coordinator a moment to finish its error branch.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(repository.syncNowCallCount, 1)
        XCTAssertEqual(
            syncStatusChangedCount,
            0,
            "onSyncStatusChanged must only fire after a successful sync."
        )
    }

    func test_schedule_whenRepositoryIsAlreadySyncing_retriesPendingRequest() async throws {
        repository.status = authenticatedStatus(isSyncing: true)
        dataVersion = 12

        coordinator.schedule(reason: "data-version-12")
        try await Task.sleep(nanoseconds: 2_300_000_000)
        XCTAssertEqual(repository.syncNowCallCount, 0)

        let expectation = XCTestExpectation(description: "syncNow after repository becomes idle")
        repository.syncNowInvoked = { expectation.fulfill() }
        repository.status = authenticatedStatus(isSyncing: false)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(repository.syncNowCallCount, 1)
        XCTAssertEqual(syncStatusChangedCount, 1)
    }

    func test_schedule_whenMultipleRequestsArriveWhileSyncing_keepsLatestDataVersion() async throws {
        repository.status = authenticatedStatus(isSyncing: true)
        dataVersion = 20
        coordinator.schedule(reason: "data-version-20")

        dataVersion = 21
        coordinator.schedule(reason: "data-version-21")
        try await Task.sleep(nanoseconds: 2_300_000_000)
        XCTAssertEqual(repository.syncNowCallCount, 0)

        let expectation = XCTestExpectation(description: "latest pending sync")
        repository.syncNowInvoked = { expectation.fulfill() }
        repository.status = authenticatedStatus(isSyncing: false)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(repository.syncNowCallCount, 1)

        repository.syncNowInvoked = nil
        coordinator.schedule(reason: "data-version-20")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(
            repository.syncNowCallCount,
            1,
            "After syncing the latest dataVersion, repeating the same current version must be a no-op."
        )
    }

    // MARK: - Helpers

    private func authenticatedStatus(
        lastSyncAt: Int64? = nil,
        isSyncing: Bool = false
    ) -> SyncStatus {
        SyncStatus(
            isAuthenticated: true,
            email: "tester@example.com",
            isSyncing: isSyncing,
            lastSyncAt: lastSyncAt
        )
    }

    private func clearCoordinatorDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: blockedKey)
        defaults.removeObject(forKey: lastLifecycleSyncKey)
    }
}

// MARK: - Mocks

@MainActor
private final class MockSyncRepository: SyncRepository {
    var status: SyncStatus = SyncStatus()
    private let subject = CurrentValueSubject<SyncStatus, Never>(SyncStatus())
    var statusPublisher: AnyPublisher<SyncStatus, Never> { subject.eraseToAnyPublisher() }

    var syncNowCallCount = 0
    var syncNowShouldThrow: Error?
    var syncNowInvoked: (() -> Void)?

    func syncNow() async throws {
        syncNowCallCount += 1
        syncNowInvoked?()
        if let syncNowShouldThrow {
            throw syncNowShouldThrow
        }
    }

    func importLocalDataToCloud() async throws {}
    func deleteCloudDataForCurrentUser() async throws {}
    func clearLocalSyncState() async {}
    func pendingConflicts() -> [SyncConflict] { [] }
    func resolveConflicts(_ resolutions: [SyncConflictResolution]) async throws {}
}
