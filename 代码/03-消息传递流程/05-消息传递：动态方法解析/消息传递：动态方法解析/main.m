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


/*
 动态方法解析
 
 lookUpImpOrForward 函数为慢速查找流程的入口，进入慢速查找流程后，仍未找方法的实现，会进入下一个流程-动态方法解析。
 我们来看一下 lookUpImpOrForward 函数调整至动态方法解析的代码：
 ```swift
 // No implementation found. Try method resolver once.
 if (slowpath(behavior & LOOKUP_RESOLVER)) {
     // ^= : 异或运算符，相同为0，不同为 1。
     // behavior = 3，LOOKUP_RESOLVER = 2.
     // behavior:         0011
     // LOOKUP_RESOLVER:  0010
     // 结果:              0001
     // behavior = 1.
     behavior ^= LOOKUP_RESOLVER;
     return resolveMethod_locked(inst, sel, cls, behavior);
 }
 ```
 
 当第一次进入判断时，behavior 等于 3，为什么？，我们把源码跑起来。跑起来之前，做一些准备工作。
 先声明一个继承自 NSObject 的 SHPerson 对象，声明 helloWorld 方法，但不去实现它，代码如下：
 ```swift
 @interface SHPerson : NSObject
 - (void)helloWorld;
 @end
 
 @implementation SHPerson
 @end
 ```
 
 接下来在 slowpath(behavior & LOOKUP_RESOLVER) 判断中打一个断点。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/05-消息传递：动态方法解析/消息传递：动态方法解析/动态方法解析入口断点.png
 
 behavior = 3，LOOKUP_RESOLVER = 2，3 & 2 = 2。条件成立，所以进入 if 的代码块。
 ^= : 异或运算符，相同为0，不同为 1。3 ^= 2 = 1，那么 behavior = 1，传入 resolveMethod_locked 函数。
 
 ## 一、resolveMethod_locked 函数
 这是 resolveMethod_locked 函数的内部实现：
 ```swift
 static NEVER_INLINE IMP
 resolveMethod_locked(id inst, SEL sel, Class cls, int behavior)
 {
     runtimeLock.assertLocked();
     ASSERT(cls->isRealized());

     runtimeLock.unlock();
     // 判断是否是元类，如果不是元类，查找实例方法，否则查找类方法。
     // 在整个 OC 的底层，没有所谓的实例方法和对象方法，之所以在 OC 层面有是因为 Apple 为了更加体现面向对象。
     if (! cls->isMetaClass()) {
         // try [cls resolveInstanceMethod:sel]
         // 动态解析实例方法。如果没有实现 sel，系统提供接口，给开发者一次机会，避免程序崩溃。
         resolveInstanceMethod(inst, sel, cls);
     }
     else {
         // try [nonMetaClass resolveClassMethod:sel]
         // and [cls resolveInstanceMethod:sel]
         // 动态解析类方法。本质上是查找元类的对象方法。
         resolveClassMethod(inst, sel, cls);
         
         // lookUpImpOrNilTryCache 检查是否有缓存，目的是检查是否动态解析类方法
         if (!lookUpImpOrNilTryCache(inst, sel, cls)) {
             // 在动态解析类方法后，开发者在 NSObject 的处理实现的可能不是类方法，而是元类方法。
             // 所以在这里又会对实例方法进行解析，这里就是和 isa 流程图中的 superclass 的走位相呼应。
             // 根元类的 superclass 指针指向根类。
             resolveInstanceMethod(inst, sel, cls);
         }
     }

     // chances are that calling the resolver have populated the cache
     // so attempt using it
     // 如果前面的处理了，再去查找一次 lookUpImpOrForwardTryCache->_lookUpImpTryCache->lookUpImpOrForward。
     // 如果动态解析方法失败
     return lookUpImpOrForwardTryCache(inst, sel, cls, behavior);
 }
 ```
 
 resolveMethod_locked 函数的返回值是一个 IMP。前面一些锁的处理我们先不看。注意看第一个判断，if (! cls->isMetaClass()) 是判断函数传进来的 cls 是否是一个元类对象。
 我们知道，在类的结构中，存在着类对象和元类对象，它们的结构是一样的，都是 Class。区别就在于，类对象存储的实例方法，而元类对象存储类方法。所以这个判断的本质上是判断要动态解析实例方法还是类方法。
 
 ## 二、动态解析实例方法
 先来看第一个动态解析实例方法 - resolveInstanceMethod 函数的实现：
 ```swift
 static void resolveInstanceMethod(id inst, SEL sel, Class cls)
 {
     runtimeLock.assertUnlocked();
     ASSERT(cls->isRealized());
     SEL resolve_sel = @selector(resolveInstanceMethod:);

     if (!lookUpImpOrNilTryCache(cls, resolve_sel, cls->ISA(true))) {
         // Resolver not implemented.
         return;
     }

     BOOL (*msg)(Class, SEL, SEL) = (typeof(msg))objc_msgSend;
     // 是否动态解析
     bool resolved = msg(cls, resolve_sel, sel);

     // Cache the result (good or bad) so the resolver doesn't fire next time.
     // +resolveInstanceMethod adds to self a.k.a. cls
     // 缓存 sel
     IMP imp = lookUpImpOrNilTryCache(inst, sel, cls);

     if (resolved  &&  PrintResolving) {
         if (imp) {
             _objc_inform("RESOLVE: method %c[%s %s] "
                          "dynamically resolved to %p",
                          cls->isMetaClass() ? '+' : '-',
                          cls->nameForLogging(), sel_getName(sel), imp);
         }
         else {
             // Method resolver didn't add anything?
             _objc_inform("RESOLVE: +[%s resolveInstanceMethod:%s] returned YES"
                          ", but no new implementation of %c[%s %s] was found",
                          cls->nameForLogging(), sel_getName(sel),
                          cls->isMetaClass() ? '+' : '-',
                          cls->nameForLogging(), sel_getName(sel));
         }
     }
 }
 ```
 
 if (resolved  &&  PrintResolving) 判断后的代码我们忽略，不看。我们来看第一个判断 if (!lookUpImpOrNilTryCache(cls, resolve_sel, cls->ISA(true)))，这个判断的意思是判断是否实现了 resolveInstanceMethod 方法。但这个判断永远不会进入，因为系统有默认实现，包括下面要讲的 resolveClassMethod 方法。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/05-消息传递：动态方法解析/消息传递：动态方法解析/系统默认实现解析器.png
 
 resolveInstanceMethod 方法的返回值是 BOOL 类型，通过这个返回值告诉系统，我们是否动态方法解析了。不管我们有没有解析，系统都会把 sel 缓存下来，避免重复触发 resolveInstanceMethod 方法。
 
 ## 三、动态解析类方法
 接下来是动态解析类方法，过程和解析实例方法差不多，解析类方法的要实现 resolveClassMethod 方法，这个是解析类方法的解析器。我们来看一下 resolveClassMethod 函数的实现。
 ```swift
 static void resolveClassMethod(id inst, SEL sel, Class cls)
 {
     runtimeLock.assertUnlocked();
     ASSERT(cls->isRealized());
     ASSERT(cls->isMetaClass());

     if (!lookUpImpOrNilTryCache(inst, @selector(resolveClassMethod:), cls)) {
         // Resolver not implemented.
         return;
     }

     Class nonmeta;
     {
         mutex_locker_t lock(runtimeLock);
         nonmeta = getMaybeUnrealizedNonMetaClass(cls, inst);
         // +initialize path should have realized nonmeta already
         if (!nonmeta->isRealized()) {
             _objc_fatal("nonmeta class %s (%p) unexpectedly not realized",
                         nonmeta->nameForLogging(), nonmeta);
         }
     }
     BOOL (*msg)(Class, SEL, SEL) = (typeof(msg))objc_msgSend;
     // 是否动态解析
     bool resolved = msg(nonmeta, @selector(resolveClassMethod:), sel);

     // Cache the result (good or bad) so the resolver doesn't fire next time.
     // +resolveClassMethod adds to self->ISA() a.k.a. cls
     // 缓存 sel-imp
     IMP imp = lookUpImpOrNilTryCache(inst, sel, cls);

     if (resolved  &&  PrintResolving) {
         if (imp) {
             _objc_inform("RESOLVE: method %c[%s %s] "
                          "dynamically resolved to %p",
                          cls->isMetaClass() ? '+' : '-',
                          cls->nameForLogging(), sel_getName(sel), imp);
         }
         else {
             // Method resolver didn't add anything?
             _objc_inform("RESOLVE: +[%s resolveClassMethod:%s] returned YES"
                          ", but no new implementation of %c[%s %s] was found",
                          cls->nameForLogging(), sel_getName(sel),
                          cls->isMetaClass() ? '+' : '-',
                          cls->nameForLogging(), sel_getName(sel));
         }
     }
 }
 ```
 
 */
