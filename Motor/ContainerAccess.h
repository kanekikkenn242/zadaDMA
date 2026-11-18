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

/// Activates a process-wide sandbox extension for an already-known path. Uses
/// the iOS 26/27 App Group symlink query (worse_query) first, then the legacy
/// bad_query path-traversal query.
+ (BOOL)grantAccessToPath:(NSString *)path error:(NSError **)error;

/// Same grant, but scoped: the caller owns the returned sandbox-extension
/// handle and must pass it to `releaseAccess:` when the write is done.
/// Returns a negative value on failure.
+ (int64_t)acquireAccessToPath:(NSString *)path error:(NSError **)error;
+ (void)releaseAccess:(int64_t)handle;

/// The App Group X uses for worse_query when the signing profile carries no
/// `com.apple.security.application-groups` entitlement. Exposed for tracing.
+ (NSString *)worseQueryGroup;

/// Resolves the installed `.app` bundle directory (e.g.
/// `/var/containers/Bundle/Application/<UUID>/FreeFire.app`) without pairing.
/// Tries the MCM class-1 app-bundle container first, then enumerates the
/// bundle root through a worse_query/traversal grant and matches the metadata
/// plist or Info.plist.
+ (nullable NSString *)applicationBundlePathForBundleID:(NSString *)bundleID
                                                 error:(NSError **)error;

/// Releases all leases/extension handles held by the process.
+ (void)releaseAll;

/// Best-effort class-2 container identifier enumeration (installed apps).
+ (nullable NSArray<NSString *> *)enumerateAppContainerIdentifiers:(NSError **)error;

/// Directory listing of `path` (used after a lease has been activated).
+ (nullable NSArray<NSString *> *)listDirectory:(NSString *)path
                                          error:(NSError **)error;

/// Clears the durable MCM breadcrumb before a new injection attempt.
+ (void)resetTrace;

/// Appends one durable breadcrumb line (used by the patch transaction too).
+ (void)note:(NSString *)step;

/// Last breadcrumb lines written before a crash (or during the last attempt).
+ (NSString *)traceTail;

@end

NS_ASSUME_NONNULL_END
