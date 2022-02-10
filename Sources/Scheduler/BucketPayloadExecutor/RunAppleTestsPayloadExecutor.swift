import DateProvider
import EmceeLogging
import Foundation
import LocalHostDeterminer
import MetricsExtensions
import QueueModels
import Runner
import RunnerModels
import SimulatorPool
import SimulatorPoolModels
import Tmp

public final class RunAppleTestsPayloadExecutor {
    private let dateProvider: DateProvider
    private let globalMetricRecorder: GlobalMetricRecorder
    private let onDemandSimulatorPool: OnDemandSimulatorPool
    private let runnerProvider: AppleRunnerProvider
    private let simulatorSettingsModifier: SimulatorSettingsModifier
    private let specificMetricRecorderProvider: SpecificMetricRecorderProvider
    private let tempFolder: TemporaryFolder
    private let version: Version
    
    public init(
        dateProvider: DateProvider,
        globalMetricRecorder: GlobalMetricRecorder,
        onDemandSimulatorPool: OnDemandSimulatorPool,
        runnerProvider: AppleRunnerProvider,
        simulatorSettingsModifier: SimulatorSettingsModifier,
        specificMetricRecorderProvider: SpecificMetricRecorderProvider,
        tempFolder: TemporaryFolder,
        version: Version
    ) {
        self.dateProvider = dateProvider
        self.globalMetricRecorder = globalMetricRecorder
        self.onDemandSimulatorPool = onDemandSimulatorPool
        self.runnerProvider = runnerProvider
        self.simulatorSettingsModifier = simulatorSettingsModifier
        self.specificMetricRecorderProvider = specificMetricRecorderProvider
        self.tempFolder = tempFolder
        self.version = version
    }
    
    public func execute(
        analyticsConfiguration: AnalyticsConfiguration,
        bucketId: BucketId,
        logger: ContextualLogger,
        payload: RunAppleTestsPayload
    ) -> BucketResult {
        let startedAt = dateProvider.dateSince1970ReferenceDate()
        let testingResult: TestingResult
        do {
            testingResult = try runRetrying(
                analyticsConfiguration: analyticsConfiguration,
                runAppleTestsPayload: payload,
                logger: logger,
                numberOfRetries: payload.testExecutionBehavior.numberOfRetriesOnWorker()
            )
        } catch {
            logger.error("Failed to execute bucket \(bucketId): \(error)")
            testingResult = TestingResult(
                testDestination: payload.testDestination,
                unfilteredResults: payload.testEntries.map { testEntry -> TestEntryResult in
                    TestEntryResult.withResult(
                        testEntry: testEntry,
                        testRunResult: TestRunResult(
                            succeeded: false,
                            exceptions: [
                                TestException(
                                    reason: "Emcee failed to execute this test: \(error)",
                                    filePathInProject: #file,
                                    lineNumber: #line,
                                    relatedTestName: testEntry.testName
                                )
                            ],
                            logs: [],
                            duration: dateProvider.currentDate().timeIntervalSince(startedAt.date),
                            startTime: startedAt,
                            hostName: LocalHostDeterminer.currentHostAddress,
                            udid: UDID(value: "undefined")
                        )
                    )
                }
            )
        }
        return .testingResult(testingResult)
    }
    
    /**
     Runs tests in a given Bucket, retrying failed tests multiple times if necessary.
     */
    private func runRetrying(
        analyticsConfiguration: AnalyticsConfiguration,
        runAppleTestsPayload: RunAppleTestsPayload,
        logger: ContextualLogger,
        numberOfRetries: UInt
    ) throws -> TestingResult {
        let firstRun = try runBucketOnce(
            analyticsConfiguration: analyticsConfiguration,
            runAppleTestsPayload: runAppleTestsPayload,
            testsToRun: runAppleTestsPayload.testEntries,
            logger: logger
        )
        
        guard numberOfRetries > 0 else { return firstRun }
        
        var lastRunResults = firstRun
        var results = [firstRun]
        for retryNumber in 0 ..< numberOfRetries {
            let failedTestEntriesAfterLastRun = lastRunResults.failedTests.map { $0.testEntry }
            if failedTestEntriesAfterLastRun.isEmpty {
                logger.debug("No failed tests after last retry, so nothing to run.")
                break
            }
            logger.debug("After last run \(failedTestEntriesAfterLastRun.count) tests have failed: \(failedTestEntriesAfterLastRun).")
            logger.debug("Retrying them, attempt #\(retryNumber + 1) of maximum \(numberOfRetries) attempts")
            lastRunResults = try runBucketOnce(
                analyticsConfiguration: analyticsConfiguration,
                runAppleTestsPayload: runAppleTestsPayload,
                testsToRun: failedTestEntriesAfterLastRun,
                logger: logger
            )
            results.append(lastRunResults)
        }
        
        return try TestingResult.byMerging(testingResults: results)
    }
    
    private func runBucketOnce(
        analyticsConfiguration: AnalyticsConfiguration,
        runAppleTestsPayload: RunAppleTestsPayload,
        testsToRun: [TestEntry],
        logger: ContextualLogger
    ) throws -> TestingResult {
        let simulatorPool = try onDemandSimulatorPool.pool(
            key: OnDemandSimulatorPoolKey(
                developerDir: runAppleTestsPayload.developerDir,
                simDeviceType: runAppleTestsPayload.simDeviceType,
                simRuntime: runAppleTestsPayload.simRuntime
            )
        )
        
        let allocatedSimulator = try simulatorPool.allocateSimulator(
            dateProvider: dateProvider,
            logger: logger,
            simulatorOperationTimeouts: runAppleTestsPayload.simulatorOperationTimeouts,
            version: version,
            globalMetricRecorder: globalMetricRecorder
        )
        
        return try allocatedSimulator.withAutoreleasingSimulator { simulator -> TestingResult in
            try simulatorSettingsModifier.apply(
                developerDir: runAppleTestsPayload.developerDir,
                simulatorSettings: runAppleTestsPayload.simulatorSettings,
                toSimulator: allocatedSimulator.simulator
            )
            
            let runner = runnerProvider.create(
                specificMetricRecorder: try specificMetricRecorderProvider.specificMetricRecorder(
                    analyticsConfiguration: analyticsConfiguration
                ),
                tempFolder: tempFolder,
                version: version
            )

            let runnerResult = try runner.runOnce(
                entriesToRun: testsToRun,
                configuration: AppleRunnerConfiguration(
                    buildArtifacts: runAppleTestsPayload.buildArtifacts,
                    developerDir:runAppleTestsPayload.developerDir,
                    environment: runAppleTestsPayload.testExecutionBehavior.environment,
                    logCapturingMode: runAppleTestsPayload.testExecutionBehavior.logCapturingMode,
                    userInsertedLibraries: runAppleTestsPayload.testExecutionBehavior.userInsertedLibraries,
                    lostTestProcessingMode: .reportError,
                    persistentMetricsJobId: analyticsConfiguration.persistentMetricsJobId,
                    pluginLocations: runAppleTestsPayload.pluginLocations,
                    simulator: allocatedSimulator.simulator,
                    simulatorSettings: runAppleTestsPayload.simulatorSettings,
                    testTimeoutConfiguration: runAppleTestsPayload.testTimeoutConfiguration,
                    testAttachmentLifetime: runAppleTestsPayload.testAttachmentLifetime
                )
            )
            
            runnerResult.testEntryResults.filter { $0.isLost }.forEach {
                logger.debug("Lost result for \($0)")
            }
            
            return TestingResult(
                testDestination: runAppleTestsPayload.testDestination,
                unfilteredResults: runnerResult.testEntryResults
            )
        }
    }
}