//
//  main.m
//  06-消息传递：消息转发-01
//
//  Created by TT-Fangss on 2021/12/27.
//

#import <Foundation/Foundation.h>
/**
 消息转发
 
 在 Objective-C 中，当我们调用一个方法的本质是消息传递，那么消息传递在经过快速查找->慢速查找->动态方法解析三个流程之后，还是没有找到该方法的实现。那么接下来会进入下一个流程，消息转发。
 
 ## 一、消息转发流程的引入
 ### 1. instrumentObjcMessageSends 函数介绍
 在 objc 源码的 objc_class.mm 文件中，有一个 instrumentObjcMessageSends 函数。
 ```swift
 void instrumentObjcMessageSends(BOOL flag)
 {
     bool enable = flag;

     // Shortcut NOP
     if (objcMsgLogEnabled == enable)
         return;

     // If enabling, flush all method caches so we get some traces
     if (enable)
         _objc_flush_caches(Nil);

     // Sync our log file
     if (objcMsgLogFD != -1)
         fsync (objcMsgLogFD);

     objcMsgLogEnabled = enable;
 }
 ```
 当 flag 为 YES 时，刷新所有方法缓存，并且将同步到日志文件。那么日志文件存放在哪里呢？在 instrumentObjcMessageSends 函数的上方，有一个 logMessageSend 函数。
 ```swift
 bool objcMsgLogEnabled = false;
 static int objcMsgLogFD = -1;
 
 bool logMessageSend(bool isClassMethod,
                     const char *objectsClass,
                     const char *implementingClass,
                     SEL selector)
 {
     char    buf[ 1024 ];

     // Create/open the log file
     if (objcMsgLogFD == (-1))
     {
         snprintf (buf, sizeof(buf), "/tmp/msgSends-%d", (int) getpid ());
         objcMsgLogFD = secure_open (buf, O_WRONLY | O_CREAT, geteuid());
         if (objcMsgLogFD < 0) {
             // no log file - disable logging
             objcMsgLogEnabled = false;
             objcMsgLogFD = -1;
             return true;
         }
     }

     // Make the log entry
     snprintf(buf, sizeof(buf), "%c %s %s %s\n",
             isClassMethod ? '+' : '-',
             objectsClass,
             implementingClass,
             sel_getName(selector));

     objcMsgLogLock.lock();
     write (objcMsgLogFD, buf, strlen(buf));
     objcMsgLogLock.unlock();

     // Tell caller to not cache the method
     return false;
 }
 ```
 logMessageSend 函数的实现大多是一些日志的格式化输出。当调用 logMessageSend 函数的时候，会将日志文件存到  /tmp/  路经下，并且文件名以 msgSends- 开头。
 
 ### 2. logMessageSend 函数的由来
 那么我为什么就这么肯定一定会走 logMessageSend 函数呢？还记得在慢速查找 - lookUpImpOrForward 函数的实现吗，在函数的实现，有一个 done: 流程，当找到 imp 时，会跳转进 done: 流程，然后调用 log_and_fill_cache 函数，对 imp 进行缓存。
 
 log_and_fill_cache 函数实现如下：
 ```swift
 static void
 log_and_fill_cache(Class cls, IMP imp, SEL sel, id receiver, Class implementer)
 {
 #if SUPPORT_MESSAGE_LOGGING
     if (slowpath(objcMsgLogEnabled && implementer)) {
         bool cacheIt = logMessageSend(implementer->isMetaClass(),
                                       cls->nameForLogging(),
                                       implementer->nameForLogging(),
                                       sel);
         if (!cacheIt) return;
     }
 #endif
     cls->cache.insert(sel, imp, receiver);
 }
 ```
 看到第一个判断，当 objcMsgLogEnabled && implementer 成立的时候，就会调用 logMessageSend 函数，而 objcMsgLogEnabled ，不就是在 instrumentObjcMessageSends 函数内部赋值的吗。所以，instrumentObjcMessageSends 函数就是一个类似开启日志缓存的开关。
 
 ### 3. 测试 instrumentObjcMessageSends 函数输出日志文件
 接下来我们来测试一下，测试代码如下：
 ```swift
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
 ```
 需要注意的是，在测试的时候，不要用源码工程来测试，否则 msgSends- 文件会没有内容。查看 /tmp/ 路径下是否有 msgSends- 开头的文件。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/06-消息传递：消息转发/消息传递：消息转发/msgSends-文件路径.png
 
 好家伙，果然有，我们来看一下文件中的日志。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/06-消息传递：消息转发-01/06-消息传递：消息转发-01/msgSends-日志内容.png
 
 当我们进行动态方法解析之后，仍然没有找到方法的实现，这个时候系统还是会给开发者一次机会，那就是进行消息转发流程。如图中所示，消息转发流程主要有两个方法，分别为 forwardingTargetForSelector: 和 methodSignatureForSelector:。
 
 ## 二、消息转发流程
 那么什么叫消息转发流程是怎么个转发呢？我们先来看看 forwardingTargetForSelector: 方法和 methodSignatureForSelector: 方法怎么用。
 ### 1. 快速转发流程
 forwardingTargetForSelector:  方法的返回值为 id，参数为 aSelector。那么根据官方的注解，我个人的理解为，当实现这个方法，可以对 aSelector 进行转发，接收的对象为 id 类型，也就是任意对象。当我们返回接收的对象时，接收的对象会对 aSelector 继续进行查找，也就是重复前面所讲的消息传递的几个流程。
 
 我们举个例子，现在有两个对象，分别为 SHPerson 和 SHAnimal，我们在 SHPerson 中声明 run 方法，但不实现，并且实现 forwardingTargetForSelector: 方法。在 SHAnimal 中实现一个 run 方法。具体的代码如下：
 ```swift
 @interface SHAnimal : NSObject
 @end
 @implementation SHAnimal
 - (void)run {
     NSLog(@"%s", __func__);
 }
 @end
 ```
 ```swift
 @interface SHPerson : NSObject
 - (void)run;
 @end
 @implementation SHPerson
 - (id)forwardingTargetForSelector:(SEL)aSelector {
     if (aSelector == @selector(run)) {
         NSLog(@"%s",__func__);
         return [SHAnimal alloc];
     }
     return [super forwardingTargetForSelector:aSelector];
 }
 @end
 ```
 ```swift
 SHPerson *p = [[SHPerson alloc] init];
 [p run];
 ```
 ```swift
 打印结果：
 2021-12-27 16:28:14.862557+0800 06-消息传递：消息转发-01[72288:2241695] -[SHPerson forwardingTargetForSelector:]
 2021-12-27 16:28:14.862844+0800 06-消息传递：消息转发-01[72288:2241695] -[SHAnimal run]
 ```
 当我们在 SHPerson 没有实现 run 方法的时候，除了可以在动态方法解析那一流程做处理之外，还可以在 forwardingTargetForSelector: 方法中做处理。就如同打印的结果，SHPerson 没有实现 run ，我们手动的让它去 SHAnimal 对象里找。
 
 SHAnimal 对象就是当前消息转发的接收者，很多人也称它为备用接收者，或者称为备胎。
 
 
 
 ### 2. 慢速转发流程
 */

extern void instrumentObjcMessageSends(BOOL flag);

@interface SHAnimal : NSObject
@end
@implementation SHAnimal
- (void)run {
    NSLog(@"%s", __func__);
}
@end


@interface SHPerson : NSObject
- (void)run;
@end
@implementation SHPerson
- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (aSelector == @selector(run)) {
        NSLog(@"%s",__func__);
        return [SHAnimal alloc];
    }
    return [super forwardingTargetForSelector:aSelector];
}
@end


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SHPerson *p = [[SHPerson alloc] init];
        [p run];
        
//        SHPerson *p = [[SHPerson alloc] init];
//        instrumentObjcMessageSends(YES);
//        [p helloWorld];
//        instrumentObjcMessageSends(NO);
    }
    return 0;
}
