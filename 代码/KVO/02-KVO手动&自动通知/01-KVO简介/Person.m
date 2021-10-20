//
//  Person.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "Person.h"

@implementation Person
- (NSMutableArray *)courses {
    if (!_courses) {
        _courses = [NSMutableArray arrayWithObjects:@"Language", @"Mathematics", @"English", @"Physics", @"chemistry", @"biology", @"politics", @"History", nil];
    }
    return _courses;
}

//- (void)setName:(NSString *)name {
//    [self willChangeValueForKey:@"name"];
//    _name = name;
//    [self didChangeValueForKey:@"name"];
//}

- (void)setName:(NSString *)name {
    [self willChangeValueForKey:@"name"];
    [self willChangeValueForKey:@"age"];
    _name = name;
    _age = _age += 1;
    [self didChangeValueForKey:@"name"];
    [self didChangeValueForKey:@"age"];
}

//// 可变容器添加手动kvo，可变容器内部元素发生添加，移除，替换时触发kvo
//// 插入单个 元素
//- (void)insertObject:(NSString *)object inCoursesAtIndex:(NSUInteger)index{
//    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"courses"];
//    [_courses insertObject:object atIndex:index];
//    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"courses"];
//}
//
//// 删除 单个元素
//- (void)removeObjectFromCoursesAtIndex:(NSUInteger)index{
//    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"courses"];
//    [_courses removeObjectAtIndex:index];
//    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"courses"];
//}
//// 插入 多个元素
//- (void)insertCourses:(NSArray *)array atIndexes:(NSIndexSet *)indexes{
//    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"courses"];
//    [_courses insertObjects:array atIndexes:indexes];
//    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"courses"];
//}
//// 删除多个元素
//- (void)removeCoursesAtIndexes:(NSIndexSet *)indexes{
//    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"courses"];
//    [_courses removeObjectsAtIndexes:indexes];
//    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:@"courses"];
//}
//// 替换 单个
//- (void)replaceObjectInCoursesAtIndex:(NSUInteger)index withObject:(id)object{
//    [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"courses"];
//    [_courses replaceObjectAtIndex:index withObject:object];
//    [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"courses"];
//}
//// 替换 多个
//- (void)replaceCoursesAtIndexes:(NSIndexSet *)indexes withCourses:(NSArray *)array{
//    [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:indexes forKey:@"courses"];
//    [_courses replaceObjectsAtIndexes:indexes withObjects:array];
//    [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:indexes forKey:@"courses"];
//}
//
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    BOOL automatic = NO;
    if ([key isEqualToString:@"name"]) {
        automatic = NO;
    }
    else {
        automatic = [super automaticallyNotifiesObserversForKey:key];
    }
    return automatic;
}
@end
