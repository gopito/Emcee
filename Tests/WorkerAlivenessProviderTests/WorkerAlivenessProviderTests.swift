import Foundation
import Models
import WorkerAlivenessProvider
import WorkerAlivenessProviderTestHelpers
import XCTest

final class WorkerAlivenessProviderTests: XCTestCase {
    func test__when_worker_registers__it_is_alive() {
        let tracker = WorkerAlivenessProviderImpl(knownWorkerIds: [])
        tracker.didRegisterWorker(workerId: "worker")
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").status, .alive)
    }
    
    func test__when_worker_registers__it_has_no_buckets_being_processed() {
        let tracker = WorkerAlivenessProviderImpl(knownWorkerIds: [])
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").status, .notRegistered)
        tracker.didRegisterWorker(workerId: "worker")
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").status, .alive)
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").bucketIdsBeingProcessed, [])
    }
    
    func test__marking_worker_as_alive___registers_buckets_being_processing() {
        let tracker = WorkerAlivenessProviderImpl(knownWorkerIds: [])
        tracker.didRegisterWorker(workerId: "worker")
        tracker.set(bucketIdsBeingProcessed: ["bucketid"], workerId: "worker")
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").bucketIdsBeingProcessed, ["bucketid"])
    }
    
    func test__when_worker_is_silent__tracker_returns_silent() {
        let tracker = WorkerAlivenessProviderImpl(knownWorkerIds: ["worker"])
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").status, .notRegistered)
        tracker.didRegisterWorker(workerId: "worker")
        tracker.setWorkerIsSilent(workerId: "worker")
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").status, .silent)
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").bucketIdsBeingProcessed, [])
    }
    
    func test___when_worker_is_silent___tracker_includes_buckets_being_processed() {
        let tracker = WorkerAlivenessProviderImpl(knownWorkerIds: ["worker"])
        tracker.didRegisterWorker(workerId: "worker")
        tracker.set(bucketIdsBeingProcessed: ["bucketid"], workerId: "worker")
        tracker.setWorkerIsSilent(workerId: "worker")
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").status, .silent)
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker").bucketIdsBeingProcessed, ["bucketid"])
    }
    
    func test__availability_of_workers() {
        let tracker = WorkerAlivenessProviderImpl(knownWorkerIds: ["worker"])
        tracker.didRegisterWorker(workerId: "worker")
        XCTAssertTrue(tracker.hasAnyAliveWorker)
    }
    
    func test___aliveness_for_not_registered_workers() {
        let tracker = WorkerAlivenessProviderImpl(
            knownWorkerIds: ["worker"]
        )
        XCTAssertEqual(
            tracker.workerAliveness,
            [
                WorkerId(value: "worker"): WorkerAliveness(
                    status: .notRegistered,
                    bucketIdsBeingProcessed: []
                )
            ]
        )
    }
    
    func test___disabling_worker___keeps_processing_buckets() {
        let tracker = WorkerAlivenessProviderImpl(
            knownWorkerIds: ["worker"]
        )
        tracker.didRegisterWorker(workerId: "worker")
        tracker.didDequeueBucket(bucketId: "bucketId", workerId: "worker")
        tracker.disableWorker(workerId: "worker")
        
        XCTAssertEqual(
            tracker.workerAliveness,
            [
                WorkerId(value: "worker"): WorkerAliveness(
                    status: .disabled,
                    bucketIdsBeingProcessed: ["bucketId"]
                )
            ]
        )
    }
    
    func test___enabling_worker___keeps_processing_buckets() {
        let tracker = WorkerAlivenessProviderImpl(
            knownWorkerIds: ["worker"]
        )
        tracker.didRegisterWorker(workerId: "worker")
        tracker.didDequeueBucket(bucketId: "bucketId", workerId: "worker")
        tracker.disableWorker(workerId: "worker")
        tracker.enableWorker(workerId: "worker")
        
        XCTAssertEqual(
            tracker.workerAliveness,
            [
                WorkerId(value: "worker"): WorkerAliveness(
                    status: .alive,
                    bucketIdsBeingProcessed: ["bucketId"]
                )
            ]
        )
    }
    
    let fixedDate = Date()
}
