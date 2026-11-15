#import "Bridge.h"
#import "SandboxEscape.h"
#import "PatchPackageCodec.h"
#import "PatchTransaction.h"

extern int kexploit_run(void);

@implementation MotorBridge

+ (BOOL)bootstrap {
    // 1. Provojmë Kernel Exploit
    int kfd_status = kexploit_run();
    if (kfd_status != 0) {
        NSLog(@"[MotorBridge] Kernel Exploit dështoi.");
        return NO;
    }
    NSLog(@"[MotorBridge] Kernel R/W u aktivizua.");
    return YES;
}

+ (BOOL)applyPatch:(NSString *)patchName {
    // 1. Kontrollo Sandbox
    if (!escape_sandbox_bad_query(@"com.dts.freefireth")) {
        NSLog(@"[MotorBridge] Sandbox escape dështoi.");
        return NO;
    }
    
    // 2. Lexo skedarin .3105
    NSString *path = [[NSBundle mainBundle] pathForResource:patchName ofType:@"3105"];
    if (!path) return NO;
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSError *err = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data passphrase:@"shared-server-secret" error:&err];
    if (!pkg) return NO;
    
    // 3. Apliko Patch-in
    return [PatchTransaction applyPackage:pkg container:@"/private/var/mobile/Containers/Data/Application" bundleID:@"com.dts.freefireth" error:&err];
}

@end
