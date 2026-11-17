#import "AirliftBridge.h"
#import "GrappaHelper.h"
#import "airlift.h"

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <stdlib.h>
#import <sys/socket.h>

static NSString *const ZDMAAirliftErrorDomain = @"zadaDMA.airlift";
static NSString *const ZDMAAirliftDefaultHost = @"10.7.0.1";

// ---------------------------------------------------------------------------
// Log sink passed through `void *ctx` to the Rust log callback.
// ---------------------------------------------------------------------------

@interface ZDMAAirliftLogSink : NSObject
@property (atomic, copy, nullable) ZDMAAirliftLogBlock block;
@property (nonatomic, strong) NSMutableArray<NSString *> *lines;
- (void)appendCString:(const char *)message;
- (NSArray<NSString *> *)snapshot;
@end

@implementation ZDMAAirliftLogSink

- (instancetype)init {
    self = [super init];
    if (self) {
        _lines = [NSMutableArray array];
    }
    return self;
}

- (void)appendCString:(const char *)message {
    if (!message) return;
    NSString *line = [NSString stringWithUTF8String:message];
    if (!line) return;

    @synchronized (self) {
        [_lines addObject:line];
        if (_lines.count > 400) {
            [_lines removeObjectsInRange:NSMakeRange(0, _lines.count - 400)];
        }
    }

    NSLog(@"[Airlift] %@", line);

    ZDMAAirliftLogBlock block = self.block;
    if (block) block(line);
}

- (NSArray<NSString *> *)snapshot {
    @synchronized (self) {
        return [_lines copy];
    }
}

@end

static void ZDMAAirliftLogCallback(void *ctx, const char *message) {
    if (!ctx || !message) return;
    [(__bridge ZDMAAirliftLogSink *)ctx appendCString:message];
}

// ---------------------------------------------------------------------------
// Last-operation diagnostics (surfaced in the LOAD error output).
// ---------------------------------------------------------------------------

static NSLock *ZDMAAirliftLogLock(void) {
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSLock new]; });
    return lock;
}

static NSArray<NSString *> *gZDMAAirliftLastLogs;

static void ZDMAAirliftRememberLogs(NSArray<NSString *> *lines) {
    NSLock *lock = ZDMAAirliftLogLock();
    [lock lock];
    gZDMAAirliftLastLogs = [lines copy] ?: @[];
    [lock unlock];
}

static NSArray<NSString *> *ZDMAAirliftLastLogs(void) {
    NSLock *lock = ZDMAAirliftLogLock();
    [lock lock];
    NSArray<NSString *> *lines = gZDMAAirliftLastLogs ?: @[];
    [lock unlock];
    return lines;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static NSError *ZDMAAirliftError(NSString *reason, NSArray<NSString *> *diagnostics) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = @"Airlift nuk mundi ta përfundojë operacionin.";
    if (reason.length) info[NSLocalizedFailureReasonErrorKey] = reason;
    if (diagnostics.count) info[@"ZDMADiagnostics"] = diagnostics;
    return [NSError errorWithDomain:ZDMAAirliftErrorDomain code:1 userInfo:info];
}

static NSString *ZDMAAirliftConsumeError(char *errorString) {
    if (!errorString) return nil;
    NSString *copy = [NSString stringWithUTF8String:errorString];
    al_string_free(errorString);
    return copy ?: @"Airlift error (invalid UTF-8)";
}

/// Non-loopback IPv4 addresses; en0 first. Airlift tries these after the
/// LocalDevVPN gateway. 127.0.0.1 is deliberately excluded: on iOS it makes
/// remotepairingdeviced invalidate the control channel.
static NSArray<NSString *> *ZDMAAirliftHostCandidates(void) {
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0 || interfaces == NULL) return @[];

    NSMutableArray<NSString *> *wifi = [NSMutableArray array];
    NSMutableArray<NSString *> *other = [NSMutableArray array];

    for (struct ifaddrs *cur = interfaces; cur != NULL; cur = cur->ifa_next) {
        if (cur->ifa_addr == NULL || cur->ifa_addr->sa_family != AF_INET) continue;
        char buffer[INET_ADDRSTRLEN] = {0};
        const struct sockaddr_in *addr = (const struct sockaddr_in *)cur->ifa_addr;
        if (inet_ntop(AF_INET, &addr->sin_addr, buffer, sizeof(buffer)) == NULL) continue;
        NSString *ip = [NSString stringWithUTF8String:buffer];
        if (!ip.length || [ip hasPrefix:@"127."] || [ip isEqualToString:@"0.0.0.0"]) continue;
        NSString *name = cur->ifa_name ? [NSString stringWithUTF8String:cur->ifa_name] : @"";
        NSMutableArray *bucket = [name isEqualToString:@"en0"] ? wifi : other;
        if (![bucket containsObject:ip]) [bucket addObject:ip];
    }
    freeifaddrs(interfaces);

    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithArray:wifi];
    [result addObjectsFromArray:other];
    if (result.count > 4) return [result subarrayWithRange:NSMakeRange(0, 4)];
    return result;
}

static void ZDMAAirliftConfigureRoute(void) {
    al_set_target_host(ZDMAAirliftDefaultHost.UTF8String);

    NSArray<NSString *> *candidates = ZDMAAirliftHostCandidates();
    if (candidates.count == 0) {
        al_set_target_hosts(NULL, 0);
        return;
    }
    size_t count = candidates.count;
    const char **hosts = calloc(count, sizeof(char *));
    if (!hosts) return;
    for (size_t i = 0; i < count; i++) hosts[i] = candidates[i].UTF8String;
    al_set_target_hosts((const char *const *)hosts, count);
    free(hosts);
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

@implementation AirliftBridge

+ (NSString *)pairingFilePath {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                              NSUserDomainMask, YES).firstObject;
    if (!documents.length) return nil;

    NSArray<NSString *> *names = @[@"rppairing.plist", @"airlift_pairing.plist", @"aircard_pairing.plist"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *name in names) {
        NSString *path = [documents stringByAppendingPathComponent:name];
        NSDictionary *attributes = [fm attributesOfItemAtPath:path error:nil];
        if (!attributes) continue;
        if ([attributes[NSFileSize] unsignedLongLongValue] > 0) return path;
    }
    return nil;
}

+ (BOOL)isAvailable {
    return [self pairingFilePath] != nil;
}

+ (NSArray<NSString *> *)lastLogLines {
    return ZDMAAirliftLastLogs();
}

+ (NSString *)containerForBundleID:(NSString *)bundleID
                               log:(ZDMAAirliftLogBlock)log
                             error:(NSError **)error {
    if (bundleID.length == 0) {
        if (error) *error = ZDMAAirliftError(@"Bundle ID mungon.", nil);
        return nil;
    }
    NSString *pairingPath = [self pairingFilePath];
    if (!pairingPath) {
        if (error) *error = ZDMAAirliftError(
            @"Pairing file (rppairing.plist) mungon. Bëj Start Pairing përsëri.", nil);
        return nil;
    }

    ZDMAAirliftConfigureRoute();

    ZDMAAirliftLogSink *sink = [ZDMAAirliftLogSink new];
    sink.block = log;

    char *outContainer = NULL;
    char *outError = NULL;
    int32_t rc = al_find_app_container(pairingPath.UTF8String,
                                       bundleID.UTF8String,
                                       ZDMAAirliftLogCallback,
                                       (__bridge void *)sink,
                                       &outContainer,
                                       &outError);

    NSArray<NSString *> *lines = [sink snapshot];
    ZDMAAirliftRememberLogs(lines);

    NSString *resolved = nil;
    if (rc == 0 && outContainer != NULL) {
        resolved = [NSString stringWithUTF8String:outContainer];
        al_string_free(outContainer);
    }

    NSString *reason = ZDMAAirliftConsumeError(outError);
    if (resolved.length) {
        if (reason.length) NSLog(@"[Airlift] container lookup warning: %@", reason);
        return resolved;
    }

    if (error) {
        *error = ZDMAAirliftError(reason ?: [NSString stringWithFormat:
            @"Airlift nuk e gjeti kontejnerin për %@ (rc=%d). LocalDevVPN duhet të jetë aktiv.",
            bundleID, rc], lines);
    }
    return nil;
}

+ (BOOL)probeDirectory:(NSString *)targetDirectory
                   log:(ZDMAAirliftLogBlock)log
                 error:(NSError **)error {
    if (targetDirectory.length == 0 || ![targetDirectory hasPrefix:@"/"]) {
        if (error) *error = ZDMAAirliftError(@"Direktoria e provës nuk është absolute.", nil);
        return NO;
    }
    NSString *pairingPath = [self pairingFilePath];
    if (!pairingPath) {
        if (error) *error = ZDMAAirliftError(
            @"Pairing file (rppairing.plist) mungon. Bëj Start Pairing përsëri.", nil);
        return NO;
    }

    ZDMAAirliftConfigureRoute();

    ZDMAAirliftLogSink *sink = [ZDMAAirliftLogSink new];
    sink.block = log;

    char *outJson = NULL;
    char *outError = NULL;
    int32_t rc = al_exploit_run(pairingPath.UTF8String,
                                targetDirectory.UTF8String,
                                ZDMAAirliftLogCallback,
                                (__bridge void *)sink,
                                &outJson,
                                &outError);

    NSArray<NSString *> *lines = [sink snapshot];
    ZDMAAirliftRememberLogs(lines);
    if (outJson) al_string_free(outJson);

    NSString *reason = ZDMAAirliftConsumeError(outError);
    if (rc == 0) return YES;

    if (error) {
        *error = ZDMAAirliftError(reason ?: [NSString stringWithFormat:
            @"Airlift probe dështoi për %@ (rc=%d).", targetDirectory, rc], lines);
    }
    return NO;
}

+ (BOOL)writeFiles:(NSDictionary<NSString *, NSData *> *)files
 toTargetDirectory:(NSString *)targetDirectory
               log:(ZDMAAirliftLogBlock)log
             error:(NSError **)error {
    if (files.count == 0) {
        if (error) *error = ZDMAAirliftError(@"Nuk ka skedarë për të shkruar.", nil);
        return NO;
    }
    if (targetDirectory.length == 0 || ![targetDirectory hasPrefix:@"/"]) {
        if (error) *error = ZDMAAirliftError(@"Direktoria e synuar nuk është absolute.", nil);
        return NO;
    }
    NSString *pairingPath = [self pairingFilePath];
    if (!pairingPath) {
        if (error) *error = ZDMAAirliftError(
            @"Pairing file (rppairing.plist) mungon. Bëj Start Pairing përsëri.", nil);
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *staging = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"zdma-airlift-%@", NSUUID.UUID.UUIDString]];
    NSError *localError = nil;
    if (![fm createDirectoryAtPath:staging withIntermediateDirectories:YES
                        attributes:nil error:&localError]) {
        if (error) *error = ZDMAAirliftError(
            [NSString stringWithFormat:@"Staging dir: %@", localError.localizedDescription], nil);
        return NO;
    }

    BOOL staged = YES;
    for (NSString *leaf in files) {
        NSData *blob = files[leaf];
        if (![leaf isKindOfClass:[NSString class]] || leaf.length == 0 ||
            [leaf containsString:@"/"] || [leaf hasPrefix:@"."] ||
            ![blob isKindOfClass:[NSData class]] || blob.length == 0) {
            staged = NO;
            break;
        }
        NSString *path = [staging stringByAppendingPathComponent:leaf];
        if (![blob writeToFile:path options:NSDataWritingAtomic error:&localError]) {
            staged = NO;
            break;
        }
    }
    if (!staged) {
        [fm removeItemAtPath:staging error:nil];
        if (error) *error = ZDMAAirliftError(
            [NSString stringWithFormat:@"Staging shkrimi dështoi: %@",
             localError.localizedDescription ?: @"skedar i pavlefshëm"], nil);
        return NO;
    }

    ZDMAAirliftConfigureRoute();

    ZDMAAirliftLogSink *sink = [ZDMAAirliftLogSink new];
    sink.block = log;

    char *outError = NULL;
    int32_t rc = al_exploit_write_dir(pairingPath.UTF8String,
                                      staging.UTF8String,
                                      targetDirectory.UTF8String,
                                      ZDMAAirliftLogCallback,
                                      (__bridge void *)sink,
                                      &outError);

    NSArray<NSString *> *lines = [sink snapshot];
    ZDMAAirliftRememberLogs(lines);
    [fm removeItemAtPath:staging error:nil];

    NSString *reason = ZDMAAirliftConsumeError(outError);
    if (rc == 0) return YES;

    if (error) {
        *error = ZDMAAirliftError(reason ?: [NSString stringWithFormat:
            @"Airlift write dështoi (rc=%d). Kontrollo LocalDevVPN dhe që iPhone është i shkyçur.", rc],
            lines);
    }
    return NO;
}

@end
