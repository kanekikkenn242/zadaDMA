#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * On-device access to another app's data container.
 *
 * iOS does not hand out cross-app container paths to normal apps. The system
 * House Arrest service is allowed to vend them, and MobileContainerManager
 * special-cases its bundle identifier (com.apple.mobile.MobileHouseArrest).
 * This app ships with that identifier, so it can use the same private
 * container_query_* API to obtain a lease + sandbox extension for a target
 * app's data container and then read/write it directly.
 *
 * Primary path : container_query class 2 (app data), identifier = bundle id.
 * Fallback     : filesystem metadata scan + bad_query path-traversal query
 *                (systemgroup.com.apple.mobilegestaltcache, 8x "..").
 *
 * Every resolved container is cached for the lifetime of the process; the
 * cached object keeps the sandbox extension alive.
 */
@interface ContainerAccess : NSObject

/// Resolves and activates the data container for `bundleID`.
/// Returns the absolute container root (usually /private/var/mobile/...).
+ (nullable NSString *)containerPathForBundleID:(NSString *)bundleID
                                          error:(NSError **)error;

/// YES when the private container API could be loaded on this OS.
+ (BOOL)isAvailable;

/// Activates a sandbox extension for an already-known container path using
/// the legacy bad_query path-traversal query.
+ (BOOL)grantAccessToPath:(NSString *)path error:(NSError **)error;

/// Releases all leases/extension handles held by the process.
+ (void)releaseAll;

/// Best-effort class-2 container identifier enumeration (installed apps).
+ (nullable NSArray<NSString *> *)enumerateAppContainerIdentifiers:(NSError **)error;

/// Directory listing of `path` (used after a lease has been activated).
+ (nullable NSArray<NSString *> *)listDirectory:(NSString *)path
                                          error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
