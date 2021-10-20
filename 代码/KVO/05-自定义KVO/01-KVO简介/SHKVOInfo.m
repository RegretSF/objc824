//
//  SHKVOInfo.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/14.
//

#import "SHKVOInfo.h"

@implementation SHKVOInfo
- (instancetype)initWithObserver:(id)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options {
    self = [super init];
    if (self) {
        self.observer = observer;
        self.keyPath = keyPath;
        self.options = options;
    }
    return self;
}
@end
