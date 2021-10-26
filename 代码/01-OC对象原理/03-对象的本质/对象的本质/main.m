//
//  main.m
//  alloc流程分析
//
//  Created by TT-Fangss on 2021/10/21.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <malloc/malloc.h>

/*
 Objective-C 对象的本质
 1. Objective-C 的面向对象都是基于 C/C++ 的数据结构实现的。
 2. Objective-C 的对象，类主要基于 C/C++ 的结构体实现的。
 3. 通过：xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc Objective-C源文件 -o 目标c或者cpp文件，在 arm64 环境下，生成的 cpp 文件中， SHPerson 对象被转成了：
     struct SHPerson_IMPL {
         struct NSObject_IMPL NSObject_IVARS;
         NSString *_name;
     };
 
    NSObject_IMPL 的结构：
    struct NSObject_IMPL {
        Class isa;
    };
 
    所以本质上 SHPerson 的结构为：
    struct SHPerson_IMPL {
        Class isa;
        NSString *_name;
    };
 
 4. getter 和 setter
    1. 在转成 cpp 文件后，name 属性的 getter 为：
    static NSString * _I_SHPerson_name(SHPerson * self, SEL _cmd) { return (*(NSString **)((char *)self + OBJC_IVAR_$_SHPerson$_name)); }
    它的返回值有个 self + OBJC_IVAR_$_SHPerson$_name，是因为 self + OBJC_IVAR_$_SHPerson$_name 是 name 的值的存储的地方。
    
    2. setter 方法的生成有点特殊
    在用 strong 修饰的时候长这样：
    static void _I_SHPerson_setName_(SHPerson * self, SEL _cmd, NSString *name) { (*(NSString **)((char *)self + OBJC_IVAR_$_SHPerson$_name)) = name; }
 
    用 copy 修饰的时候长这样：
    extern "C" __declspec(dllimport) void objc_setProperty (id, SEL, long, id, bool, bool);
    static void _I_SHPerson_setName_(SHPerson * self, SEL _cmd, NSString *name) { objc_setProperty (self, _cmd, __OFFSETOFIVAR__(struct SHPerson, _name), (id)name, 0, 1); }
 
    应该是系统针对不同的修饰符做了不同的处理。
 
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

@interface SHPerson : NSObject
@property (nonatomic, copy) NSString *name;
@end

@implementation SHPerson
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        /*
         ios 端为小端模式，所以在读取内存的时候从右往左读。
         */
        SHPerson *person = [SHPerson alloc];
        NSLog(@"%zd，%zd，%zd", sizeof(person), class_getInstanceSize(person.class), malloc_size((__bridge const void *)(person)));
    }
    return 0;
}
