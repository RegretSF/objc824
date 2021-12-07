//
//  main.m
//  objc_msgSend介绍
//
//  Created by TT-Fangss on 2021/12/6.
//

#import <Foundation/Foundation.h>

/*
## 一、runtime介绍

iOS的runtime是指 Objective-C 将尽可能多的决策从编译时和链接时推迟到运行时。

Objective-C与runtime的交互：
* 通过Objective-C源代码；
* 通过Foundation框架的NSObject类中定义的方法；
* 通过直接调用运行时函数。

## 二、消息传递
消息传递的过程需要用到一个很重要的方法-objc_msgSend，我们来看对 objc_msgSend 做一个介绍以及如何使用。

### 1. objc_msgSend 函数
在 Objective-C 中，消息直到运行时才会绑定到方法实现。下面是我们的对象正常调用方法。
```swift
[receiver message]
```

在调用 message 方法的时候，Objective-C 会在运行时调用 objc_msgSend 函数，objc_msgSend函数将 receiver(接收者) 和 SEL(方法选择器(方法名称)) 作为它主要的两个参数。
```swift
objc_msgSend(receiver, selector)
```

如果有其它参数，调用objc_msgSend 函数的时候：
```swift
objc_msgSend(receiver, selector, arg1, arg2, ...)
```

objc_msgSend函数完成动态绑定所需的一切：
* 首先查找方法是否有实现。 由于相同的方法可以由不同的类以不同的方式实现，因此它找到的精确过程取决于接收器的类。
* 然后将接收者，方法选择器以及指定的参数传递给它进行调用。
* 最后，它传递过程的返回值作为它自己的返回值。

请看一张图：
/Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/06-objc_msgSend介绍/objc_msgSend介绍/messaging1.gif

当一个消息被发送到一个对象时，objc_msgSend函数跟随对象的 isa 指针指向类结构，它在调度表中查找方法选择器。如果在那里找不到选择器，objc_msgSend 会跟随指向超类的指针并尝试在其调度表中找到选择器。连续失败导致 objc_msgSend 爬升类层次结构，直到它到达 NSObject 类。一旦找到选择器，函数就会调用表中输入的方法，并将接收对象的数据结构传递给它。

这是在运行时选择方法实现的方式，或者，用面向对象编程的行话来说，这些方法是动态绑定到消息的。

为了加快消息传递过程，运行时系统会在使用时缓存方法的选择器和地址。每个类都有一个单独的缓存，它可以包含继承方法以及类中定义的方法的选择器。在搜索调度表之前，先检查接收对象的类的缓存（理论上使用过一次的方法可能会再次使用）。如果方法选择器在缓存中，消息传递只比函数调用慢一点。一旦程序运行了足够长的时间来“预热”它的缓存，它发送的几乎所有消息都会找到一个缓存方法。缓存会随着程序运行而动态增长以容纳新消息。

### 2. 隐藏参数
当 objc_msgSend 找到实现方法的过程时，它调用该过程并将消息中的所有参数传递给它。 其中有两个是隐藏参数：
* 接收对象。
* 方法的选择器。

之所以说它们是“隐藏的”，是因为它们没有在定义方法的源代码中声明。它们在代码编译时插入到实现中。

虽然这些参数没有明确声明，但源代码仍然可以引用它们（就像它可以引用接收对象的实例变量一样）。 一个方法将接收对象称为self，并作为 _cmd 到它自己的选择器。
在下面的例子中，_cmd 指的是strange法的选择器，而 self 指的是接收到strange消息的对象。
```swift
- strange
{
 id  target = getTheReceiver();
 SEL method = getTheMethod();

 if ( target == self || method == _cmd )
     return nil;
 return [target performSelector:method];
}
```

### 3. 获取方法地址
绕过动态绑定的唯一方法是获取方法的地址并直接调用它，就像它是一个函数一样。这在极少数情况下可能是合适的，即特定方法将连续执行多次，并且您希望避免每次执行该方法时的消息传递开销。

使用 NSObject 类中定义的方法-methodForSelector:，你可以要求一个指向实现方法的过程的指针，然后使用指针调用该过程。methodForSelector: 返回的指针必须小心地转换为正确的函数类型。返回类型和参数类型都应包含在强制转换中。

下面的示例显示了如何调用实现 setFilled: 方法的过程：
```swift
void (*setter)(id, SEL, BOOL);
int i;

setter = (void (*)(id, SEL, BOOL))[target
 methodForSelector:@selector(setFilled:)];
for ( i = 0 ; i < 1000 ; i++ )
 setter(targetList[i], @selector(setFilled:), YES);
```

以上也是Apple官方文档关于 runtime 的内容，想看更详细的内容，可以去看Apple官方文档的-Objective-C 运行时编程指南，https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008048-CH1-SW1
 
 
## 三、动态方法解析
### 1. 动态方法的解析
实现 resolveInstanceMethod: 和 resolveClassMethod: 方法分别为实例和类方法的给定选择器动态提供实现。

Objective-C 方法只是一个 C 函数，它至少接受两个参数：self和_cmd，可以使用 class_addMethod 将函数作为方法添加到类中。下面是一个将要动态的添加到类的C函数：
```swift
void dynamicMethodIMP(id self, SEL _cmd) {
 // implementation ....
}
```

实现 resolveInstanceMethod: 方法将 dynamicMethodIMP 函数动态的添加到类中，称为动态解析此方法。
```swift
@implementation MyClass
+ (BOOL)resolveInstanceMethod:(SEL)aSEL
{
 if (aSEL == @selector(resolveThisMethodDynamically)) {
       class_addMethod([self class], aSEL, (IMP) dynamicMethodIMP, "v@:");
       return YES;
 }
 return [super resolveInstanceMethod:aSEL];
}
@end
```
 
消息转发和动态方法解析在很大程度上是正交的。如果调用respondsToSelector: 或instanceRespondToSelector:，则动态方法解析器有机会首先为选择器提供IMP。如果您实现了 resolveInstanceMethod: 但希望通过转发机制实际转发特定的选择器，则为这些选择器返回 NO。


### 2. 动态加载
Objective-C 程序可以在运行时加载和链接新的类和类别。新代码被合并到程序中，并与开始时加载的类和类别相同。

 
 ## 四、消息转发
 我们在调用一个方法的时候，本质上就是通过 objc_msgSend 函数发送消息，才能调用方法。那么，当我们调用一个对象的方法，该方法有声明定义，但没有实现，这个时候程序崩溃，崩溃日志告诉你找不到该方法。
 
 在程序崩溃之前，运行时系统会给接收对象第二次机会来处理消息，接下来就进入到消息转发流程。
 
 ### 1. 转发
 如果你调用了一个没有实现的对象方法，运行时会向对象发送一个 forwardInvocation: 消息，传递一个 NSInvocation 类型的参数，NSInvocation 对象封装了原始消息和随它传递的参数。
 
 这个时候可以实现对象的 forwardInvocation: 方法，将需要发送的消息，转发到另一个对象上。那么重写 forwardInvocation: 后要做的是：
 * 确定消息应该去哪里。
 * 将其连同其原始参数发送到那里。
 
 可以使用 invokeWithTarget: 方法发送消息：
 ```swift
 - (void)forwardInvocation:(NSInvocation *)anInvocation
 {
     if ([someOtherObject respondsToSelector:
             [anInvocation selector]])
         [anInvocation invokeWithTarget:someOtherObject];
     else
         [super forwardInvocation:anInvocation];
 }

 ```
 
 forwardInvocation: 方法可以充当无法识别的消息的分发中心，将它们分发给不同的接收者。或者它可以是一个中转站，将所有消息发送到同一个目的地。
 
 
 
 
 
 
 举个例子，比如现在有 A，B对象，A对象声明了名为negotiate的方法，但没有实现该方法，当我们调用未实现的negotiate方法时，肯定会走到 forwardInvocation: 方法。接下来我们重写 forwardInvocation: 方法，在 forwardInvocation: 里进行一个消息转发，去B对象中查找negotiate方法。
 
 
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
