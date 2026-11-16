#import <Foundation/Foundation.h>

@interface AirliftBridge : NSObject
+ (BOOL)writeFile:(NSString *)filePath toContainer:(NSString *)containerPath;
@end
