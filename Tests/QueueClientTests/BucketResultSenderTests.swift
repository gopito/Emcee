import Foundation
import Models
import ModelsTestHelpers
import QueueClient
import RESTMethods
import RequestSender
import RequestSenderTestHelpers
import XCTest

final class BucketResultSenderTests: XCTestCase {
    let testingResult = TestingResultFixtures().testingResult()
    
    func test___callback_with_result() throws {
        let sender = BucketResultSenderImpl(
            requestSender: FakeRequestSender(
                result: BucketResultAcceptResponse.bucketResultAccepted(bucketId: testingResult.bucketId),
                requestSenderError: nil
            )
        )
        
        let callbackExpectation = expectation(description: "callback should be called")
        try sender.send(
            testingResult: testingResult,
            requestId: "request id",
            workerId: "worker id",
            requestSignature: RequestSignature(value: "signature"),
            completion: { result in
                XCTAssertEqual(
                    try? result.dematerialize(),
                    self.testingResult.bucketId
                )
                callbackExpectation.fulfill()
            }
        )
        
        wait(for: [callbackExpectation], timeout: 10)
    }
    
    func test___callback_with_error() throws {
        let sender = BucketResultSenderImpl(
            requestSender: FakeRequestSender(result: nil, requestSenderError: RequestSenderError.noData)
        )
        
        let callbackExpectation = expectation(description: "callback should be called")
        try sender.send(
            testingResult: testingResult,
            requestId: "request id",
            workerId: "worker id",
            requestSignature: RequestSignature(value: "signature"),
            completion: { result in
                do {
                    _ = try result.dematerialize()
                } catch {
                    guard case RequestSenderError.noData = error else {
                        return XCTFail("Unexpected error: \(error). Error is expected to be propagated.")
                    }
                }
                callbackExpectation.fulfill()
            }
        )
        
        wait(for: [callbackExpectation], timeout: 10)
    }
}
