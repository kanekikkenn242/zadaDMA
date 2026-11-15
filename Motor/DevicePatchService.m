#import "DevicePatchService.h"
#import "PatchTransaction.h"
#import "PatchPackageCodec.h"
#import <dlfcn.h>
@implementation DevicePatchService
+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    void *h=dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",RTLD_LAZY);
    Class ws=NSClassFromString(@"LSApplicationWorkspace");
    if(!ws){ if(h)dlclose(h); return nil; }
    id workspace=[ws performSelector:@selector(defaultWorkspace)];
    NSArray *apps=[workspace performSelector:@selector(allInstalledApplications)];
    NSString *out=nil;
    for(id app in apps){
        NSString *bid=[app performSelector:@selector(applicationIdentifier)];
        if([bid isEqualToString:bundleID]){
            NSURL *url=[app performSelector:@selector(dataContainerURL)];
            if(!url) url=[app performSelector:@selector(bundleContainerURL)];
            if(url){ out=url.path; break; }
        }
    }
    if(h)dlclose(h);
    return out;
}
+ (BOOL)applyPatch:(PatchPackage *)pkg toBundleID:(NSString *)bundleID error:(NSError **)err {
    NSString *c=[self containerPathForBundleID:bundleID];
    if(!c){ if(err)*err=[NSError errorWithDomain:@"patch" code:ENOENT userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"container not found: %@",bundleID]}]; return NO; }
    return [PatchTransaction applyPackage:pkg container:c bundleID:bundleID error:err];
}
@end
