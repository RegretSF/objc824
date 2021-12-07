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
 
 其实 objc_msgSend 函数的实现是由汇编实现，在 objc 源码中搜索 objc_msgSend 后：
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/07-objc_msgSend汇编实现/objc_msgSend汇编实现/源码搜索 objc_msgSend 找到汇编文件.png
 
 .s 文件是汇编文件，因为iPhone手机属于 arm64 架构的，所以我们直接看 arm64 架构的 objc_msgSend 汇编实现就好了，找到 objc_msgSend 的实现入口。在汇编文件中，ENTRY 和 END_ENTRY 是成对出现的。
 ```swift
 //- 消息发送 -- 汇编入口-- objc_msgSend 主要是拿到接收者的isa信息
     ENTRY _objc_msgSend
 //- 无窗口
     UNWIND _objc_msgSend, NoFrame

 //- p0 和空对比，即判断接收者是否存在，其中 p0 是 objc_msgSend 的第一个参数-receiver
     cmp    p0, #0            // nil check and tagged pointer check

 //- le小于 --支持tagged pointer（小对象类型）的流程
 #if SUPPORT_TAGGED_POINTERS
     b.le    LNilOrTagged        //  (MSB tagged pointer looks negative)
 #else
 //- p0 等于 0 时，直接返回 空
     b.eq    LReturnZero
 #endif

 //- p0即receiver 肯定存在的流程
 //- 根据对象拿出isa ，即从x0寄存器指向的地址 取出 isa，存入 p13 寄存器
     ldr    p13, [x0]        // p13 = isa
 //- 在64位架构下通过 p16 = isa（p13） & ISA_MASK，拿出shiftcls信息，得到class信息
     GetClassFromIsa_p16 p13, 1, x0    // p16 = class
 LGetIsaDone:
     // calls imp or objc_msgSend_uncached
 //- 如果有isa，走到CacheLookup 即缓存查找流程，也就是所谓的sel-imp快速查找流程
     CacheLookup NORMAL, _objc_msgSend, __objc_msgSend_uncached

 #if SUPPORT_TAGGED_POINTERS
 LNilOrTagged:
 //- 等于空，返回空
     b.eq    LReturnZero        // nil check
     GetTaggedClass
     b    LGetIsaDone
 // SUPPORT_TAGGED_POINTERS
 #endif

 LReturnZero:
     // x0 is already zero
     mov    x1, #0
     movi    d0, #0
     movi    d1, #0
     movi    d2, #0
     movi    d3, #0
     ret

     END_ENTRY _objc_msgSend

 ```
 
 在汇编代码中，我们可以配合注释来理解一些汇编指令的含义。那么，通过汇编，得出 objc_msgSend 函数的实现流程为：
 1. 判断消息接受者是否为 nil，如果为 nil，返回 nil - 这里还会判断是否支持 Tagged Pointer 技术。
 2. 通过接受者的isa，取出类对象的信息。
 3. 调用 CacheLookup，开始进行缓存查找流程。
 
 
 
*/

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
