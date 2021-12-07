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
 
    这是因为系统在对用 copy 修饰的属性进行了特殊的处理。
    
    3. 在平时写的 OC 写的 setter 和 getter 中，发现并没有 SHPerson * self, SEL _cmd 这两个参数，但 clang 编译成的 C++ 文件中有。得知， SHPerson * self, SEL _cmd 是这两个方法的隐藏参数，这也就是为什么我们在实例方法里面都可以使用 self 的原因。
 
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
 isa:
 通过以上分析知道，NSObject 里有一个 Class 类型的 isa 指针，而 Class 的基础关系是：Class -> objc_class -> objc_object。通过源码，看到 objc_object 里有一个 isa_t isa; isa_t 是一个联合体，里面用到了一个宏定义 ISA_BITFIELD，点击去，发现了一堆宏定义，在此之前，先对联合体、位域做一个补充。
 
 1. 位域、联合体
    1. 简单的结构体（struct）
     struct SHCar1 {
         BOOL front; // 0 1
         BOOL back;
         BOOL left;
         BOOL right;
     };
    
    当前结构体有四个 BOOL 值，一个 BOOL 值占用一个字节。所以，SHCar1 共占 4 个字节。
 
    2. 位域
     struct SHCar2 {
         BOOL front: 1;
         BOOL back : 1;
         BOOL left : 1;
         BOOL right: 1;
     };
 
    : 1 表示指定这个成员变量占用1位(bit)，SHCar2 一共占用4位，所以，SHCar2 占用 1 个字节。
 
    注意：
        在16位的系统中1字(Word) = 2字节（Byte）= 16（bit）。
        在32位的系统中1字(Word) = 4字节（Byte）= 32（bit）。
        在64位的系统中1字(Word) = 8字节（Byte）= 64（bit）。
 
    3. 联合体（union）
    // 联合体
     union SHTeacher1 {
         char *name;
         int  age;
     };
    // 结构体
     struct SHTeacher2 {
         char *name;
         int  age;
     };
 
    4. 结构体与联合体的区别
 
     union SHTeacher1 t1;
     t1.name = "Andy";
     t1.age = 18;

     struct SHTeacher2 t2;
     t2.name = "Andy";
     t2.age = 18;
 
    以上代码，通过lldb打印如下：
    联合体打印：
     (lldb) p t1
     (SHTeacher1) $0 = (name = 0x0000000000000000, age = 0)
     (lldb) p t1
     (SHTeacher1) $1 = (name = "Andy", age = 16296)
     (lldb) p t1
     (SHTeacher1) $2 = (name = "", age = 18)
    结构体打印：
     (lldb) p t2
     (SHTeacher2) $3 = (name = 0x0000000000000000, age = 0)
     (lldb) p t2
     (SHTeacher2) $4 = (name = "Andy", age = 0)
     (lldb) p t2
     (SHTeacher2) $5 = (name = "Andy", age = 18)
     
    总结：
        1. struct内成员变量的存储互不影响，union内的对象存储是互斥的。
        2. 结构体（struct）中所有的变量是共存的，优点是可以存储所有的对象的值，比较全面。缺点是struct内存空间分配是粗放的，不管是否被使用，全部分配。
        3. 联合体（union）中所有的变量是互斥的，优点是内存使用更加精细灵活，也节省了内存空间，缺点也很明显，就是不够包容。
 
 
 2. nonPointerIsa分析
 回到 isa_t isa，isa_t 使用 union 的原因也大概是因为内存优化的考虑。isa 指针中通过 char + 位域（即二进制中每一位均可表示不同的信息），通常来说，isa 指针占用的内存大小是8字节即64 bit(64位系统下)，已经足够存储很多的信息了，这样可以极大的节省内存，以提高性能。
 
 在 isa_t 中，有个 struct，struct 有个 ISA_BITFIELD 的成员变量，ISA_BITFIELD 的部分定义如下：
     uintptr_t nonpointer        : 1;                                       \
     uintptr_t has_assoc         : 1;                                       \
     uintptr_t has_cxx_dtor      : 1;                                       \
     uintptr_t shiftcls          : 33;                                      \
     uintptr_t magic             : 6;                                       \
     uintptr_t weakly_referenced : 1;                                       \
     uintptr_t unused            : 1;                                       \
     uintptr_t has_sidetable_rc  : 1;                                       \
     uintptr_t extra_rc          : 19
 
 可以看到的是 ISA_BITFIELD 用到了位域。以下是各个成员的注释：
 nonpointer         : 表示是否对 isa 指针开启指针优化 0:纯isa指针，1:不止是类对象地址,isa 中包含了类信息、对象的引用计数等。
 has_assoc          : 关联对象标志位，0没有，1存在。
 has_cxx_dtor       : 该对象是否有 C++ 或者 Objc 的析构器,如果有析构函数,则需要做析构逻辑, 如果没有,则可以更快的释放对象。
 shiftcls           : 存储类指针的值。开启指针优化的情况下，在 arm64 架构中有 33 位用来存储类指针。
 magic              : 用于调试器判断当前对象是真的对象还是没有初始化的空间。
 weakly_referenced  : 指对象是否被指向或者曾经指向一个 ARC 的弱变量，没有弱引用的对象可以更快释放。
 unused             : 标志对象是否正在释放内存。
 has_sidetable_rc   : 当对象引用技术大于 10 时，则需要借用该变量存储进位。
 extra_rc           : 当表示该对象的引用计数值，实际上是引用计数值减 1， 例如，如果对象的引用计数为 10，那么 extra_rc 为 9。如果引用计数大于 10， 则需要使用到 has_sidetable_rc。
 
 3. isa 推导 class
 通过 [SHPerson class] 可以拿到 SHPerson 的 class 对象。每个对象都有一个 isa，这个 isa 指向的是 class 对象，但通过 lldb 打印 SHPerson 实力对象的内存分布发现，第一块内存地址（也就是isa）和 [SHPerson class] 拿到的 class 对象的内存地址不一样。
 isa: 0x000021a100008175
 class对象: 0x0000000100008170
 
    1. ISA_MASK 获取 calss 对象的内存地址
     这是因为苹果做了一个掩码的操作，在 isa.h 文件中有一个 ISA_MASK 的宏定义（系统架构不一样，值也不一样，调试的时候根据运行环境选取不同的值），用 isa 的地址 & 上 ISA_MASK，就可以得出 class 对象的内存地址。
    打印如下：
     (lldb) x/4gx person
     0x1007170c0: 0x000021a100008175 0x0000000000000000
     0x1007170d0: 0x0000000000000000 0xce7ed407c2c98f1d
     (lldb) p/x [SHPerson class]
     (Class) $3 = 0x0000000100008170 SHPerson
     (lldb) p/x 0x000021a100008175 & 0x0000000ffffffff8ULL
     (unsigned long long) $10 = 0x0000000100008170
 
    2. isa 的位运算获取 calss 对象的内存地址
    通过分析 isa_t 得知 ISA_BITFIELD 的 shiftcls 是用来存储 class 指针的值，所以只要拿到 shiftcls，看看里面存放的值就可以得知 calss 对象的内存地址。
    观察到在 arm64 下，shiftcls 占33位，在前面共有3位（1+1+1），后面共有28位（6+1+1+1+19）。
    所以，运算的步骤如下：
        1. 左移3位     -- 顶掉前面的3位，这时后面会空出3位，不足用0补。
        2. 右移31位    -- 后面本来有28位，加上用0补的3位，一共31位
        3. 左移28位    -- 将 shiftcls 归位。
    平移的数位不是固定的，根据 ISA_BITFIELD 中的规定得算出来的。
 
    打印如下：
     (lldb) x/4gx person
     0x100722a40: 0x000021a100008175 0x0000000000000000
     0x100722a50: 0x000000010080db90 0xcdb2bd35671d6859
     (lldb) p/x 0x000021a100008175 >> 3
     (long) $1 = 0x000004342000102e
     (lldb) p/x 0x000004342000102e << 20
     (long) $2 = 0x4342000102e00000
     (lldb) p/x 0x4342000102e00000 >> 17
     (long) $3 = 0x000021a100008170
     (lldb) p/x [SHPerson class]
     (Class) $4 = 0x0000000100008170 SHPerson
     (lldb)
 */

// 结构体
struct SHCar1 {
    BOOL front; // 0 1
    BOOL back;
    BOOL left;
    BOOL right;
};

// 结构体位域
struct SHCar2 {
    BOOL front: 1;
    BOOL back : 1;
    BOOL left : 1;
    BOOL right: 1;
};

//struct LGCar2 {
//    BOOL front: 1;
//    BOOL back : 2;
//    BOOL left : 6;
//    BOOL right: 1;
//};

// 联合体
union SHTeacher1 {
    char *name;
    int  age;
};

// 结构体
struct SHTeacher2 {
    char *name;
    int  age;
};

@interface SHPerson : NSObject
@property (nonatomic, copy) NSString *name;

- (void)run;
@end

@implementation SHPerson
- (void)run {
    NSLog(@"%s",__func__);
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
//        struct SHCar1 car1;
//        struct SHCar2 car2;
//        NSLog(@"%zd -- %zd", sizeof(car1), sizeof(car2));
        
//        union SHTeacher1 t1;
//        t1.name = "Andy";
//        t1.age = 18;
//
//        struct SHTeacher2 t2;
//        t2.name = "Andy";
//        t2.age = 18;
        
        SHPerson *person = [SHPerson alloc];
        [person run];
        NSLog(@"%zd，%zd，%zd", sizeof(person), class_getInstanceSize(person.class), malloc_size((__bridge const void *)(person)));
    }
    return 0;
}
