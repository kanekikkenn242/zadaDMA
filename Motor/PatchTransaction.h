#pragma once
#import <Foundation/Foundation.h>

@class PatchPackage;

NS_ASSUME_NONNULL_BEGIN
@interface PatchLedgerEntry : NSObject
@property (nonatomic, copy) NSString *bundleID, *containerPath;
@property (nonatomic, copy) NSArray<NSDictionary *> *entries;
@property (nonatomic, strong) NSDate *at;
@end

@interface PatchTransaction : NSObject
+ (BOOL)applyPackage:(PatchPackage *)pkg container:(NSString *)containerPath bundleID:(NSString *)bundleID error:(NSError **)err;
+ (BOOL)restoreLedger:(PatchLedgerEntry *)ledger error:(NSError **)err;
@end
NS_ASSUME_NONNULL_END
