//
//  SHPerson.m
//  02-KVC中访问器搜索模式
//
//  Created by TT-Fangss on 2021/9/27.
//

#import "SHPerson.h"

@implementation SHPerson
#pragma mark: - setter
//- (void)setName:(NSString *)name {
//    NSLog(@"%s--%@", __func__, name);
//}
//
//- (void)_setName:(NSString *)name {
//    NSLog(@"%s--%@", __func__, name);
//}

//setIs<Key>
- (void)setIsName:(NSString *)name {
    NSLog(@"%s--%@", __func__, name);
}

#pragma mark: - getter
//- (NSString *)getName {
//    NSLog(@"%s--%@", __func__, self->_name);
//    return self->_name;
//}

//- (NSString *)name {
//    NSLog(@"%s--%@", __func__, self->_name);
//    return self->_name;
//}

//- (NSString *)isName {
//    NSLog(@"%s--%@", __func__, self->_name);
//    return self->isName;
//}

//- (NSString *)_name {
//    NSLog(@"%s--%@", __func__, self->_name);
//    return self->_name;
//}

#pragma mark: 集合类型的走
//MARK: - array
// 个数
- (NSUInteger)countOfPens{
    NSLog(@"%s",__func__);
    return [self.arr count];
}

// 获取值
- (id)objectInPensAtIndex:(NSUInteger)index {
    NSLog(@"%s - %lu",__func__, (unsigned long)index);
    return [NSString stringWithFormat:@"pen%lu", index];
}

- (NSArray *)pensAtIndexes:(NSIndexSet *)indexes {
    NSLog(@"%s",__func__);
    return self.arr;
}

//MARK: - set
// 个数
- (NSUInteger)countOfBooks{
    NSLog(@"%s",__func__);
    return [self.set count];
}

// 是否包含这个成员对象
- (id)memberOfBooks:(id)object {
    NSLog(@"%s",__func__);
    return [self.set containsObject:object] ? object : nil;
}

// 迭代器
- (id)enumeratorOfBooks {
    // objectEnumerator
    NSLog(@"来了 迭代编译");
    return [self.arr reverseObjectEnumerator];
}

#pragma mark: - 可变数组的搜素模式
//- (void)insertObject:(id)object inArrayMAtIndex:(NSUInteger)index {
//    NSLog(@"%s",__func__);
//}
//
//- (void)removeObjectFromArrayMAtIndex:(NSUInteger)index {
//    NSLog(@"%s",__func__);
//}
//
//- (void)insertArrayM:(NSArray *)array atIndexes:(NSIndexSet *)indexes {
//    NSLog(@"%s",__func__);
//}
//
//- (void)removeArrayMAtIndexes:(NSIndexSet *)indexes {
//    NSLog(@"%s",__func__);
//}
//
//- (void)replaceObjectInArrayMAtIndex:(NSUInteger)index withObject:(id)object {
//    NSLog(@"%s",__func__);
//}
//
//- (void)replaceArrayMAtIndexes:(NSIndexSet *)indexes withArrayM:(NSArray *)array {
//    NSLog(@"%s",__func__);
//}

//- (void)setArrayM:(NSMutableArray *)arrayM {
//    _arrayM = arrayM;
//    NSLog(@"%s",__func__);
//}

#pragma mark: - accessInstanceVariablesDirectly
+ (BOOL)accessInstanceVariablesDirectly {
    return NO;
}

#pragma mark: - setValue:forUndefinedKey:
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"key: %@, value: %@ -- 异常处理", key, value);
}

// valueForUndefinedKey
- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"key: %@ -- 异常处理", key);
    return [NSMutableArray array];
}
@end
