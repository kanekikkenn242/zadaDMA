#import "IdeviceBridge.h"
#import "zdma_pairing.h"

#import <arpa/inet.h>
#import <dns_sd.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <netinet/in.h>

static NSString *ZDMADNSServiceErrorText(DNSServiceErrorType error) {
    switch (error) {
        case kDNSServiceErr_NoError: return @"OK";
        case kDNSServiceErr_Unknown: return @"gabim i panjohur";
        case kDNSServiceErr_NoAuth: return @"pa autorizim";
        case kDNSServiceErr_NameConflict: return @"emri është në përdorim";
        case kDNSServiceErr_BadParam: return @"parametër i pavlefshëm";
        case kDNSServiceErr_BadReference: return @"referencë e pavlefshme";
        case kDNSServiceErr_Unsupported: return @"i pambështetur";
        case kDNSServiceErr_NotInitialized: return @"mDNS nuk u inicializua";
        case kDNSServiceErr_AlreadyRegistered: return @"tashmë i regjistruar";
        case kDNSServiceErr_BadInterfaceIndex: return @"interface i pavlefshëm";
        case kDNSServiceErr_ServiceNotRunning: return @"mDNS service nuk punon";
        case kDNSServiceErr_PolicyDenied: return @"Local Network permission u refuzua";
        case kDNSServiceErr_Timeout: return @"timeout";
        default: return @"gabim Bonjour";
    }
}

static NSDictionary<NSString *, NSString *> *ZDMAParseTXT(NSData *data) {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    const uint8_t *bytes = data.bytes;
    NSUInteger total = data.length;
    NSUInteger offset = 0;
    while (offset < total) {
        uint8_t length = bytes[offset++];
        if (length == 0 || offset + length > total) { break; }
        NSString *entry = [[NSString alloc] initWithBytes:bytes + offset
                                                   length:length
                                                 encoding:NSUTF8StringEncoding];
        offset += length;
        if (!entry) { continue; }
        NSRange separator = [entry rangeOfString:@"="];
        if (separator.location == NSNotFound) { continue; }
        values[[entry substringToIndex:separator.location]] =
            [entry substringFromIndex:separator.location + 1];
    }
    return values;
}

@class IdeviceBridge;

@interface ZDMAServiceCandidate : NSObject
@property (nonatomic, weak) IdeviceBridge *bridge;
@property (nonatomic, copy) NSString *hostname;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *txt;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) DNSServiceRef resolveRef;
@property (nonatomic, assign) DNSServiceRef addressRef;
@property (nonatomic, copy) NSString *ipAddress;
@end

@implementation ZDMAServiceCandidate
@end

@interface IdeviceBridge ()
@property (nonatomic, assign) DNSServiceRef hostRegistration;
@property (nonatomic, assign) DNSServiceRef browseRegistration;
@property (nonatomic, strong) NSMutableArray<ZDMAServiceCandidate *> *candidates;
@property (nonatomic, strong) NSTimer *browseTimer;

@property (nonatomic, copy, nullable) void (^hostCompletion)(BOOL, NSString *);
@property (nonatomic, copy, nullable) void (^pinBlock)(NSString *);
@property (nonatomic, copy, nullable) void (^readyBlock)(NSString *, uint16_t);
@property (nonatomic, assign) BOOL hostRunning;
@property (nonatomic, copy, nullable) NSString *publishError;

@property (nonatomic, copy, nullable) void (^writeCompletion)(BOOL, NSString *);
@property (nonatomic, copy, nullable) NSString *writeLocalPath;
@property (nonatomic, copy, nullable) NSString *writeBundleID;
@property (nonatomic, copy, nullable) NSString *writeRemotePath;
@property (nonatomic, copy, nullable) NSString *writePairingPath;
@property (nonatomic, copy, nullable) NSString *writeHostname;

@property (nonatomic, strong) dispatch_queue_t hostQueue;
@property (nonatomic, strong) dispatch_queue_t ioQueue;

- (void)stopHostRegistration;
- (void)handleHostRegistrationError:(DNSServiceErrorType)error;
- (void)handleResolvedCandidate:(NSDictionary *)candidate;
- (void)finishWrite:(BOOL)success message:(NSString *)message;
@end

static void ZDMABrowseReply(DNSServiceRef sdRef,
                            DNSServiceFlags flags,
                            uint32_t interfaceIndex,
                            DNSServiceErrorType errorCode,
                            const char *serviceName,
                            const char *regtype,
                            const char *replyDomain,
                            void *context);

static void ZDMAResolveReply(DNSServiceRef sdRef,
                             DNSServiceFlags flags,
                             uint32_t interfaceIndex,
                             DNSServiceErrorType errorCode,
                             const char *fullname,
                             const char *hosttarget,
                             uint16_t port,
                             uint16_t txtLen,
                             const unsigned char *txtRecord,
                             void *context);

static void ZDMAAddrInfoReply(DNSServiceRef sdRef,
                              DNSServiceFlags flags,
                              uint32_t interfaceIndex,
                              DNSServiceErrorType errorCode,
                              const char *hostname,
                              const struct sockaddr *address,
                              uint32_t ttl,
                              void *context);

static void ZDMAHostRegisterReply(DNSServiceRef sdRef,
                                  DNSServiceFlags flags,
                                  DNSServiceErrorType errorCode,
                                  const char *name,
                                  const char *regtype,
                                  const char *domain,
                                  void *context) {
    (void)flags;
    IdeviceBridge *bridge = (__bridge IdeviceBridge *)context;
    if (errorCode == kDNSServiceErr_NoError) {
        NSLog(@"[IdeviceBridge] pairable host registered: %s.%s%s",
              name ?: "", regtype ?: "", domain ?: "");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!bridge.hostRunning || bridge.hostRegistration != sdRef) { return; }
        [bridge handleHostRegistrationError:errorCode];
    });
}

static void ZDMABrowseReply(DNSServiceRef sdRef,
                            DNSServiceFlags flags,
                            uint32_t interfaceIndex,
                            DNSServiceErrorType errorCode,
                            const char *serviceName,
                            const char *regtype,
                            const char *replyDomain,
                            void *context) {
    (void)sdRef;
    IdeviceBridge *bridge = (__bridge IdeviceBridge *)context;
    if (errorCode != kDNSServiceErr_NoError) {
        [bridge finishWrite:NO
                    message:[NSString stringWithFormat:
                        @"Bonjour browse dështoi (%d: %@). Kontrollo Local Network permission.",
                        (int)errorCode, ZDMADNSServiceErrorText(errorCode)]];
        return;
    }
    if (!(flags & kDNSServiceFlagsAdd)) { return; }
    if (!bridge.writeCompletion || !serviceName || !regtype) { return; }

    ZDMAServiceCandidate *candidate = [[ZDMAServiceCandidate alloc] init];
    candidate.bridge = bridge;
    candidate.ipAddress = nil;  // will be set in ZDMAResolveReply if successful
    DNSServiceRef resolver = NULL;
    DNSServiceErrorType resolveError = DNSServiceResolve(&resolver,
                                                         0,
                                                         interfaceIndex,
                                                         serviceName,
                                                         regtype,
                                                         replyDomain,
                                                         ZDMAResolveReply,
                                                         (__bridge void *)candidate);
    if (resolveError != kDNSServiceErr_NoError || resolver == NULL) {
        NSLog(@"[IdeviceBridge] resolve setup failed: %d", (int)resolveError);
        return;
    }
    candidate.resolveRef = resolver;
    [bridge.candidates addObject:candidate];
    DNSServiceSetDispatchQueue(resolver, dispatch_get_main_queue());
    NSLog(@"[IdeviceBridge] resolving %s", serviceName);
}

static void ZDMAResolveReply(DNSServiceRef sdRef,
                             DNSServiceFlags flags,
                             uint32_t interfaceIndex,
                             DNSServiceErrorType errorCode,
                             const char *fullname,
                             const char *hosttarget,
                             uint16_t port,
                             uint16_t txtLen,
                             const unsigned char *txtRecord,
                             void *context) {
    (void)sdRef;
    (void)flags;
    (void)fullname;
    ZDMAServiceCandidate *candidate = (__bridge ZDMAServiceCandidate *)context;
    IdeviceBridge *bridge = candidate.bridge;
    if (!bridge || ![bridge.candidates containsObject:candidate]) { return; }
    if (candidate.resolveRef) {
        DNSServiceRefDeallocate(candidate.resolveRef);
        candidate.resolveRef = NULL;
    }
    if (errorCode != kDNSServiceErr_NoError || !hosttarget) {
        NSLog(@"[IdeviceBridge] resolve failed: %d", (int)errorCode);
        [bridge.candidates removeObject:candidate];
        return;
    }
    candidate.hostname = [NSString stringWithUTF8String:hosttarget];
    candidate.port = ntohs(port);
    candidate.txt = ZDMAParseTXT(txtRecord
                                 ? [NSData dataWithBytes:txtRecord length:txtLen]
                                 : [NSData data]);
    DNSServiceRef addrRef = NULL;
    DNSServiceErrorType addrError = DNSServiceGetAddrInfo(&addrRef,
                                                          0,
                                                          interfaceIndex,
                                                          kDNSServiceProtocol_IPv4,
                                                          hosttarget,
                                                          ZDMAAddrInfoReply,
                                                          (__bridge void *)candidate);
    if (addrError != kDNSServiceErr_NoError || addrRef == NULL) {
        NSLog(@"[IdeviceBridge] getaddrinfo setup failed: %d", (int)addrError);
        [bridge.candidates removeObject:candidate];
        return;
    }
    candidate.addressRef = addrRef;
    DNSServiceSetDispatchQueue(addrRef, dispatch_get_main_queue());
    // Store the IP address for later use in candidate address list
    candidate.ipAddress = nil;  // will be set in ZDMAAddrInfoReply if successful
}

static void ZDMAAddrInfoReply(DNSServiceRef sdRef,
                              DNSServiceFlags flags,
                              uint32_t interfaceIndex,
                              DNSServiceErrorType errorCode,
                              const char *hostname,
                              const struct sockaddr *address,
                              uint32_t ttl,
                              void *context) {
    (void)sdRef;
    (void)flags;
    (void)interfaceIndex;
    (void)hostname;
    (void)ttl;
    ZDMAServiceCandidate *candidate = (__bridge ZDMAServiceCandidate *)context;
    IdeviceBridge *bridge = candidate.bridge;
    if (!bridge || ![bridge.candidates containsObject:candidate]) { return; }
    if (errorCode != kDNSServiceErr_NoError || address == NULL) {
        if (errorCode != kDNSServiceErr_NoError) {
            NSLog(@"[IdeviceBridge] addr info failed: %d", (int)errorCode);
            if (candidate.addressRef) {
                DNSServiceRefDeallocate(candidate.addressRef);
                candidate.addressRef = NULL;
            }
            [bridge.candidates removeObject:candidate];
        }
        return;
    }
    if (address->sa_family != AF_INET) { return; }
    const struct sockaddr_in *sin = (const struct sockaddr_in *)address;
    char buffer[INET_ADDRSTRLEN] = {0};
    if (!inet_ntop(AF_INET, &sin->sin_addr, buffer, sizeof(buffer))) { return; }
    NSDictionary *resolved = @{
        @"ip": [NSString stringWithUTF8String:buffer],
        @"port": @(candidate.port),
        @"identifier": candidate.txt[@"identifier"] ?: @"",
        @"authTag": candidate.txt[@"authTag"] ?: @"",
    };
    NSLog(@"[IdeviceBridge] resolved %@ -> %@:%u txt=%@",
          candidate.hostname, resolved[@"ip"], candidate.port, candidate.txt);
    candidate.ipAddress = [NSString stringWithUTF8String:buffer];
    if (candidate.addressRef) {
        DNSServiceRefDeallocate(candidate.addressRef);
        candidate.addressRef = NULL;
    }
    [bridge.candidates removeObject:candidate];
    [bridge handleResolvedCandidate:resolved];
}

@implementation IdeviceBridge

+ (instancetype)shared {
    static IdeviceBridge *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[IdeviceBridge alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hostQueue = dispatch_queue_create("com.zadaDMA.idevice.host", DISPATCH_QUEUE_SERIAL);
        _ioQueue = dispatch_queue_create("com.zadaDMA.idevice.io", DISPATCH_QUEUE_SERIAL);
        _candidates = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Pairable host

static void ZDMAReadyTrampoline(const char *identifier,
                                const char *name,
                                const char *model,
                                const char *authTag,
                                const char *flags,
                                const char *ver,
                                const char *minVer,
                                uint16_t port,
                                void *ctx) {
    IdeviceBridge *bridge = (__bridge IdeviceBridge *)ctx;
    NSString *sIdentifier = identifier ? [NSString stringWithUTF8String:identifier] : @"";
    NSString *sName = name ? [NSString stringWithUTF8String:name] : @"zadaDMA";
    NSString *sModel = model ? [NSString stringWithUTF8String:model] : @"Mac17,7";
    NSString *sAuth = authTag ? [NSString stringWithUTF8String:authTag] : @"";
    NSString *sFlags = flags ? [NSString stringWithUTF8String:flags] : @"1";
    NSString *sVer = ver ? [NSString stringWithUTF8String:ver] : @"26";
    NSString *sMin = minVer ? [NSString stringWithUTF8String:minVer] : @"17";
    [bridge publishHostWithIdentifier:sIdentifier
                                 name:sName
                                model:sModel
                              authTag:sAuth
                                flags:sFlags
                                  ver:sVer
                               minVer:sMin
                                 port:port];
}

static void ZDMAPinTrampoline(const char *pin, void *ctx) {
    IdeviceBridge *bridge = (__bridge IdeviceBridge *)ctx;
    NSString *value = pin ? [NSString stringWithUTF8String:pin] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        if (bridge.pinBlock) { bridge.pinBlock(value); }
    });
}

- (void)publishHostWithIdentifier:(NSString *)identifier
                             name:(NSString *)name
                            model:(NSString *)model
                          authTag:(NSString *)authTag
                            flags:(NSString *)flags
                              ver:(NSString *)ver
                           minVer:(NSString *)minVer
                             port:(uint16_t)port {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.hostRunning) { return; }
        [self stopHostRegistration];

        NSDictionary<NSString *, NSString *> *records = @{
            @"name": name,
            @"identifier": identifier,
            @"authTag": authTag,
            @"model": model,
            @"flags": flags,
            @"ver": ver,
            @"minVer": minVer,
        };
        TXTRecordRef txt;
        TXTRecordCreate(&txt, 0, NULL);
        for (NSString *key in records) {
            NSString *value = records[key];
            const char *keyBytes = key.UTF8String;
            const char *valueBytes = value.UTF8String;
            if (!keyBytes || !valueBytes) { continue; }
            size_t valueLength = strlen(valueBytes);
            if (valueLength > 255) { valueLength = 255; }
            DNSServiceErrorType txtError = TXTRecordSetValue(&txt,
                                                             keyBytes,
                                                             (uint8_t)valueLength,
                                                             valueBytes);
            if (txtError != kDNSServiceErr_NoError) {
                NSLog(@"[IdeviceBridge] TXTRecordSetValue %@ failed: %d", key, (int)txtError);
            }
        }

        DNSServiceRef ref = NULL;
        DNSServiceErrorType error = DNSServiceRegister(&ref,
                                                       0,
                                                       kDNSServiceInterfaceIndexAny,
                                                       identifier.UTF8String,
                                                       "_remotepairing-pairable-host._tcp",
                                                       NULL,
                                                       NULL,
                                                       htons(port),
                                                       TXTRecordGetLength(&txt),
                                                       TXTRecordGetBytesPtr(&txt),
                                                       ZDMAHostRegisterReply,
                                                       (__bridge void *)self);
        TXTRecordDeallocate(&txt);

        if (error != kDNSServiceErr_NoError || ref == NULL) {
            if (ref) { DNSServiceRefDeallocate(ref); }
            [self handleHostRegistrationError:error == kDNSServiceErr_NoError
                                                  ? kDNSServiceErr_Unknown
                                                  : error];
            return;
        }

        self.hostRegistration = ref;
        DNSServiceErrorType queueError = DNSServiceSetDispatchQueue(ref, dispatch_get_main_queue());
        if (queueError != kDNSServiceErr_NoError) {
            [self stopHostRegistration];
            [self handleHostRegistrationError:queueError];
            return;
        }

        NSLog(@"[IdeviceBridge] advertising pairable host %@ port %u (dns_sd)", name, port);
        if (self.readyBlock) { self.readyBlock(identifier, port); }
    });
}

- (void)handleHostRegistrationError:(DNSServiceErrorType)error {
    if (!self.hostRunning) { return; }
    NSLog(@"[IdeviceBridge] pairable host registration failed: %d (%@)",
          (int)error, ZDMADNSServiceErrorText(error));
    if (error == kDNSServiceErr_PolicyDenied) {
        self.publishError = @"Local Network permission u refuzua. Shko Settings › Apps › zadaDMA › Local Network → ON, pastaj provo përsëri.";
    } else {
        self.publishError = [NSString stringWithFormat:
            @"mDNS publish dështoi (%d: %@). Kontrollo që Wi-Fi është ON, VPN OFF dhe Local Network ON për zadaDMA.",
            (int)error, ZDMADNSServiceErrorText(error)];
    }
    zdma_pairing_host_cancel();
}

- (void)stopHostRegistration {
    if (self.hostRegistration) {
        DNSServiceRefDeallocate(self.hostRegistration);
        self.hostRegistration = NULL;
    }
}

- (void)startPairableHostWithName:(NSString *)name
                            model:(NSString *)model
                             port:(uint16_t)port
                  pairingFilePath:(NSString *)pairingFilePath
                       readyBlock:(void (^)(NSString *, uint16_t))readyBlock
                         pinBlock:(void (^)(NSString *))pinBlock
                       completion:(void (^)(BOOL, NSString *))completion {
    if (self.hostRunning) {
        completion(NO, @"Pairing already running");
        return;
    }
    self.hostRunning = YES;
    self.publishError = nil;
    self.hostCompletion = completion;
    self.readyBlock = readyBlock;
    self.pinBlock = pinBlock;

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.hostQueue, ^{
        char err[2048] = {0};
        int rc = zdma_pairing_host_accept(name.UTF8String,
                                          model.UTF8String,
                                          port,
                                          ZDMAReadyTrampoline,
                                          ZDMAPinTrampoline,
                                          (__bridge void *)weakSelf,
                                          pairingFilePath.UTF8String,
                                          err,
                                          sizeof(err));
        NSString *message = err[0] ? [NSString stringWithUTF8String:err] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            IdeviceBridge *strongSelf = weakSelf;
            if (!strongSelf) { return; }
            strongSelf.hostRunning = NO;
            [strongSelf stopHostRegistration];
            void (^done)(BOOL, NSString *) = strongSelf.hostCompletion;
            NSString *publishError = strongSelf.publishError;
            strongSelf.hostCompletion = nil;
            strongSelf.readyBlock = nil;
            strongSelf.pinBlock = nil;
            strongSelf.publishError = nil;
            if (done) {
                if (rc == 0) {
                    done(YES, message.length ? message : @"Paired");
                } else if (publishError.length) {
                    done(NO, publishError);
                } else {
                    done(NO, message.length ? message : @"Pairing failed");
                }
            }
        });
    });
}

- (void)cancelPairableHost {
    zdma_pairing_host_cancel();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopHostRegistration];
    });
}

#pragma mark - AFC write

- (void)writeFileAtPath:(NSString *)localPath
               bundleID:(NSString *)bundleID
             remotePath:(NSString *)remotePath
        pairingFilePath:(NSString *)pairingFilePath
               hostname:(NSString *)hostname
             completion:(void (^)(BOOL, NSString *))completion {
    if (self.writeCompletion) {
        completion(NO, @"Another write is already running");
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:pairingFilePath]) {
        completion(NO, @"Pairing file mungon. Bëj Start Pairing së pari.");
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        completion(NO, @"Skedari .3105 mungon në app.");
        return;
    }

    self.writeCompletion = completion;
    self.writeLocalPath = localPath;
    self.writeBundleID = bundleID;
    self.writeRemotePath = remotePath;
    self.writePairingPath = pairingFilePath;
    self.writeHostname = hostname;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self startBrowsing];
    });
}

- (void)startBrowsing {
    [self stopBrowsing];
    DNSServiceRef ref = NULL;
    DNSServiceErrorType error = DNSServiceBrowse(&ref,
                                                 0,
                                                 kDNSServiceInterfaceIndexAny,
                                                 "_remotepairing._tcp",
                                                 "local.",
                                                 ZDMABrowseReply,
                                                 (__bridge void *)self);
    if (error != kDNSServiceErr_NoError || ref == NULL) {
        [self finishWrite:NO
                  message:[NSString stringWithFormat:
                      @"Bonjour browse nuk nisi (%d: %@). Kontrollo Local Network permission.",
                      (int)error, ZDMADNSServiceErrorText(error)]];
        return;
    }
    self.browseRegistration = ref;
    DNSServiceSetDispatchQueue(ref, dispatch_get_main_queue());
    NSLog(@"[IdeviceBridge] browsing _remotepairing._tcp (dns_sd)");

    __weak typeof(self) weakSelf = self;
    self.browseTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                       repeats:NO
                                                         block:^(NSTimer *timer) {
        IdeviceBridge *strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [strongSelf finishWrite:NO
                        message:@"Nuk u gjet _remotepairing._tcp me authTag që përputhet me pairing file. Bëj Start Pairing përsëri. Kontrollo: Developer Mode ON, i njëjti Wi-Fi, Local Network permission, VPN OFF."];
    }];
}

- (void)stopBrowsing {
    if (self.browseRegistration) {
        DNSServiceRefDeallocate(self.browseRegistration);
        self.browseRegistration = NULL;
    }
    for (ZDMAServiceCandidate *candidate in self.candidates) {
        if (candidate.resolveRef) {
            DNSServiceRefDeallocate(candidate.resolveRef);
            candidate.resolveRef = NULL;
        }
        if (candidate.addressRef) {
            DNSServiceRefDeallocate(candidate.addressRef);
            candidate.addressRef = NULL;
        }
    }
    [self.candidates removeAllObjects];
    [self.browseTimer invalidate];
    self.browseTimer = nil;
}

- (void)handleResolvedCandidate:(NSDictionary *)candidate {
    if (!self.writeCompletion) { return; }

    if (![candidate[@"identifier"] length] || ![candidate[@"authTag"] length]) {
        return;
    }
    // Only the advertisement whose authTag validates against the peer altIRK in
    // our pairing file may be contacted. A candidate from an unrelated device (or
    // a stale pairing) must never receive pair-verify.
    int match = zdma_pairing_file_validate(self.writePairingPath.UTF8String,
                                           [candidate[@"identifier"] UTF8String],
                                           [candidate[@"authTag"] UTF8String]);
    if (match == -1) {
        [self finishWrite:NO
                  message:@"Pairing file nuk lexohet. Bëj Start Pairing përsëri."];
        return;
    }
    if (match != 1) { return; }

    [self performWriteWithCandidate:candidate];
}

- (NSString *)candidateAddressList {
    // Build a comma-separated list of addresses to try, in order of preference:
    //  1. IPv4 loopback 127.0.0.1
    //  2. IPv6 loopback ::1
    //  3. All mDNS-resolved addresses (IPv4 and IPv6) already in candidates
    //  4. utun interface addresses (from getifaddrs)
    //  5. own-interface addresses
    //
    // This list is passed to zdma_tunnel_write_file which tries each endpoint.
    NSMutableArray *parts = [NSMutableArray array];

    // 1. IPv4 loopback
    [parts addObject:@"127.0.0.1"];

    // 2. IPv6 loopback
    [parts addObject:@"::1"];

    // 3. mDNS-resolved candidates already gathered (IPv4 and IPv6)
    for (ZDMAServiceCandidate *cand in self.candidates) {
        NSString *ip = cand.ipAddress;
        if (!ip) continue;
        // Avoid duplicates
        if (![parts containsObject:ip]) {
            [parts addObject:ip];
        }
    }

    // 4. utun interface addresses
    struct ifaddrs *ifap = NULL;
    if (getifaddrs(&ifap) == 0) {
        struct ifaddrs *cur = ifap;
        while (cur) {
            if (cur->ifa_addr &&
                cur->ifa_addr->sa_family == AF_INET) {
                // Only non-loopback utun IPv4
                struct sockaddr_in *sin = (struct sockaddr_in *)cur->ifa_addr;
                char ipstr[INET_ADDRSTRLEN];
                if (inet_ntop(AF_INET, &sin->sin_addr, ipstr, sizeof(ipstr))) {
                    NSString *ipStr = [NSString stringWithUTF8String:ipstr];
                    if ([ipStr compare:@"127.0.0.0"] != NSOrderedSame &&
                        ![parts containsObject:ipStr]) {
                        [parts addObject:ipStr];
                    }
                }
            }
            if (cur->ifa_addr &&
                cur->ifa_addr->sa_family == AF_INET6) {
                struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)cur->ifa_addr;
                char ipstr[INET6_ADDRSTRLEN];
                if (inet_ntop(AF_INET6, &sin6->sin6_addr, ipstr, sizeof(ipstr))) {
                    NSString *ipStr = [NSString stringWithUTF8String:ipstr];
                    if (![ipStr hasPrefix:@"fe80::"] &&  // skip link-local IPv6
                        ![parts containsObject:ipStr]) {
                        [parts addObject:ipStr];
                    }
                }
            }
            cur = cur->ifa_next;
        }
        freeifaddrs(ifap);
    }

    // Format as comma-separated string
    return [parts componentsJoinedByString:@","];
}

- (void)performWriteWithCandidate:(NSDictionary *)candidate {
    if (!self.writeCompletion) { return; }
    NSNumber *portNum = candidate[@"port"];
    uint16_t port = [portNum unsignedShortValue];
    NSString *localPath = self.writeLocalPath;
    NSString *bundleID = self.writeBundleID;
    NSString *remotePath = self.writeRemotePath;
    NSString *pairingPath = self.writePairingPath;
    NSString *hostname = self.writeHostname;
    void (^done)(BOOL, NSString *) = self.writeCompletion;

    // Stop browsing before clearing state.
    [self stopBrowsing];
    self.writeCompletion = nil;
    self.writeLocalPath = nil;
    self.writeBundleID = nil;
    self.writeRemotePath = nil;
    self.writePairingPath = nil;
    self.writeHostname = nil;

    NSLog(@"[IdeviceBridge] writing via candidate list");
    dispatch_async(self.ioQueue, ^{
        // Gather all addresses to try: loopback + current candidate IP + utun addresses
        NSMutableArray *parts = [NSMutableArray array];
        [parts addObject:@"127.0.0.1"];
        [parts addObject:@"::1"];
        // Add the current candidate's resolved IP
        NSString *currentIP = candidate[@"ip"];
        if (currentIP && ![parts containsObject:currentIP]) {
            [parts addObject:currentIP];
        }
        // Add utun interface addresses
        struct ifaddrs *ifap = NULL;
        if (getifaddrs(&ifap) == 0) {
            struct ifaddrs *cur = ifap;
            while (cur) {
                if (cur->ifa_addr && cur->ifa_addr->sa_family == AF_INET) {
                    struct sockaddr_in *sin = (struct sockaddr_in *)cur->ifa_addr;
                    char ipstr[INET_ADDRSTRLEN];
                    if (inet_ntop(AF_INET, &sin->sin_addr, ipstr, sizeof(ipstr))) {
                        NSString *ipStr = [NSString stringWithUTF8String:ipstr];
                        if ([ipStr compare:@"127.0.0.0"] != NSOrderedSame &&
                            ![parts containsObject:ipStr]) {
                            [parts addObject:ipStr];
                        }
                    }
                }
                if (cur->ifa_addr && cur->ifa_addr->sa_family == AF_INET6) {
                    struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)cur->ifa_addr;
                    char ipstr[INET6_ADDRSTRLEN];
                    if (inet_ntop(AF_INET6, &sin6->sin6_addr, ipstr, sizeof(ipstr))) {
                        NSString *ipStr = [NSString stringWithUTF8String:ipstr];
                        if (![ipStr hasPrefix:@"fe80::"] && ![parts containsObject:ipStr]) {
                            [parts addObject:ipStr];
                        }
                    }
                }
                cur = cur->ifa_next;
            }
            freeifaddrs(ifap);
        }
        NSString *addrsList = [parts componentsJoinedByString:@","];
        char err[4096] = {0};
        char out[2048] = {0};
        int rc = zdma_tunnel_write_file(addrsList.UTF8String,
                                        port,
                                        hostname.UTF8String,
                                        pairingPath.UTF8String,
                                        bundleID.UTF8String,
                                        remotePath.UTF8String,
                                        localPath.UTF8String,
                                        err,
                                        sizeof(err),
                                        out,
                                        sizeof(out));
        NSString *message = rc == 0
            ? (out[0] ? [NSString stringWithUTF8String:out] : @"OK")
            : (err[0] ? [NSString stringWithUTF8String:err] : @"AFC write failed");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (done) { done(rc == 0, message); }
        });
    });
}

- (void)finishWrite:(BOOL)success message:(NSString *)message {
    if (!self.writeCompletion) { return; }
    void (^done)(BOOL, NSString *) = self.writeCompletion;
    self.writeCompletion = nil;
    self.writeLocalPath = nil;
    self.writeBundleID = nil;
    self.writeRemotePath = nil;
    self.writePairingPath = nil;
    self.writeHostname = nil;
    [self stopBrowsing];
    if (done) { done(success, message); }
}

@end
