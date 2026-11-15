#import <Foundation/Foundation.h>
@interface MotorBridge : NSObject
+ (BOOL)bootstrap;
+ (BOOL)applyPatch:(NSString *)patchName;
@end
