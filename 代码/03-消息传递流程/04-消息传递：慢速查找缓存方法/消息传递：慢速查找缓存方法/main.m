//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>

/*
 objc_msgSend 函数在进行消息传递的过程中，会先进行快速查找缓存方法，快速查找缓存方法是用汇编实现，其汇编函数名为 CacheLookup 。如果 CacheLookup 函数中没有找到要匹配的方法，会跳转到 __objc_msgSend_uncached 函数。
 
__objc_msgSend_uncached 的实现如下：
 ```swift
 STATIC_ENTRY __objc_msgSend_uncached
 UNWIND __objc_msgSend_uncached, FrameWithNoSaves

 // THIS IS NOT A CALLABLE C FUNCTION
 // Out-of-band p15 is the class to search
 
 MethodTableLookup
 TailCallFunctionPointer x17

 END_ENTRY __objc_msgSend_uncached
 ```
 
 在 __objc_msgSend_uncached 函数中会执行 MethodTableLookup 函数，MethodTableLookup 函数实现如下：
 ```swift
 .macro MethodTableLookup
     
     SAVE_REGS MSGSEND

     // lookUpImpOrForward(obj, sel, cls, LOOKUP_INITIALIZE | LOOKUP_RESOLVER)
     // receiver and selector already in x0 and x1
     mov    x2, x16
     mov    x3, #3
     bl    _lookUpImpOrForward

     // IMP in x0
     mov    x17, x0

     RESTORE_REGS MSGSEND

 .endmacro
 ```
 
 bl 指令：带链接程序跳转，也就是要带返回地址。也就是说，MethodTableLookup 函数调用后，会跳转到 _lookUpImpOrForward 函数，查找 IMP。
 注意：
 * C/C++ 中调用汇编 ，去查找汇编时，需要将 C/C++ 调用的方法多加一个下划线。例如 objc_msgSend 在汇编中是 _objc_msgSend。
 * 汇编中调用 C/C++ 方法时，去查找 C/C++ 方法，需要将汇编调用的方法去掉一个下划线。例如 例如 _objc_msgSend 在C/C++中是 objc_msgSend。
 
 所以，_lookUpImpOrForward 的实现是用 C/C++ 写的，实现代码如下：
 ```swift
 ```
 */

/**
 二分查找：
 什么叫二分查找呢。
 举个例子：
 这里有一个区间 0～100，我需要找到 55 这个数的位置，按正常的逻辑用一个循环去遍历，也可以找到，但会有个问题，循环遍历需要一个一个的去找，会非常的消耗性能。
 如果用二分查找，是怎么查找呢。
 随便取一个数，比如 50 ，那么 50 是小于 55 。
 再取一个数，这个数是 50～100 区间内的数，比如 75，那么 75 大于 55 。
 再取一个数，50～75 区间内的数，比如 60，60 还是大于 55。
 再取一个数，50～60 区间内的数，比如 55，这个时候就找到了。
 那么通过这个二分查找呢，我们就用了 4 ，相比于循环一个一个去遍历是不是快了很多呢。
 下面的这个
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
