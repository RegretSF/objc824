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
 当我们在 forwardingTargetForSelector: 方法做处理的时候，总会觉得奇奇怪怪的。如果 SHAnimal 也不实现 run 方法，程序一样会崩溃，毕竟只是备胎😂，所以我们不想在 forwardingTargetForSelector: 中做处理，那么就开始进入到下一个流程，叫慢速转发流程，也就是实现 methodSignatureForSelector: 方法，在 methodSignatureForSelector: 方法中做转发的处理。
 
 #### 1. methodSignatureForSelector:
 methodSignatureForSelector: 方法需要返回一个 NSMethodSignature 对象，也就是方法签名。需要注意的是，methodSignatureForSelector: 和 forwardingTargetForSelector: 不能同时存在哦，否则就只走到 forwardingTargetForSelector: ，不会走到 methodSignatureForSelector: 。
 
 代码如下：
 ```swift
 @interface SHPerson : NSObject
 - (void)run;
 @end
 @implementation SHPerson
 - (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
     if (aSelector == @selector(run)) {
         NSLog(@"%s",__func__);
         NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
         return signature;
     }
     return [super methodSignatureForSelector:aSelector];
 }
 ```
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/06-消息传递：消息转发-01/06-消息传递：消息转发-01/慢速转发崩溃.png
 
 我们把代码跑起来后，虽然调用了 methodSignatureForSelector:  方法，但程序还是崩了。难道 methodSignatureForSelector: 方法不能解决吗，我在看 methodSignatureForSelector: 方法的文档说明的时候，注意到了 forwardInvocation: 方法。
 
 #### 2.  forwardInvocation:
 在实现 methodSignatureForSelector: 方法的同时，也必须创建 NSInvocation 对象。我理解的大概意思是，methodSignatureForSelector:  和 forwardInvocation:  必须一起实现，因为实现了 forwardInvocation:  方法，会去创建 NSInvocation 对象，并且将 NSInvocation 对象作为参数传到 forwardInvocation:  方法。
 
 那么，我们实现  forwardInvocation: 方法，并重新运行。
 ```swift
 - (void)forwardInvocation:(NSInvocation *)anInvocation {
     NSLog(@"%s",__func__);
 }
 ```
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/03-消息传递流程/06-消息传递：消息转发-01/06-消息传递：消息转发-01/forwardInvocation 打印.png

 实现了 forwardInvocation: 方法后，果然不崩了，并且还打印了 methodSignatureForSelector: 和 forwardInvocation:。
 
 那为什么实现了 forwardInvocation: 方法之后，不用做任何的处理，程序都不会崩溃呢。下面是我翻译官方文档对  forwardInvocation:  的说明。
 
 当一个对象收到一条没有相应方法的消息时，运行时系统会给接收者一个机会将消息委托给另一个接收者。它通过创建一个表示消息的 NSInvocation 对象并向接收者发送一个 forwardInvocation: 消息来委托消息，该消息包含这个 NSInvocation 对象作为参数。然后，接收者的 forwardInvocation: 方法可以选择将消息转发到另一个对象。 （如果该对象也无法响应消息，它也将有机会转发它。）
 
 forwardInvocation: 消息因此允许一个对象与其他对象建立关系，对于某些消息，这些对象将代表它行事。从某种意义上说，转发对象能够“继承”将消息转发到的对象的某些特征。
 
 要响应您的对象本身无法识别的方法，除了 forwardInvocation: 之外，您还必须覆盖 methodSignatureForSelector:。转发消息的机制使用从 methodSignatureForSelector: 获得的信息来创建要转发的 NSInvocation 对象。您的覆盖方法必须为给定的选择器提供适当的方法签名，通过预先制定一个方法或通过向另一个对象询问一个方法。
 
 forwardInvocation: 方法的实现有两个任务：
 1. 定位可以响应 anInvocation 中编码的消息的对象。该对象不必对所有消息都相同。
 2. 使用调用将消息发送到该对象。anInvocation 将保存结果，运行时系统将提取该结果并将其传递给原始发送者。
 
 那么，什么意思呢，我们来看一段 forwardInvocation: 的简单实现。
 ```swift
 - (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
     if (aSelector == @selector(run)) {
         NSLog(@"%s",__func__);
         NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
         return signature;
     }
     return [super methodSignatureForSelector:aSelector];
 }

 - (void)forwardInvocation:(NSInvocation *)anInvocation {
     NSLog(@"%s",__func__);
     
     SEL aSelector = [anInvocation selector];
     SHAnimal *forward = [SHAnimal alloc];
     
     if ([forward respondsToSelector:aSelector]) {
         [anInvocation invokeWithTarget:forward];
     }else {
         [super forwardInvocation:anInvocation];
     }
 }
 ```
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/03-消息传递流程/06-消息传递：消息转发-01/06-消息传递：消息转发-01/forwardInvocation实现打印.png
 
 通过这段代码和打印，正好就是印证了官方文档的注释。forwardInvocation: 实现之后，可以在方法中通过 NSInvocation 对象进行最后的消息转发处理。
 
 NSInvocation 相当于事物，你只需要告诉它，是否要进行消息转发，需要的话，就像上面的例子。不需要进行转发的话，NSInvocation 对象会很乖，什么也不管，但是不会导致程序崩溃，因为只要实现了 methodSignatureForSelector: ，返回方法签名，并且创建 NSInvocation 对象，就不会崩溃。
 
 forwardInvocation: 会帮我们创建一个 NSInvocation 对象，并且把这个对象传给我们，让我们通过 NSInvocation 对象进行最后的消息转发。
 
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
//- (id)forwardingTargetForSelector:(SEL)aSelector {
//    if (aSelector == @selector(run)) {
//        NSLog(@"%s",__func__);
//        return [SHAnimal alloc];
//    }
//    return [super forwardingTargetForSelector:aSelector];
//}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if (aSelector == @selector(run)) {
        NSLog(@"%s",__func__);
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:"];
        return signature;
    }
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"%s",__func__);
    
    SEL aSelector = [anInvocation selector];
    SHAnimal *forward = [SHAnimal alloc];
    
    if ([forward respondsToSelector:aSelector]) {
        [anInvocation invokeWithTarget:forward];
    }else {
        [super forwardInvocation:anInvocation];
    }
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
