//
//  main.m
//  objc_msgSend介绍
//
//  Created by TT-Fangss on 2021/12/6.
//

#import <Foundation/Foundation.h>

/*
 
 objc_msgSend 函数的汇编实现
 
 在 OC 中调用方法，在运行时是由 objc_msgSend 函数进行消息传递，从而调起对象方法。在官方文档中也只是介绍了 objc_msgSend 函数的作用，但底层 objc_msgSend 是如何实现的呢。
 
 ## 一、源码搜索 objc_msgSend
 在 objc 源码中搜索 objc_msgSend( ，只找到了 objc_msgSend 函数的定义。
 ```swift
 OBJC_EXPORT id _Nullable
 objc_msgSend(id _Nullable self, SEL _Nonnull op, ...)
     OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0);
 ```
 
 在下面还有一个 objc_msgSendSuper 函数，这是一个将消息发给父类的函数。
 ```swift
 OBJC_EXPORT id _Nullable
 objc_msgSendSuper(struct objc_super * _Nonnull super, SEL _Nonnull op, ...)
     OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0);
 ```
 
 其它参数和 objc_msgSend 函数的参数一样，只有 objc_super 不一样，objc_super 是一个结构体指针，在源码中找到了 objc_super 结构体的定义。 struct objc_super 需要两个成员变量，一个是消息接收者，一个是消息接收者的类对象的父类对象。
 ```swift
 /// Specifies the superclass of an instance.
 struct objc_super {
     /// Specifies an instance of a class.
     __unsafe_unretained _Nonnull id receiver;

     /// Specifies the particular superclass of the instance to message.
 #if !defined(__cplusplus)  &&  !__OBJC2__
     // For compatibility with old objc-runtime.h header
     __unsafe_unretained _Nonnull Class class;
 #else
     __unsafe_unretained _Nonnull Class super_class;
 #endif
     //super_class is the first class to search
 };
 ```
 
 ## 二、objc_msgSend 的汇编实现

 
 
 
 
 
*/

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
