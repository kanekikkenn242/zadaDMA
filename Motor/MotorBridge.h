#pragma once
#import <Foundation/Foundation.h>
#import "PatchPackageCodec.h"
#import "PatchTransaction.h"
#import "ExploitBootstrap.h"
#import "SandboxEscape.h"
#import "DevicePatchService.h"
#import "AFCClient.h"
#import "AntiTamper.h"

NS_ASSUME_NONNULL_BEGIN
@interface MotorBridge : NSObject
+ (BOOL)bootstrap;
+ (void)ensureSandbox:(void(^)(BOOL ok, NSError * _Nullable err))done;
+ (BOOL)applyPackageData:(NSData *)data passphrase:(NSString *)pass bundleID:(NSString *)bundleID;
+ (nullable NSArray<NSString *> *)appContainers;
@end
NS_ASSUME_NONNULL_END
