#import <Foundation/Foundation.h>

// Deklarojme funksionet e librarise Rust Airlift
extern int al_pairing_run_host(const char *pairing_file, const char *host_ip, int port);
extern int al_exploit_write_file(const char *target_path, const char *source_file);
extern int al_exploit_remove_path(const char *target_path);

@implementation AirliftBridge

+ (BOOL)writeFile:(NSString *)filePath toContainer:(NSString *)containerPath {
    // Kontrollo nese ekziston pairing file
    NSString *pairingPath = [self pairingFilePath];
    if (!pairingPath) {
        NSLog(@"[Airlift] Pairing file not found.");
        return NO;
    }
    
    // Fillimisht nis host-in (RPPairing)
    int host_result = al_pairing_run_host(pairingPath.UTF8String, "127.0.0.1", 49152);
    if (host_result != 0) {
        NSLog(@"[Airlift] Failed to start pairing host: %d", host_result);
        return NO;
    }
    
    // Tani shkruaj skedarin
    NSString *targetPath = [containerPath stringByAppendingPathComponent:@"Data/Raw/ios/gameassetbundles/avatar/assetindexer.tdn~2F53YNFWXQZyPdFl8HWBBwtXk~3D"];
    int write_result = al_exploit_write_file(targetPath.UTF8String, filePath.UTF8String);
    
    if (write_result != 0) {
        NSLog(@"[Airlift] Write failed: %d", write_result);
        return NO;
    }
    
    NSLog(@"[Airlift] File written successfully.");
    return YES;
}

+ (NSString *)pairingFilePath {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *pairingPath = [docs stringByAppendingPathComponent:@"pairing.plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:pairingPath]) {
        return pairingPath;
    }
    return nil;
}

@end
