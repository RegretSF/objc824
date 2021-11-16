//
//  main.m
//  Objective-C运行时的改进
//
//  Created by TT-Fangss on 2021/11/16.
//

#import <Foundation/Foundation.h>

/**
 一、数据结构的变化
 类对象本身包含了最常被访问的信息：指向元类、超类和方法缓存的指针，它还有一个指向更多数据的指针。
 
 class_ro_t：
“ro”代表只读，它包括像类名词，方法，协议，和实例变量的信息。Swift类和Objective-C类共享这一数据结构，所以每个Swift类也有这些数据结构。
 
 当类第一次从磁盘中加载到内存中时，它们一开始也是这样的，但一经使用，它们就会发生变化。
 
 了解这些变化之前，先了解一下 clean memory 和 dirty memory 的区别。
 
 clean memory：指加载后不会发生更改的内存，class_ro_t 就属于 clean memory，因为它是只读的。
 
 dirty memory：指在进程运行时会发生更改的内存
 
 二、方法列表的变化
 三、tagged pointer 格式的变化
 
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
