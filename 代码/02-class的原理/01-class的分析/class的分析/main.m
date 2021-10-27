//
//  main.m
//  class的分析
//
//  Created by TT-Fangss on 2021/10/27.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/*
 通过分析对象的本质得知instance对象的isa指向class对象，那class对象的isa指向谁呢？指向的对象是不是也像class对象一样呢？它自己的isa指向的又是谁呢？它们之间有联系呢？具体是用来干什么的。
 1. lldb打印
     定义一个 SHPerson 对象，在 main 函数初始化并断点调试。
     /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/断点调试.png
 
     lldb打印结果如下：
     /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/lldb逐步打印isa的指向.png
     
     第一次打印是person的内存分布，并且 0x000021a1000080e9(isa) & 0x0000000ffffffff8ULL，得到person的isa指向的内存地址为0x00000001000080e8且名为SHPerson的class对象。
     
     第二次打印是class对象的内存分布，并且 0x00000001000080c0(isa) & 0x0000000ffffffff8ULL，得到的内存地址为 0x00000001000080c0，po打印的结果是名为SHPerson的calss对象。
     
     对比第一次第二次的打印，两个分别为0x00000001000080f8和0x00000001000080d0的内存地址，打印的出来的class对象的名称是一样的。
     
     第三次是打印0x00000001000080c0的内存分布，并且 0x00000001003790f0(isa) & 0x0000000ffffffff8ULL，得到的内存地址为 0x00000001003790f0，po打印的结果是名为NSObject的calss对象。
     
     再对比前两次的打印，发现是不一样的，0x00000001003790f0和0x00000001000080f8、0x00000001000080d0打印出来的class对象名称是不一样的。
     
     第四次是打印0x00000001003790f0的内存分布，这次发现拿到的 isa 竟然和它一样本身一样，说明0x00000001003790f0的isa指向的是它自己本身。
     
     至此，得知要研究的几个内存地址：
        0x00000001000080e8
        0x00000001000080c0
        0x00000001003790f0
     
    这个内存地址是可能会变的，具体需要自己根据断点进行lldb打印。
     
 2. 烂苹果（MachOView）查看符号表
    使用MachOView打开代码的可执行文件(exec)。
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/可执行文件.png
    
    找到符号表，并且滚动到黄褐色的部分。
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/烂苹果找到class对象和metaclass对象.png
 
    发现，00000001000080E8，00000001000080C0的内存地址不就是上面提到要研究的么，再根据value这一列的值，就可以得知，0x00000001000080e8是class对象，0x00000001000080c0是mateclass对象，那么0x00000001003790f0是什么呢？来看一张图：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/烂苹果推断rootMetaclass对象.png
 
    从图中大概可以猜得到，0x00000001003790f0就是rootMetaClass对象，至此得出以下结论：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/isa的走位.png
    
    instance对象的isa指向class对象，class对象的isa指向metaclass对象，metaclass对象的isa指向rootMetaclass对象，rootMetaclass对象的isa指向的是自己本身。
 */

@interface SHPerson : NSObject
@end
@implementation SHPerson
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SHPerson *person = [[SHPerson alloc] init];
//        Class class_objc = [person class]; // object_getClass(person) || [SHPerson class]
//        Class metaclass_objc = object_getClass(class_objc);
//        Class rootMetaclass_objc = object_getClass(metaclass_objc);
//        Class rootMetaclass_objc2 = object_getClass(rootMetaclass_objc);
//        NSLog(@"\ninstance: %@ \nclass: %@ \nmetaclass: %@ \nrootMetaclass: %@", person, class_objc, metaclass_objc, rootMetaclass_objc);
//        NSLog(@"%@", rootMetaclass_objc2);
        NSLog(@"-------");
    }
    return 0;
}
