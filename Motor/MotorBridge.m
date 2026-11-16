// Kthen path-in e container-it te app-it
+ (NSString *)containerPathForBundleID:(NSString *)bundleID {
    Class ws = NSClassFromString(@"LSApplicationWorkspace");
    if (!ws) return @"";
    id workspace = [ws performSelector:@selector(defaultWorkspace)];
    for (id app in [workspace performSelector:@selector(allInstalledApplications)]) {
        NSString *bid = [app performSelector:@selector(applicationIdentifier)];
        if ([bid isEqualToString:bundleID]) {
            NSURL *url = [app performSelector:@selector(dataContainerURL)];
            if (!url) url = [app performSelector:@selector(bundleContainerURL)];
            if (url) return url.path;
        }
    }
    return @"";
}
