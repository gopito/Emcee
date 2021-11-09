import Foundation
import QueueModels
import UniqueIdentifierGenerator

public final class UnsplitBucketSplitter: BucketSplitter {    
    public override func split(
        inputs: [TestEntryConfiguration],
        bucketSplitInfo: BucketSplitInfo
    ) -> [[TestEntryConfiguration]] {
        return [inputs]
    }
}
