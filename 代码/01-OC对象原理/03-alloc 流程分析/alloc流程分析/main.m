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
 Objective-C 对象的本质
 1. Objective-C 的面向对象都是基于 C/C++ 的数据结构实现的。
 2. Objective-C 的对象，类主要基于 C/C++ 的结构体实现的。
 3. 通过：xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc Objective-C源文件 -o 目标c或者cpp 文件，在 arm64 环境下，生成的 cpp 文件中， SHPerson 对象被转成了：
     struct SHPerson_IMPL {
         struct NSObject_IMPL NSObject_IVARS;
     };
 
    NSObject_IMPL 的结构：
    struct NSObject_IMPL {
        Class isa;
    };
 
    所以本质上 SHPerson 的结构为：
    struct SHPerson_IMPL {
        Class isa;
    };
 
 Class 的本质
 1. 在 objc-private.h 文件中有 Class 的声明定义：typedef struct objc_class *Class;
 2. objc_class 继承 objc_object 结构体。
    为什么结构体可以继承？
    这是 C++ 的写法，在 C++ 中，结构体和类没有太大的区别，可以把结构体当类来用。最本质的一个区别就是默认的访问控制，struct是public的，class是private的。
 3. Class 本质上是一个结构体指针。
 
 id 的本质
 1. 在 objc-private.h 文件中有 id 的声明定义：typedef struct objc_object *id;
 2. id 本质上是一个结构体指针。
 */

/*
 alloc 源码跟踪：
 alloc -> _objc_rootAlloc -> callAlloc -> _objc_rootAllocWithZone -> _class_createInstanceFromZone
 
 _class_createInstanceFromZone: (核心方法)
 
 1. instanceSize，计算对象需要开辟的内存。
    1. 缓存中快速计算内存大小： cache.fastInstanceSize -> align16。
    2. 计算 isa 和成员变量需要的内存大小（alignedInstanceSize），如果不足16字节的，补齐16字节
 
    3. 对象的内存对齐
    对象内存的大小由成员变量决定，对象在分配内存的时候，按8字节对齐进行分配的（结构体的内存分配原则）。
    但按8字节分配后的内存并实例出来的真正内存，因为系统规定，一个对象的内存至少是16个字节，并且16字节对齐。
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
