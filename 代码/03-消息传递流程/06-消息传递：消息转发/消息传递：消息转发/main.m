//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

extern void instrumentObjcMessageSends(BOOL flag);

@interface SHPerson : NSObject
- (void)helloWorld;
@end
@implementation SHPerson
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SHPerson *p = [[SHPerson alloc] init];
        instrumentObjcMessageSends(YES);
        [p helloWorld];
        instrumentObjcMessageSends(NO);
    }
    return 0;
}

