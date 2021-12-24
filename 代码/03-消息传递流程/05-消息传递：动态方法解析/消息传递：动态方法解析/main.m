//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

void dynamicMethodIMP(id self, SEL _cmd) {
    NSLog(@"%s", __func__);
}

@interface SHPerson : NSObject
+ (void)helloWorld;
@end

@implementation SHPerson
//+ (BOOL)resolveClassMethod:(SEL)sel {
//    if (sel == @selector(helloWorld)) {
//        NSLog(@"%s", __func__);
//        return class_addMethod(objc_getMetaClass("SHPerson"), sel, (IMP)dynamicMethodIMP, "v@:");
//    }
//    return [super resolveClassMethod:sel];
//}

//+ (BOOL)resolveInstanceMethod:(SEL)sel {
//    if (sel == @selector(helloWorld)) {
//        NSLog(@"%s", __func__);
//        return class_addMethod([self class], sel, (IMP)dynamicMethodIMP, "v@:");
//    }
//    return [super resolveInstanceMethod:sel];
//}
@end

//@interface SHStudent : SHPerson
//- (void)play_1;
//+ (void)play_2;
//- (void)play_3;
//@end
//@implementation SHStudent
//- (void)play_1 {
//    NSLog(@"%s", __func__);
//}
//@end

@implementation NSObject(Category)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
//+ (BOOL)resolveInstanceMethod:(SEL)sel {
//    if (sel == NSSelectorFromString(@"play_3")) {
//        NSLog(@"%s",__func__);
//    }
//
//    return NO;
//}
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == @selector(helloWorld)) {
        NSLog(@"%s", __func__);
        return class_addMethod([self class], sel, (IMP)dynamicMethodIMP, "v@:");
    }
    return NO;
}


//+ (BOOL)resolveClassMethod:(SEL)sel {
//    NSLog(@"%s",__func__);
//    return NO;
//}
#pragma clang diagnostic pop
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
//        SHPerson *p = [[SHPerson alloc] init];
        [SHPerson helloWorld];
        
//        SHStudent *s = [[SHStudent alloc] init];
//        [s helloWorld];
//        [s play_1];
//        [SHStudent play_2];
//        [s play_3];

        
    }
    return 0;
}


/*
 动态方法解析
 
 lookUpImpOrForward 函数为慢速查找流程的入口，进入慢速查找流程后，仍未找方法的实现，会进入下一个流程-动态方法解析。
 ## 一、动态方法解析的源码分析
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
 
 ### 1、resolveMethod_locked 函数
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
 
 ### 2、动态解析实例方法
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
 
 ### 3、动态解析类方法
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
 
 解析类方法的实现逻辑和解析实例方法的实现逻辑差不多，需要注意的不是 resolveClassMethod 函数的实现，而是 resolveMethod_locked 函数。来看一下 resolveMethod_locked 函数解析类方法的流程：
 ```swift
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
 ```
 
 我们可以看到，在尝试去动态的解析类方法后，会去检查缓存里是否有方法，如果没有方法，会去解析实例方法。为什么呢？
 
 在整个 OC 的底层，没有所谓实例方法和类方法，这些所谓的实例方法和类方法在底层都是函数。那苹果这么做的意义是为了更加体现面向对象。在没有找到对应的类方法实现时，会去实例方法里找，所以才会动态解析实例方法。这里其实就和前面第六篇文章-Objective-C 对象的结构分析中的 isa 流程相呼应。
 
 ### 4、没有动态方法解析的处理
 如果开发者没有实现动态方法解析的处理，会调用 lookUpImpOrForwardTryCache 函数，它内部的实现就是调用了 _lookUpImpTryCache 函数。
 _lookUpImpTryCache 函数的实现如下：
 ```swift
 static IMP _lookUpImpTryCache(id inst, SEL sel, Class cls, int behavior)
 {
     runtimeLock.assertUnlocked();

     if (slowpath(!cls->isInitialized())) {
         // see comment in lookUpImpOrForward
         return lookUpImpOrForward(inst, sel, cls, behavior);
     }

     IMP imp = cache_getImp(cls, sel);
     if (imp != NULL) goto done;
 #if CONFIG_USE_PREOPT_CACHES
     if (fastpath(cls->cache.isConstantOptimizedCache(true))) {
         imp = cache_getImp(cls->cache.preoptFallbackClass(), sel);
     }
 #endif
     if (slowpath(imp == NULL)) {
         return lookUpImpOrForward(inst, sel, cls, behavior);
     }
     
 done:
     if ((behavior & LOOKUP_NIL) && imp == (IMP)_objc_msgForward_impcache) {
         return nil;
     }
     return imp;
 }
 ```
 
 先判断类是否初始化，如果没有就会去之前的慢速查找的操作。
 如果类初始化了，先进行快速查找，如果缓存有，跳转至 done，否则会根据架构的不同，进行处理。
 
 ## 二、动态方法解析 OC 层面处理
 
 在 OC 层面怎么处理呢，系统提供给开发者两个方法 resolveInstanceMethod:，resolveClassMethod:，分别对应动态实例方法解析和动态类方法解析。
 ### 1、动态实例方法解析
 我们以动态实例方法解析为例，定义一个 dynamicMethodIMP 函数。
 ```swift
 void dynamicMethodIMP(id self, SEL _cmd) {
     NSLog(@"%s", __func__);
 }
 ```
 
 定义一个 SHPerson，代码实现如下
 ```swift
 @interface SHPerson : NSObject
 - (void)helloWorld;
 @end
 
 @implementation SHPerson
 + (BOOL)resolveInstanceMethod:(SEL)sel {
     if (sel == @selector(helloWorld)) {
         NSLog(@"%s", __func__);
         return class_addMethod([self class], sel, (IMP)dynamicMethodIMP, "v@:");
     }
     return [super resolveInstanceMethod:sel];
 }
 @end
 ```
 
 在 SHPerson 中声明 helloWorld 方法，但并未实现该方法。
 
 实现动态实例方法解析器 - resolveInstanceMethod:，当 helloWorld 方法不实现的话必然会走到 resolveInstanceMethod: 方法。如果没有实现 helloWorld 方法，我们动态的将 dynamicMethodIMP 函数添加到 SHPerson，否则就 super 一下。
 
 这里需要注意的是需要导入运行时的库：#import <objc/runtime.h>
 
 调用 helloWorld 方法，并将结果打印。
 ```swift
 int main(int argc, const char * argv[]) {
     @autoreleasepool {
         SHPerson *p = [[SHPerson alloc] init];
         [p helloWorld];
     }
     return 0;
 }
 ```
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/05-消息传递：动态方法解析/消息传递：动态方法解析/动态实例方法解析的实现打印.png
 
控制台成功打印出 [SHPerson resolveInstanceMethod:] 和 dynamicMethodIMP。
 
 ### 2、动态类方法解析
 其实动态类方法解析的处理和动态实例方法解析的处理是一样的，只是解析器不一样。动态类方法解析需要实现 resolveClassMethod: 方法，还是用 dynamicMethodIMP 函数处理，SHPerson 的处理如下：
 ```swift
 @interface SHPerson : NSObject
 + (void)helloWorld;
 @end

 @implementation SHPerson
 + (BOOL)resolveClassMethod:(SEL)sel {
     if (sel == @selector(helloWorld)) {
         NSLog(@"%s", __func__);
         return class_addMethod(objc_getMetaClass("SHPerson"), sel, (IMP)dynamicMethodIMP, "v@:");
     }
     return [super resolveClassMethod:sel];
 }
 @end
 ```
 
 实现 resolveClassMethod: 方法，因为类方法是存储在元类里面，所以在调用 class_addMethod 传的第一个参数需要传 SHPerson 的元类。
 
 来看一下调用和打印的结果：
 ```swift
 int main(int argc, const char * argv[]) {
     @autoreleasepool {
         [SHPerson helloWorld];
     }
     return 0;
 }
 ```
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/05-消息传递：动态方法解析/消息传递：动态方法解析/动态类方法解析的实现打印.png
 控制台成功打印出 [SHPerson resolveClassMethod:] 和 dynamicMethodIMP。
 
 ### 3、验证源码中动态类方法解析流程
 那么，前面讲过，如果动态类方法解析没有实现的话会进行动态实例方法解析，下面对此进行验证。我们调用类方法 helloWorld，但是实现的是 resolveInstanceMethod: 方法。
 
 需要注意的是，底层在查找方法的时候，找到根元类了，并且没有找到方法的实现，才会去根类里面去找方法的实现。那么动态方法解析的原理也是一样，只有找到 NSObject 的元类并且没有对类方法解析器做处理，才会走实例方法解析器。
 
 代码如下：
 ```swift
 @interface SHPerson : NSObject
 + (void)helloWorld;
 @end

 @implementation SHPerson
 @end
 
 @implementation NSObject(Category)
 #pragma clang diagnostic push
 #pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
 + (BOOL)resolveInstanceMethod:(SEL)sel {
     if (sel == @selector(helloWorld)) {
         NSLog(@"%s", __func__);
         return class_addMethod([self class], sel, (IMP)dynamicMethodIMP, "v@:");
     }
     return NO;
 }
 #pragma clang diagnostic pop
 @end
 ```
 
 来看一下调用和打印的结果：
 ```swift
 int main(int argc, const char * argv[]) {
     @autoreleasepool {
         [SHPerson helloWorld];
     }
     return 0;
 }
 ```
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/05-消息传递：动态方法解析/消息传递：动态方法解析/调用类方法实现实例方法解析器.png
 
 通过打印结果可以知道，虽然调用的是类方法，但是只要在 NSObject 的分类中实现 resolveInstanceMethod: 方法，一样可以做处理，这里就印证前面的源码分析是对的。到这里，整个动态方法解析的流程分析就结束了。
 
 */
