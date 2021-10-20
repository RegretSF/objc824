//
//  NSObject+SHKVO.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/11.
//

#import "NSObject+SHKVO.h"
#import "SHKVOInfo.h"
#import <objc/runtime.h>
#import <objc/message.h>

/*
 自定义 KVO
 模仿系统的三个方法:
 添加观察者：addObserver:forKeyPath:options:context:
 观察者监听：observeValueForKeyPath:ofObject:change:context:
 移除观察者：removeObserver:forKeyPath:
 
 思路：
 addObserver:forKeyPath:options:context:
 1. 验证 keyPath 是否有 setter 的实例方法
 
 2. 动态生成子类
    1. 拼接子类名称，模仿系统的拼接规则（NSKVONotifying_<className>）
    2. 根据通过 NSClassFromString 方法获取类名称获取对应的 Class。
    3. 判断获取的 Class 是否为 nil，如果为 nil，则向系统申请并注册类，并且添加 setter、class、dealloc和_isKVOA方法。
 
 3. 将 isa 指向动态生成的子类
 
 4. 缓存观察者
    1. 用关联对象并通过数组对 addObserver:forKeyPath:options:context: 传过来的参数进行缓存。
 
 observeValueForKeyPath:ofObject:change:context:
 其实就是 setter 方法的实现。
 1. 获取缓存的观察者数组
 2. 获取 keyPath
 3. 将缓存里有 keyPath 的观察者对象取出。
 4. 调用 willChangeValueForKey: 方法
 4. 核心重点！，发生消息给父类，相当于 [super setter]。
 5. 调用 didChangeValueForKey: 方法
 6. 发送消息给观察者。

 removeObserver:forKeyPath:
 1. 获取缓存观察者的关联对象，做 nil 处理
 2. 从数组中查找与 keyPath 相匹配的观察者，并删除。
 3. 如果数组中的 count 为 0，将 isa 指回。
 
 剩下的 class、dealloc和_isKVOA 方法实现
 1. class: 返回父类对象。（class_getSuperclass(object_getClass(self));）
 2. dealloc: 收尾工作，将 isa 指回。
 3. _isKVOA: 返回 YES。
 
 */

static NSString *const SHKVONotifyingKey = @"SHKVONotifying_";
static NSString *const SHKVOAssociatedObjectKey = @"SHKVOAssociatedObjectKey";

@implementation NSObject (KVO)
- (void)sh_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void * _Nullable)context {
    // 1. setter 方法验证
    if (sh_judgeSetterMethodWithClass(object_getClass(self), keyPath) == NO) {
        NSLog(@"没有相应的 setter");
        return;
    }
    
    // 2. 动态生成子类
    Class subclass_kvo = [self sh_createChildClassWithKeyPath:keyPath];
    
    // 3. isa的指向 : SHKVONotifying_xxx
    object_setClass(self, subclass_kvo);
    
    // 4. 保存观察者
    NSMutableArray *kvoInfos = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(SHKVOAssociatedObjectKey));
    
    if (kvoInfos == nil) {
        kvoInfos = [NSMutableArray arrayWithCapacity:1];
    }
    
    SHKVOInfo *kvoInfo = [[SHKVOInfo alloc] initWithObserver:observer keyPath:keyPath options:options];
    [kvoInfos addObject:kvoInfo];
    objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(SHKVOAssociatedObjectKey), kvoInfos, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sh_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    // 获取关联数组对象
    NSMutableArray *kvoInfos = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(SHKVOAssociatedObjectKey));
    
    // nil 处理
    if (kvoInfos == nil) return;
    
    // 从数组中删除 keyPath 对应的 kvoInfo
    for (SHKVOInfo *kvoInfo in kvoInfos.copy) {
        if ([kvoInfo.keyPath isEqualToString:keyPath]) {
            [kvoInfos removeObject:kvoInfo];
            objc_setAssociatedObject(self, (__bridge const void * _Nonnull)(SHKVOAssociatedObjectKey), kvoInfos, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            break;
        }
    }
    
    // 如果数组中没有了 kvoInfo， 将 isa 指回父类
    if (kvoInfos.count <= 0) {
        object_setClass(self, sh_kvo_class(self));
    }
}

- (void)sh_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void * _Nullable)context {
}

/// 传一个 keyPath 动态的创建一个 当前类相关的 NSKVONotifying_xxx 类
/// @param keyPath keyPath
- (Class)sh_createChildClassWithKeyPath:(NSString *)keyPath {
    NSString *oldClassName = NSStringFromClass([self class]);
    NSString *newClassName = [NSString stringWithFormat:@"%@%@",SHKVONotifyingKey, oldClassName];
    Class newClass = NSClassFromString(newClassName);
    
    if (newClass == nil) {
        // 申请类
        // 第一个参数：父类
        // 第二个参数：申请类的名称
        // 第三个参数：开辟的额外空间
        newClass = objc_allocateClassPair([self class], newClassName.UTF8String, 0);
        
        // 添加 class 方法: class的指向是当前实例对象的 class 对象
        SEL classSel = NSSelectorFromString(@"class");
        Method classMethod = class_getInstanceMethod([self class], classSel);
        const char *classTypes = method_getTypeEncoding(classMethod);
        class_addMethod(newClass, classSel, (IMP)sh_kvo_class, classTypes);
        
        // 添加 dealloc 方法
        SEL deallocSel = NSSelectorFromString(@"dealloc");
        Method deallocMethod = class_getInstanceMethod([self class], deallocSel);
        const char *deallocTypes = method_getTypeEncoding(deallocMethod);
        class_addMethod(newClass, deallocSel, (IMP)sh_kvo_dealloc, deallocTypes);
        
        // 添加 _isKVOA 方法
        SEL _isKVOASel = NSSelectorFromString(@"_isKVOA");
        Method _isKVOAMethod = class_getInstanceMethod([self class], _isKVOASel);
        const char *_isKVOATypes = method_getTypeEncoding(_isKVOAMethod);
        class_addMethod(newClass, _isKVOASel, (IMP)sh_isKVOA, _isKVOATypes);
        
        // 注册类
        objc_registerClassPair(newClass);
    }
    
    // 添加 setter 方法
    SEL setterSel = NSSelectorFromString(sh_setterForKeyPath(keyPath));
    Method setterMethod = class_getInstanceMethod([self class], setterSel);
    const char *setterTypes = method_getTypeEncoding(setterMethod);
    class_addMethod(newClass, setterSel, (IMP)sh_kvo_setter, setterTypes);
    
    return newClass;
}

/// 设置 change 并返回
/// @param kvoInfo kvoInfo
/// @param keyPath keyPath
/// @param newValue newValue
- (NSDictionary *)sh_changeForKVOInfo:(SHKVOInfo *)kvoInfo keyPath:(NSString *)keyPath newValue:(id)newValue {
    NSMutableDictionary *change = [NSMutableDictionary dictionary];
    
    if (kvoInfo.options & NSKeyValueObservingOptionOld) {
        id oldValue = [self valueForKey:keyPath];
        if (oldValue) {
            [change setObject:oldValue forKey:NSKeyValueChangeOldKey];
        }else {
            [change setObject:@"" forKey:NSKeyValueChangeOldKey];
        }
    }
    
    if (kvoInfo.options & NSKeyValueObservingOptionNew) {
        [change setObject:newValue forKey:NSKeyValueChangeNewKey];
    }
    
    return change.copy;
}

/// 给父类发送消息
/// @param sel sel
/// @param newValue newValue
- (void)sh_objc_msgSendSuper:(SEL)sel newValue:(id)newValue {
    struct objc_super sh_objc_super;
    sh_objc_super.receiver = self;
    sh_objc_super.super_class = sh_kvo_class(self);
    // 1.给父类发送消息
    ((void (*)(void *, SEL, id))objc_msgSendSuper)(&sh_objc_super, sel, newValue);
}

void sh_kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *keyPath = sh_getterForSetter(NSStringFromSelector(_cmd));
    
    // 查找观察者
    NSMutableArray *kvoInfos = objc_getAssociatedObject(self, (__bridge const void * _Nonnull)(SHKVOAssociatedObjectKey));
    
    // 遍历
    for (SHKVOInfo *kvoInfo in kvoInfos) {
        if ([kvoInfo.keyPath isEqualToString:keyPath]) {
            if (kvoInfo == nil) {
                [self sh_objc_msgSendSuper:_cmd newValue:newValue];
                return;
            }
            
            // 获取 change
            NSDictionary *change = [self sh_changeForKVOInfo:kvoInfo keyPath:keyPath newValue:newValue];
            
            // 调用 willChangeValueForKey
            [self willChangeValueForKey:keyPath];
            
            // 判断 自动开关 省略
            // 核心 -> Person - setter _cmd 父类发送消息
            [self sh_objc_msgSendSuper:_cmd newValue:newValue];
            
            
            // 调用 didChangeValueForKey
            [self didChangeValueForKey:keyPath];
            
            // 2.发送消息-观察者
            SEL observerSel = NSSelectorFromString(@"sh_observeValueForKeyPath:ofObject:change:context:");
            ((void (*)(id, SEL, NSString *, id, NSDictionary *, void *))objc_msgSend)(kvoInfo.observer, observerSel, keyPath, self, change, NULL);
        }
    }
}

Class sh_kvo_class(id self)
{
    return class_getSuperclass(object_getClass(self));
}

void sh_kvo_dealloc(id self)
{
    // 把 isa 指回去
    object_setClass(self, sh_kvo_class(self));
}

BOOL sh_isKVOA(id self)
{
    return YES;
}

#pragma mark: - 静态方法
/// 验证 class 对象是否有 keyPath 对应的 setter 存在
/// @param cls class 对象
/// @param keyPath keyPath
static BOOL sh_judgeSetterMethodWithClass(Class cls, NSString *keyPath)
{
    // 根据 keyPath 拼接的 setter
    SEL sel = NSSelectorFromString(sh_setterForKeyPath(keyPath));
    // 检查 setterMthod 是否为 nil，如果没有 nil，则没有 setter
    Method setterMthod = class_getInstanceMethod(cls, sel);
    return !(setterMthod == nil);
}

/// 传一个 keyPath 返回一个 keyPath 对应的 setter
/// @param keyPath keyPath
static NSString *sh_setterForKeyPath(NSString *keyPath)
{
    // nil 判断
    if (keyPath.length <= 0) return nil;
    // 取首字母并且大写形式
    NSString *firstString = [[keyPath substringToIndex:1] uppercaseString];
    // 取首字母以外的字母
    NSString *leaveString = [keyPath substringFromIndex:1];
    
    return [NSString stringWithFormat:@"set%@%@:", firstString, leaveString];
}

/// 传一个 setter 方法名返回一个 setter 对应的 getter
/// @param setter setter
static NSString *sh_getterForSetter(NSString *setter)
{
    if (![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"] ||setter.length <= 3) {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length-4);
    NSString *getter = [setter substringWithRange:range];
    NSString *firstString = [[getter substringToIndex:1] lowercaseString];
    return  [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstString];
}


@end
