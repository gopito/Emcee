import Deployer
import Foundation
import Logging
import Models
import PathLib
import TemporaryStuff
import Version

/// Starts the remote workers on the given destinations that will poll jobs from the given queue
public final class RemoteWorkersStarter {
    private let emceeVersionProvider: VersionProvider
    private let deploymentDestinations: [DeploymentDestination]
    private let analyticsConfigurationLocation: AnalyticsConfigurationLocation?
    private let tempFolder: TemporaryFolder

    public init(
        emceeVersionProvider: VersionProvider,
        deploymentDestinations: [DeploymentDestination],
        analyticsConfigurationLocation: AnalyticsConfigurationLocation?,
        tempFolder: TemporaryFolder
    ) {
        self.emceeVersionProvider = emceeVersionProvider
        self.deploymentDestinations = deploymentDestinations
        self.analyticsConfigurationLocation = analyticsConfigurationLocation
        self.tempFolder = tempFolder
    }
    
    public func deployAndStartWorkers(queueAddress: SocketAddress) throws {
        let deployablesGenerator = DeployablesGenerator(
            emceeVersionProvider: emceeVersionProvider,
            remoteEmceeBinaryName: "EmceeWorker"
        )
        try deployWorkers(
            deployableItems: try deployablesGenerator.deployables()
        )
        try startDeployedWorkers(
            emceeBinaryDeployableItem: try deployablesGenerator.runnerTool(),
            queueAddress: queueAddress
        )
    }
    
    private func deployWorkers(
        deployableItems: [DeployableItem]
    ) throws {
        let deployer = DistDeployer(
            deploymentId: try emceeVersionProvider.version().value,
            deploymentDestinations: deploymentDestinations,
            deployableItems: deployableItems,
            deployableCommands: [],
            tempFolder: tempFolder
        )
        try deployer.deploy()
    }
    
    private func startDeployedWorkers(
        emceeBinaryDeployableItem: DeployableItem,
        queueAddress: SocketAddress)
        throws
    {
        let launchdPlistTargetPath = "launchd.plist"
        
        for destination in deploymentDestinations {
            let launchdPlist = RemoteWorkerLaunchdPlist(
                deploymentId: try emceeVersionProvider.version().value,
                deploymentDestination: destination,
                executableDeployableItem: emceeBinaryDeployableItem,
                queueAddress: queueAddress,
                analyticsConfigurationLocation: analyticsConfigurationLocation
            )
            let filePath = try tempFolder.createFile(
                filename: launchdPlistTargetPath,
                contents: try launchdPlist.plistData()
            )
            
            let launchdDeployableItem = DeployableItem(
                name: "launchd_plist",
                files: [
                    DeployableFile(
                        source: filePath,
                        destination: RelativePath(launchdPlistTargetPath)
                    )
                ]
            )
            let launchctlDeployableCommands = LaunchctlDeployableCommands(
                launchdPlistDeployableItem: launchdDeployableItem,
                plistFilename: launchdPlistTargetPath
            )
            
            let deployer = DistDeployer(
                deploymentId: try emceeVersionProvider.version().value,
                deploymentDestinations: [destination],
                deployableItems: [launchdDeployableItem],
                deployableCommands: [
                    launchctlDeployableCommands.forceUnloadFromBackgroundCommand(),
                    [
                        "sleep", "2"        // launchctl is async, so we have to wait :(
                    ],
                    launchctlDeployableCommands.forceLoadInBackgroundCommand()
                ],
                tempFolder: tempFolder
            )
            do {
                try deployer.deploy()
            } catch {
                Logger.error("Failed to deploy launchd plist: \(error). This error will be ignored.")
            }
        }
    }
}
