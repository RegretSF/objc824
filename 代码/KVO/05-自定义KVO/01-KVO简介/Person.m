//
//  Person.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "Person.h"
#import <objc/runtime.h>

@implementation Person
//static Person *instance = nil;
//+ (instancetype)sharedInstance {
//    static dispatch_once_t predicate;
//    dispatch_once(&predicate, ^{
//        instance = [[Person alloc] init];
//    });
//    return instance;
//}

- (void)setName:(NSString *)name {
    _name = name;
    NSLog(@"%s", __func__);
}

- (void)willChangeValueForKey:(NSString *)key {
    NSLog(@"%s", __func__);
    [super willChangeValueForKey:key];
}

- (void)didChangeValueForKey:(NSString *)key {
    NSLog(@"%s", __func__);
    [super didChangeValueForKey:key];
}

- (void)printObjectInfo {
    NSLog(@"-------");
    NSLog(@"对象: %@, 地址: %p", self, &self);
    
    Class cls_object = object_getClass(self); // 类对象（person->isa）
    Class super_cls_object = class_getSuperclass(cls_object); // 类对象的父类对象（person->superclass_isa）
    Class meta_cls_object = object_getClass(cls_object); // 元类对象（person->isa->isa）
    NSLog(@"class 对象: %@", cls_object);
    NSLog(@"class 对象的 superclass 对象: %@", super_cls_object);
    NSLog(@"metaclass 对象: %@", meta_cls_object);
    
    IMP name_imp = [self methodForSelector:@selector(setName:)];
    IMP age_imp = [self methodForSelector:@selector(setAge:)];
    NSLog(@"setName: %p, setAge: %p", name_imp, age_imp);
    
    [self printMethodNamesOfClass:cls_object];
}

- (void)printMethodNamesOfClass:(Class)cls {
    unsigned int count;
    Method *methodList = class_copyMethodList(cls, &count);
    NSMutableArray<NSString *> *methodNames = [NSMutableArray<NSString *> array];
    for (int i = 0; i < count; i++) {
        Method method = methodList[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        [methodNames addObject:methodName];
    }
    
    free(methodList);
    
    NSLog(@"对象的方法列表:%@", methodNames);
}
@end
