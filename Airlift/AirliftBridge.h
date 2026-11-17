#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ZDMAAirliftLogBlock)(NSString *line);

/**
 * ObjC bridge over the vendored Airlift Rust core (MIT, AirCard-iOS).
 *
 * Airlift drives the AirTraffic / com.apple.atc sync escape over an RPPairing
 * tunnel. It runs entirely in Rust and writes outside the app sandbox, so it
 * does not need a MobileContainerManager lease and does not use House Arrest.
 *
 * Requirements on device:
 *   - a valid RPPairing record (Documents/rppairing.plist, written by
 *     PairingController),
 *   - a loopback VPN route to 10.7.0.1 (LocalDevVPN),
 *   - the device unlocked.
 *
 * Every method blocks (network + AirTraffic sync) and must be called from a
 * background queue.
 */
@interface AirliftBridge : NSObject

/// YES when a non-empty RPPairing record is present.
+ (BOOL)isAvailable;

/// Absolute path of Documents/rppairing.plist, or nil.
+ (nullable NSString *)pairingFilePath;

/// Resolves the Data container via InstallationProxy over the Airlift tunnel.
+/// Returns a `/var/mobile/...` path (AirTraffic canonical form) or nil.
+ (nullable NSString *)containerForBundleID:(NSString *)bundleID
                                        log:(nullable ZDMAAirliftLogBlock)log
                                      error:(NSError **)error;

/// Writes every entry of `files` (leaf name -> bytes) into `targetDirectory`
/// on the device through the AirTraffic exploit.
+ (BOOL)writeFiles:(NSDictionary<NSString *, NSData *> *)files
 toTargetDirectory:(NSString *)targetDirectory
               log:(nullable ZDMAAirliftLogBlock)log
             error:(NSError **)error;

/// Log lines of the last Airlift operation (bounded).
+ (NSArray<NSString *> *)lastLogLines;

@end

NS_ASSUME_NONNULL_END
