//
//  main.m
//  class的分析
//
//  Created by TT-Fangss on 2021/10/27.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/*
 isa的流程探究
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

/*
 class对象，metaclass对象，rootMetaclass对象的继承链
 class对象，metaclass对象，rootMetaclass对象是否也有继承链呢？如果有，是怎么样的一个继承链呢？添加一个继承至SHPerson的SHStudent类。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/01-class的分析/class的分析/SHStudent类.png
 并且为了更好的理解,先把SHStudent比作子类（subClass），SHPerson比作父类（superClass），NSObject比作根类（rootClass）。
 
    1. runtime部分API介绍。
    导入 #import <objc/runtime.h>
    object_getClass:        传一个对象，返回这个对象的class对象。
    class_getSuperclass:    传一个 class，返回 class 的 superclass。
    objc_getClass:          传一个类名称，返回对应的class对象。
    objc_getMetaClass:      传一个类名称，返回对应的metaclass对象。
 
    objc_getClass和objc_getMetaClass先作为了解，因为object_getClass就可以得到 calss对象，metaclass对象，rootMetaclass对象。主要用到object_getClass和class_getSuperclass。
    
    2. 使用 runtime API 打印输出
     、、、
     //1. 子类的instance对象isa流程和继承链。
     NSLog(@"子类(SHStudent)打印");
     SHStudent *student = [[SHStudent alloc] init];
     // class对象
     Class class_student = object_getClass(student);
     // metaclass对象
     Class metaclass_student = object_getClass(class_student);
     // rootMetaclass对象
     Class rootMetaclass_student = object_getClass(metaclass_student);
     
     NSLog(@"class_student        : %@ - %p",class_student, class_student);
     NSLog(@"metaclass_student    : %@ - %p",metaclass_student, metaclass_student);
     NSLog(@"rootMetaclass_student: %@ - %p",rootMetaclass_student, rootMetaclass_student);
     
     NSLog(@"------------------");
     
     // class对象的superclass对象
     Class superclass_student = class_getSuperclass(class_student);
     // metaclass对象的superclass对象
     Class superMetaclass_student = class_getSuperclass(metaclass_student);
     // rootMetaclass对象的superclass对象
     Class superRootMetaclass_student = class_getSuperclass(rootMetaclass_student);
     
     NSLog(@"superclass_student        : %@ - %p",superclass_student, superclass_student);
     NSLog(@"superMetaclass_student    : %@ - %p",superMetaclass_student, superMetaclass_student);
     NSLog(@"superRootMetaclass_student: %@ - %p",superRootMetaclass_student, superRootMetaclass_student);
     
     //2. 父类的instance对象isa流程和继承链。
     NSLog(@"");
     NSLog(@"父类(SHPerson)打印");
     SHPerson *person = [[SHPerson alloc] init];
     // class对象
     Class class_person = object_getClass(person);
     // metaclass对象
     Class metaclass_person = object_getClass(class_person);
     // rootMetaclass对象
     Class rootMetaclass_person = object_getClass(metaclass_person);
     
     NSLog(@"class_person        : %@ - %p",class_person, class_person);
     NSLog(@"metaclass_person    : %@ - %p",metaclass_person, metaclass_person);
     NSLog(@"rootMetaclass_person: %@ - %p",rootMetaclass_person, rootMetaclass_person);
     
     NSLog(@"------------------");
     
     // class对象的superclass对象
     Class superclass_person = class_getSuperclass(class_person);
     // metaclass对象的superclass对象
     Class superMetaclass_person = class_getSuperclass(metaclass_person);
     // rootMetaclass对象的superclass对象
     Class superRootMetaclass_person = class_getSuperclass(rootMetaclass_person);
     
     NSLog(@"superclass_person        : %@ - %p",superclass_person, superclass_person);
     NSLog(@"superMetaclass_person    : %@ - %p",superMetaclass_person, superMetaclass_person);
     NSLog(@"superRootMetaclass_person: %@ - %p",superRootMetaclass_person, superRootMetaclass_person);
     
     //3. 根类的instance对象isa流程和继承链。
     NSLog(@"");
     NSLog(@"根类(NSObject)打印");
     NSObject *object = [[NSObject alloc] init];
     // class对象
     Class class_object = object_getClass(object);
     // metaclass对象
     Class metaclass_object = object_getClass(class_object);
     // rootMetaclass对象
     Class rootMetaclass_object = object_getClass(metaclass_object);
     
     NSLog(@"class_object        : %@ - %p",class_object, class_object);
     NSLog(@"metaclass_object    : %@ - %p",metaclass_object, metaclass_object);
     NSLog(@"rootMetaclass_object: %@ - %p",rootMetaclass_object, rootMetaclass_object);
     
     NSLog(@"------------------");
     
     // class对象的superclass对象
     Class superclass_object = class_getSuperclass(class_object);
     // metaclass对象的superclass对象
     Class superMetaclass_object = class_getSuperclass(metaclass_object);
     // rootMetaclass对象的superclass对象
     Class superRootMetaclass_object = class_getSuperclass(rootMetaclass_object);
     
     NSLog(@"superclass_object        : %@ - %p",superclass_object, superclass_object);
     NSLog(@"superMetaclass_object    : %@ - %p",superMetaclass_object, superMetaclass_object);
     NSLog(@"superRootMetaclass_object: %@ - %p",superRootMetaclass_object, superRootMetaclass_object);
     、、、
 
    3. lldb打印分析
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/01-class的分析/class的分析/子类、父类、根类打印分析.jpeg
 
    红色箭头代表class对象的继承链，黄色箭头代表metaclass对象的继承链，绿色箭头代表rootMetaclass对象的继承链。
    从图得知：
        1. 子类的class对象的父类是父类的class对象，父类的class对象的父类是根类的class对象，根类的class对象为nil。
        2. 子类的metaclass对象的父类是父类的metaclass对象，父类的metaclass对象的父类是根类的metaclass对象，根类的metaclass对象的父类是根类的class对象。
 
    4. 一张经典的图
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/01-class的分析/class的分析/isa流程图.png
 
    这种是一张广为流传并且很经典的图，这张图描述isa的流程以及class的继承链，通过以上的分析再来看这种图就有种豁然开朗的感觉，以前总看不懂这张。
    其实不管是子类、父类还是根类的isa流程和class的继承链都基本是一样的，真正的不同在于根类的metaclass对象(rootMetaclass)这个地方，isa的流程到这儿，isa指针再怎么指都是rootMetaclass自己。rootMetaclass的父类是rootClass，而rootClass对象的superclass指针指向 nil。
    
 
 */

@interface SHPerson : NSObject
@end
@implementation SHPerson
@end

@interface SHStudent : SHPerson
@end
@implementation SHStudent
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //1. 子类的instance对象isa流程和继承链。
        NSLog(@"子类(SHStudent)打印");
        SHStudent *student = [[SHStudent alloc] init];
        // class对象
        Class class_student = object_getClass(student);
        // metaclass对象
        Class metaclass_student = object_getClass(class_student);
        // rootMetaclass对象
        Class rootMetaclass_student = object_getClass(metaclass_student);
        
        NSLog(@"class_student        : %@ - %p",class_student, class_student);
        NSLog(@"metaclass_student    : %@ - %p",metaclass_student, metaclass_student);
        NSLog(@"rootMetaclass_student: %@ - %p",rootMetaclass_student, rootMetaclass_student);
        
        NSLog(@"------------------");
        
        // class对象的superclass对象
        Class superclass_student = class_getSuperclass(class_student);
        // metaclass对象的superclass对象
        Class superMetaclass_student = class_getSuperclass(metaclass_student);
        // rootMetaclass对象的superclass对象
        Class superRootMetaclass_student = class_getSuperclass(rootMetaclass_student);
        
        NSLog(@"superclass_student        : %@ - %p",superclass_student, superclass_student);
        NSLog(@"superMetaclass_student    : %@ - %p",superMetaclass_student, superMetaclass_student);
        NSLog(@"superRootMetaclass_student: %@ - %p",superRootMetaclass_student, superRootMetaclass_student);
        
        //2. 父类的instance对象isa流程和继承链。
        NSLog(@"");
        NSLog(@"父类(SHPerson)打印");
        SHPerson *person = [[SHPerson alloc] init];
        // class对象
        Class class_person = object_getClass(person);
        // metaclass对象
        Class metaclass_person = object_getClass(class_person);
        // rootMetaclass对象
        Class rootMetaclass_person = object_getClass(metaclass_person);
        
        NSLog(@"class_person        : %@ - %p",class_person, class_person);
        NSLog(@"metaclass_person    : %@ - %p",metaclass_person, metaclass_person);
        NSLog(@"rootMetaclass_person: %@ - %p",rootMetaclass_person, rootMetaclass_person);
        
        NSLog(@"------------------");
        
        // class对象的superclass对象
        Class superclass_person = class_getSuperclass(class_person);
        // metaclass对象的superclass对象
        Class superMetaclass_person = class_getSuperclass(metaclass_person);
        // rootMetaclass对象的superclass对象
        Class superRootMetaclass_person = class_getSuperclass(rootMetaclass_person);
        
        NSLog(@"superclass_person        : %@ - %p",superclass_person, superclass_person);
        NSLog(@"superMetaclass_person    : %@ - %p",superMetaclass_person, superMetaclass_person);
        NSLog(@"superRootMetaclass_person: %@ - %p",superRootMetaclass_person, superRootMetaclass_person);
        
        //3. 根类的instance对象isa流程和继承链。
        NSLog(@"");
        NSLog(@"根类(NSObject)打印");
        NSObject *object = [[NSObject alloc] init];
        // class对象
        Class class_object = object_getClass(object);
        // metaclass对象
        Class metaclass_object = object_getClass(class_object);
        // rootMetaclass对象
        Class rootMetaclass_object = object_getClass(metaclass_object);
        
        NSLog(@"class_object        : %@ - %p",class_object, class_object);
        NSLog(@"metaclass_object    : %@ - %p",metaclass_object, metaclass_object);
        NSLog(@"rootMetaclass_object: %@ - %p",rootMetaclass_object, rootMetaclass_object);
        
        NSLog(@"------------------");
        
        // class对象的superclass对象
        Class superclass_object = class_getSuperclass(class_object);
        // metaclass对象的superclass对象
        Class superMetaclass_object = class_getSuperclass(metaclass_object);
        // rootMetaclass对象的superclass对象
        Class superRootMetaclass_object = class_getSuperclass(rootMetaclass_object);
        
        NSLog(@"superclass_object        : %@ - %p",superclass_object, superclass_object);
        NSLog(@"superMetaclass_object    : %@ - %p",superMetaclass_object, superMetaclass_object);
        NSLog(@"superRootMetaclass_object: %@ - %p",superRootMetaclass_object, superRootMetaclass_object);
    }
    return 0;
}
