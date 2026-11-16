#import "AirliftBridge.h"

+ (BOOL)applyPatch:(NSString *)patchName {
    NSString *path = [[NSBundle mainBundle] pathForResource:patchName ofType:@"3105"];
    if (!path) return NO;
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return NO;
    
    // Dekripto paketën .3105
    NSError *err = nil;
    PatchPackage *pkg = [PatchPackageCodec decodeData:data passphrase:@"shared-server-secret" error:&err];
    if (!pkg) return NO;
    
    // Gjej container-in e Free Fire
    NSString *container = [DevicePatchService containerPathForBundleID:@"com.dts.freefireth"];
    if (!container) return NO;
    
    // Shkruaj skedarin përmes Airlift (në vend të sandbox escape)
    for (NSDictionary *rule in pkg.rules) {
        NSString *src = rule[@"src"];
        NSString *dst = rule[@"dst"];
        NSData *blob = pkg.files[src];
        
        // Ruaj skedarin përkohësisht në Documents
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:src];
        [blob writeToFile:tempPath atomically:YES];
        
        // Dërgoje përmes Airlift
        if (![AirliftBridge writeFile:tempPath toContainer:container]) {
            NSLog(@"[Patch] Airlift failed for %@", dst);
            return NO;
        }
    }
    return YES;
}
