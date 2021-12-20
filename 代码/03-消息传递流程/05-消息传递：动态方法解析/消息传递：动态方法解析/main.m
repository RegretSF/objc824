//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>
@interface SHPerson : NSObject
- (void)helloWorld;
@end
@implementation SHPerson
- (void)helloWorld {
    NSLog(@"%s", __func__);
}
@end

@interface SHStudent : SHPerson
- (void)play_1;
+ (void)play_2;
- (void)play_3;
@end
@implementation SHStudent
- (void)play_1 {
    NSLog(@"%s", __func__);
}
@end

@implementation NSObject(Category)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == NSSelectorFromString(@"play_3")) {
        NSLog(@"%s",__func__);
    }
    
    return NO;
}


+ (BOOL)resolveClassMethod:(SEL)sel {
    NSLog(@"%s",__func__);
    return NO;
}
#pragma clang diagnostic pop
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SHStudent *s = [[SHStudent alloc] init];
//        [s helloWorld];
//        [s play_1];
        [SHStudent play_2];
        [s play_3];

        
    }
    return 0;
}
