//
//  main.m
//  objc_msgSend介绍
//
//  Created by TT-Fangss on 2021/12/6.
//

#import <Foundation/Foundation.h>

/**
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
 
 
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
