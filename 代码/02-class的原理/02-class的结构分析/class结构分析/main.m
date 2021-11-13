//
//  main.m
//  class结构分析
//
//  Created by TT-Fangss on 2021/10/28.
//

/*
 Class的结构分析：
     在前面的探索中，已知Class本质上是一个结构体指针，是 objc_class* 的别名，而objc_class继承至objc_object。
     1. 过时的 objc_class 定义。
     源码工程中搜索 objc_class {，如图：
     /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/过时的objc_class的结构.png
     在结构体的尾部，有 OBJC2_UNAVAILABLE 这一声明，意思是这个 objc_class 的定义，在 OBJC2 中是不可用的，但我们从这个结构体中也可以参考一下里面的结构。
     
     2. OBJC2 中 objc_class 的定义
     源码工程中搜索 objc_class : objc_object {，如图：
     /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/objc_class的真正结构.png
     搜索出来的有两个 objc_class 的定义，分别在两个文件为objc-runtime-new.h和objc-runtime-old.h,这里选择objc-runtime-new.h的objc_class定义，因为这个是新的，肯定用这个。
     
     3. Class的结构探究
     影响对象的内存大小是由成员变量决定的，所以在分析 Class 的时候，我们只需要关注，objc_object和objc_class的成员变量，像里面定义的一些方法，静态变量什么的都可以不用关注。
     如下图：
     /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/objc_object的成员变量.png
     /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/objc_class的成员变量.png

     objc_object的成员变量只有isa，objc_class的成员变量有superclass，cache，bits。通过名称大致可以知道，superclass是指向父类的指针，cache为缓存，bits为数据。
     所以 Class 的结构一目了然，分别是：
     isa_t isa;
     Class superclass;
     cache_t cache;
     class_data_bits_t bits;
     
     下一步的探究是 bits数据分析，在这之前得加深一下指针和内存平移的知识。
 */

/*
 指针和内存平移
 以下研究的分别为普通指针，对象指针，数组指针。
 、、、
 // 普通指针 --  地址->值
 int a = 10; //
 int b = 10; //
 NSLog(@"%d -- %p",a,&a);
 NSLog(@"%d -- %p",b,&b);

 // 对象指针 -- 地址->地址->值
 SHPerson *p1 = [SHPerson alloc];
 SHPerson *p2 = [SHPerson alloc];
 NSLog(@"%@ -- %p",p1,&p1);
 NSLog(@"%@ -- %p",p2,&p2);

 // 数组指针
 // 数组的首地址就是第0个元素的地址,通过元素的地址可以取元素的值。
 // 将数组c赋值给int类型的指针d，以d+n的形式获取值相当于&c[n]，表示获取数组元素的地址。
 int c[4] = {1,2,3,4};
 int *d   = c;
 NSLog(@"%p - %p - %p",&c,&c[0],&c[1]);
 NSLog(@"%p - %p - %p",d,d+1,d+2);

 // d+i是通过内存平移的方式获取内存中的地址，而*(d+i)是取内存中这个地址的值。
 for (int i = 0; i<4; i++) {
     int value =  *(d+i);
     NSLog(@"%d",value);
 }
 // OC 类 结构 首地址 - 平移一些大小 -> 内容
 // SHPerson.class地址 - 平移 所有的值
 NSLog(@"指针 - 内存偏移");
 、、、
 
 通过以上的测试其实就是想说明一点，在 OC 中，我们可以通过向数组一样的内存平移获取元素值的方式获取对象中成员变量的值。
 */

/*
 Class 的结构内存计算
 因为需要拿到bits的内存地址和值，所以要知道isa，superclass，cache占用的内存大小，从而得知bits的内存，这个时候就需要用到上诉的内存平移获取值的操作了。
 已知，isa占8字节，superclass8字节，唯一不知道的只有 cache，来看一下 cache_t 的结构：
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/cache_t的结构.png
 cache_t 只有两个变量，一个是联合共用体，一个是 explicit_atomic<uintptr_t>，explicit_atomic<uintptr_t>占8字节，另外一个联合共用体也只占8个字节，加起来16字节，所以cache占16个字节。
 接下来可以求出bits的内存地址：
 、、、
 isa_t isa;             // 8字节
 Class superclass;      // 8字节
 cache_t cache;         // 16字节
 class_data_bits_t bits;
 
 求出 bits 的内存地址
isa的内存大小 + superclass的内存大小 + cache的内存大小
 8 + 8 + 16 = 32
 SHPerson.class首地址 + 32个字节
 、、、
 
 这是一段 lldb 的打印分析：
 、、、
 (lldb) x/6gx SHPerson.class
 0x1000080e8: 0x00000001000080c0 0x0000000100379140
 0x1000080f8: 0x0001000100797e90 0x0001801000000000
 0x100008108: 0x0000000100797e74 0x000000010009d910
 (lldb) p/x 0x1000080e8+0x20
 (long) $5 = 0x0000000100008108
 (lldb) p (class_data_bits_t *)0x0000000100008108
 (class_data_bits_t *) $6 = 0x0000000100008108
 (lldb)
 、、、
 
 可以看到 0x1000080e8(SHPerson.class首地址)+ 0x20(32) 取到bits的内存地址是第三行的地址0x100008108，我们再对这个内存地址进行一个强转。下一步就是探索这个 bits 里面有什么。
 */

/*
 class_rw_t 的探索
 在拿到 class_data_bits_t 的内存地址后，需要拿到里面的data，怎么那呢，我们看到源码是这么拿的：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/class_rw_t 的获取.png
 
 那我们也假里假气的，通过lldb打印的方式去获取：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/lldb获取class_rw_t的结构.png
我们通过 p $2->data() 的方式拿到了 class_rw_t 的内存地址，并且回想起通过内存地址取值的操作，p *($3)就拿到了class_rw_t的结构。（$2和$3都是lldb打印生成的变量名。）
 
 我们现在需要拿到，这个类里缓存的方法，属性，协议等等。先来看class_rw_t里有什么。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/class_rw_t的成员变量.png

 这么一看，貌似没有我们想要的东西，那就找方法，往下找，发现：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/class_rw_t获取属性，方法的方法.png
 这个不就是我们需要的么，为此，我们先来给 SHPerson 添加属性和方法：
 、、、
 @interface SHPerson : NSObject
 @property (nonatomic, copy) NSString *name;
 @property (nonatomic) NSInteger age;
 @end
 @implementation SHPerson
 - (void)setNickname:(NSString *)name {
 }
 @end
 、、、
 重新运行，重新拿到 class_rw_t，并获取属性和方法：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/properties()方法的lldb打印.png
 
 通过 lldb 打印 p $3.properties()，拿到了类型为 property_array_t 的 $4，通过property_array_t在运行时的结构看到里面有 ptr 这个指针地址。打印出来发现它是一个 property_list_t 类型的，来看看源码中 property_list_t 是什么：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/property_list_t源码定义.png
 
 源码中什么都没有，但它继承自 entsize_list_tt：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/entsize_list_tt源码定义.png
 
 可以看到，里面有一个 get 获取元素的方法，get 里调用 getOrEnd，发现，getOrEnd的实现，是通过内存平移的方式来拿到对应的元素！
 这时，我们试试在lldb打印中通过get方法拿我们的属性相关的东西,但是因为 lldb 打印的原因，得重新运行，并且我们知道 ptr 的类型 为 property_list_t，在打印到property_array_t的时候，可以直接强制将 ptr 转换为 property_list_t，不然在lldb中不能通过get方法打印出相关的东西。
 lldb打印：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/lldb打印property_list_t含有的属性.png
 
 通过lldb打印，确实有属性相关的东西，来看看方法，过程和属性的差不多。
 methods() 返回的是一个 method_array_t 类型的，他一样继承自entsize_list_tt，但通过get方法打印的出来的是一个里面啥都没有的 method_t 类型：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/methods()方法的lldb打印.png
 
 不要着急，来看一下 method_t 的结构：
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/method_t的结构.png
 
 这么一看，好像看不出什么，我们往下看：
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/method_t的name()方法和imp方法.png
通过lldb打印name方法，成功获取到对应的方法名称！并且，细心的发现，我们拿到的都是对象方法！
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/02-class的结构分析/class结构分析/打印method_t中的name方法.png
 另外 .cxx_destruct方法原本是为了C++对象析构的，ARC借用了这个方法插入代码实现了自动内存释放的工作。
 
 总结：通过探究Class了解到Class有四个成员变量，分别为 isa，superclass，cache和bits，主角是bits。通过内存平移我们拿到了bits的内存地址，之后我们观察class_data_bits_t的源码得知，调用data方法可以拿到结构为class_rw_t的数据，再次观察class_rw_t的源码得知class_rw_t里有获取我们对象的属性、方法和协议，最后通过lldb打印一一证明了。
     因为一开始探究的时候，就是通过 SHPerson class对象来探究Class的，现在对Class已经有一个初步的了解了，并且，通过这次探究，得知class对象有isa，superclass，属性信息，对象方法信息，协议信息，成员变量信息等。
 */

#import <Foundation/Foundation.h>

@interface SHPerson : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSInteger age;
@end
@implementation SHPerson
- (void)setNickname:(NSString *)name {
}

+ (instancetype)person {
    return [[SHPerson alloc] init];
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
//        // 普通指针 --  地址->值
//        int a = 10; //
//        int b = 10; //
//        NSLog(@"%d -- %p",a,&a);
//        NSLog(@"%d -- %p",b,&b);
//
//        // 对象指针 -- 地址->地址->值
//        SHPerson *p1 = [SHPerson alloc];
//        SHPerson *p2 = [SHPerson alloc];
//        NSLog(@"%@ -- %p",p1,&p1);
//        NSLog(@"%@ -- %p",p2,&p2);
//
//        // 数组指针
//        // 数组的首地址就是第0个元素的地址,通过元素的地址可以取元素的值。
//        // 将数组c赋值给int类型的指针d，以d+n的形式获取值相当于&c[n]，表示获取数组元素的地址。
//        int c[4] = {1,2,3,4};
//        int *d   = c;
//        NSLog(@"%p - %p - %p",&c,&c[0],&c[1]);
//        NSLog(@"%p - %p - %p",d,d+1,d+2);
//
//        // d+i是通过内存平移的方式获取内存中的地址，而*(d+i)是取内存中这个地址的值。
//        for (int i = 0; i<4; i++) {
//            int value =  *(d+i);
//            NSLog(@"%d",value);
//        }
//        // OC 类 结构 首地址 - 平移一些大小 -> 内容
//        // SHPerson.class地址 - 平移 所有的值
//        NSLog(@"指针 - 内存偏移");
        
        SHPerson *person = [[SHPerson alloc] init];
        NSLog(@"类的结构内存计算");
    }
    return 0;
}
