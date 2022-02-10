import DateProvider
import CommonTestModels
import Foundation
import LocalHostDeterminer
import MetricsExtensions
import QueueModels

public final class RunAndroidTestsPayloadExecutor {
    private let dateProvider: DateProvider
    
    public init(
        dateProvider: DateProvider
    ) {
        self.dateProvider = dateProvider
    }
    
    public func execute(
        analyticsConfiguration: AnalyticsConfiguration,
        bucketId: BucketId,
        payload: RunAndroidTestsPayload
    ) -> BucketResult {
        let testingResult = TestingResult(
            testDestination: payload.testDestination,
            unfilteredResults: payload.testEntries.map { (testEntry: TestEntry) -> TestEntryResult in
                TestEntryResult.withResults(
                    testEntry: testEntry,
                    testRunResults: [
                        TestRunResult(
                            succeeded: false,
                            exceptions: [
                                TestException(
                                    reason: "Android tests are not supported by Apple worker",
                                    filePathInProject: "Unknown",
                                    lineNumber: 0,
                                    relatedTestName: testEntry.testName
                                )
                            ],
                            logs: [],
                            duration: 0,
                            startTime: dateProvider.dateSince1970ReferenceDate(),
                            hostName: LocalHostDeterminer.currentHostAddress,
                            udid: "n/a"
                        )
                    ]
                )
            }
        )
        
        return BucketResult.testingResult(testingResult)
    }
}
