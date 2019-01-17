import Foundation
import Models

public final class TestExecutionBehaviorFixtures {
    public var environment = [String: String]()
    public var numberOfRetries: UInt = 0
    
    public init(environment: [String: String] = [:], numberOfRetries: UInt = 0) {
        self.environment = environment
        self.numberOfRetries = numberOfRetries
    }
    
    public func build() -> TestExecutionBehavior {
        return TestExecutionBehavior(environment: environment, numberOfRetries: numberOfRetries)
    }
}
