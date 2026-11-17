#pragma once
#import <Foundation/Foundation.h>

@class PatchPackage;

NS_ASSUME_NONNULL_BEGIN
/// Marker used by DevicePatchService: this container path came from Airlift
/// (InstallationProxy over the RPPairing tunnel), not from an MCM lease.
extern NSString *const PatchTransactionAirliftContainerKey;

@interface PatchLedgerEntry : NSObject
@property (nonatomic, copy) NSString *bundleID, *containerPath;
@property (nonatomic, copy) NSArray<NSDictionary *> *entries;
@property (nonatomic, strong) NSDate *at;
@end

@interface PatchTransaction : NSObject
+ (BOOL)applyPackage:(PatchPackage *)pkg container:(NSString *)containerPath bundleID:(NSString *)bundleID error:(NSError **)err;

/// Writes the package through the Airlift AirTraffic escape. The container is
/// a remote `/var/mobile/...` path; nothing is written through NSFileManager.
+ (BOOL)applyPackage:(PatchPackage *)pkg viaAirliftToContainer:(NSString *)containerPath bundleID:(NSString *)bundleID error:(NSError **)err;
+ (BOOL)restoreLedger:(PatchLedgerEntry *)ledger error:(NSError **)err;
+ (NSArray<NSString *> *)lastResolvedTargets;
+ (void)resetResolvedTargets;
@end
NS_ASSUME_NONNULL_END
