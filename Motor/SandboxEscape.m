#import "SandboxEscape.h"
#import "ContainerAccess.h"

bool escape_sandbox_bad_query(NSString *bundleId) {
    // Legacy entry point kept for ABI compatibility. The raw container_query
    // sequence it used to run passed a C string to a setter that expects an
    // XPC object, which killed the process on iOS 27. Route it through the
    // guarded MCM lease instead.
    if (bundleId.length == 0) return false;
    NSString *path = [ContainerAccess containerPathForBundleID:bundleId error:nil];
    return path.length > 0;
}
