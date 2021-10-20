//
//  Person.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "Person.h"

@implementation Person

static Person *instance = nil;
+ (instancetype)sharedInstance {
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        instance = [Person new];
    });
    return instance;
}

- (NSMutableArray *)courses {
    if (!_courses) {
        _courses = [NSMutableArray arrayWithObjects:@"Language", @"Mathematics", @"English", @"Physics", @"chemistry", @"biology", @"politics", @"History", nil];
    }
    return _courses;
}
@end
