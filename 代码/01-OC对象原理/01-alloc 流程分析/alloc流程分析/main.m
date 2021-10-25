//
//  main.m
//  alloc流程分析
//
//  Created by TT-Fangss on 2021/10/21.
//

#import <Foundation/Foundation.h>
#import "SHPerson.h"
//#import "SHTeacher.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>

/*
 alloc 源码跟踪：
 alloc -> _objc_rootAlloc -> callAlloc -> _objc_rootAllocWithZone -> _class_createInstanceFromZone
 
 _class_createInstanceFromZone: (核心方法)
 
 1. instanceSize，计算对象需要开辟的内存。
    1. 缓存中快速计算内存大小： cache.fastInstanceSize -> align16。
    2. 计算 isa 和成员变量需要的内存大小（alignedInstanceSize），如果不足16字节的，补齐16字节
 
    3. 对象的内存对齐
    对象内存的大小由成员变量决定，一个 NSObject 只有里有一个 isa 指针变量，isa 指针占用 8 字节。所以一个 NSObject 实际上需要 8 个字节来存储，但是由于内存对齐的因，系统会分配给 NSObject 16 个字节。
    源码跟踪或用以下方法验证：
 
    sizeof：判断数据类型或者表达式长度的运算符,返回一个变量或者类型的大小（以字节为单位）
    class_getInstanceSize：返回类实例的大小。
    malloc_size：系统分配的内存大小
    
    sizeof 和 class_getInstanceSize 是获得这个对象需要占用的内存。malloc_size 是获得系统会给这个实例对象分配的内存。
 
    4. 内存对齐原则
    1：数据成员对⻬规则:结构(struct)(或联合(union))的数据成员，第一个数据成员放在offset为0的地方，以后每个数据成员存储的起始位置要从该成员大小或者成员的子成员大小(只要该成员有子成员，比如说是数组，结构体等)的整数倍开始(比如int为4字节,则要从4的整数倍地址开始存储。 min(当前开始的位置m n)m=9 n=4 9 10 11 12
    2：结构体作为成员:如果一个结构里有某些结构体成员,则结构体成员要从其内部最大元素大小的整数倍地址开始存储.(struct a里存有struct b,b里有char,int,double等元素,那b应该从8的整数倍开始存储.)
    3：收尾工作:结构体的总大小,也就是sizeof的结果,.必须是其内部最大成员的整数倍，不足的要补⻬。
 
 2. calloc 开辟内存。
    在 libmalloc-317.40.8 源码中，calloc的流程：
 
    calloc -> _malloc_zone_calloc -> default_zone_calloc -> nano_calloc -> _nano_malloc_check_clear -> segregated_size_to_fit。
    直到 segregated_size_to_fit 方法中，查看 NANO_REGIME_QUANTA_SIZE 的定义发现以下宏定义：
 
     #define NANO_MAX_SIZE            256 （ Buckets sized {16, 32, 48, ..., 256} ）
     #define SHIFT_NANO_QUANTUM        4
     #define NANO_REGIME_QUANTA_SIZE    (1 << SHIFT_NANO_QUANTUM)    // 16
     #define NANO_QUANTA_MASK        (NANO_REGIME_QUANTA_SIZE - 1)
     #define NANO_SIZE_CLASSES        (NANO_MAX_SIZE/NANO_REGIME_QUANTA_SIZE)
 
    得知，calloc 开辟内存是遵守 16 字节对齐的。
 
    
 
 3. initInstanceIsa 将 cls 和 isa 绑定在一起，进行关联。
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        /*
         ios 端为小端模式，所以在读取内存的时候从右往左读。
         */
        SHPerson *person = [SHPerson alloc];
        person.name = @"zhan san";
        person.nickName = @"z s";
        person.age = 18;
        person.height = 180;
        
        // 16+16+8+8 = 
        
        NSLog(@"%zd，%zd，%zd", sizeof(person), class_getInstanceSize(person.class), malloc_size((__bridge const void *)(person)));
    }
    return 0;
}
