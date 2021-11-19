//
//  main.m
//  类的成员变量和分类方法的存储
//
//  Created by TT-Fangss on 2021/11/19.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark: - Protocol
@protocol SHPersonProtocol<NSObject>
- (void)run;
- (void)sleep;
+ (void)work;
@end

#pragma mark: - SHPerson
@interface SHPerson : NSObject<SHPersonProtocol>
{
    NSString *_name;
    NSString *_age;
    NSObject *family;
}
@property (nonatomic, copy) NSString *nickname;
@end
@interface SHPerson()
@property (nonatomic, copy) NSString *sex;
- (void)play_table_tennis;
@end
@implementation SHPerson
- (void)play_basketball {}
+ (void)playFootball {}

/// 扩展
- (void)play_table_tennis {}

/// SHPersonProtocol
- (void)run {}
- (void)sleep {}
+ (void)work {}
@end

#pragma mark: - SHPerson 的分类
@interface SHPerson(Home)
@property (nonatomic, copy) NSString *height;

- (void)write_homework;
+ (void)eat;
@end
@implementation SHPerson(Home)
- (void)setHeight:(NSString *)height {}
- (NSString *)height { return @""; }

- (void)write_homework {}
+ (void)eat {}
@end

#pragma mark: - SHTeacher
@interface SHTeacher : SHPerson
@property (nonatomic, strong) NSString *course;
@end
@implementation SHTeacher
- (void)attend_class {}
+ (void)change_homework {}
@end


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        SHPerson *p = [[SHPerson alloc] init];
        SHTeacher *t = [[SHTeacher alloc] init];
        
        NSLog(@"Hello, World!");
    }
    return 0;
}

/**
 class_ro_t 的探索
 验证 WWDC2020 中 Objective—C 在运行时的一些优化
 
 1. class_ro_t 存储着 Flags，Size，Name，Methods，Protocols，Ivars，Properties。
 2. class_rw_t 存储着 Methods，Protocols，Properties。
 3. 为什么 class_ro_t 已经存储了 Methods，Protocols，Properties，而 class_rw_t 还要存储这些呢？
 WWDC 中的介绍是 class_ro_t 是只读的，存储的信息在编译时期就已经确定了，不能再更改，并且必要的时候可以清除，需要用的时候重磁盘中加载就好了。class_rw_t 是可读可写的，它信息的存储是在运行的时候，需要用到的时候才会写入，并且一直存在于内存中，并且为了优化，还延伸出一个 class_rw_ext_t，这个会不会是 WWDC 提到的，存储分类方法和属性的地方呢？。
 4. 之前的文章中提到 class_rw_t 的 firstSubclass 一开始为什么为nil的问题，在 WWDC 中提到，只有当我们使用到这个类的时候才会进行储存，有点类似懒加载的意思。
 
 其中，第2点我们在前面的篇章中已经验证过了，确实有方法列表，协议列表和属性列表，其中协议列表没有去验证，但看完下面的验证方法后，再去验证class_rw_t的协议方法，也是一样的。接下来我们重点研究的是 class_ro_t 和 firstSubclass 为 nil 的问题。
 
 我们先声明几个类，分别为继承自 NSObject 的 SHPerson，SHPerson 的分类 SHPerson(Home)，和继承自 SHPerson 的 SHTeacher。
 ```
 #pragma mark: - SHPerson
 @interface SHPerson : NSObject
 {
     NSString *_name;
     NSString *_age;
     NSObject *family;
 }
 @property (nonatomic, copy) NSString *nickname;
 @end
 @implementation SHPerson
 - (void)play_basketball {}
 + (void)playFootball {}
 @end

 #pragma mark: - SHPerson 的分类
 @interface SHPerson(Home)
 - (void)write_homework;
 + (void)eat;
 @end
 @implementation SHPerson(Home)
 - (void)write_homework {}
 + (void)eat {}
 @end

 #pragma mark: - SHTeacher
 @interface SHTeacher : SHPerson
 @property (nonatomic, strong) NSString *course;
 @end
 @implementation SHTeacher
 - (void)attend_class {}
 + (void)change_homework {}
 @end

 ```
 
 一、class_ro_t 存储的信息
 在 class_rw_t 中，有这么一这个方法：
 ```
 const class_ro_t *ro() const {
     auto v = get_ro_or_rwe();
     if (slowpath(v.is<class_rw_ext_t *>())) {
         return v.get<class_rw_ext_t *>(&ro_or_rw_ext)->ro;
     }
     return v.get<const class_ro_t *>(&ro_or_rw_ext);
 }
 ```
 通过 ro() 这个方法可以拿到 class_ro_t 的数据，我们来看一下。
 
 通过 lldb 打印出 class_ro_t 运行时在内存中的结构：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/class_ro_t的结构.png
 发现，class_ro_t 中是有 Flags，Size，Name，Methods，Protocols，Ivars，Properties 的成员变量，但是 baseProtocols 为nil，我们向 SHPreson 中添加协议，再运行看看。
 ```
 #pragma mark: - Protocol
 @protocol SHPersonProtocol<NSObject>
 - (void)run;
 - (void)sleep;
 + (void)work;
 @end

 #pragma mark: - SHPerson
 @interface SHPerson : NSObject<SHPersonProtocol>
 {
     NSString *_name;
     NSString *_age;
     NSObject *family;
 }
 @property (nonatomic, copy) NSString *nickname;
 @end
 @implementation SHPerson
 - (void)play_basketball {}
 + (void)playFootball {}

 /// SHPersonProtocol
 - (void)run {}
 - (void)sleep {}
 + (void)work {}
 @end

 ```
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/SHPerson添加协议之后的lldb打印.png
 
 我们看到，确实有值了,我们再来看一下源码中 class_ro_t 的结构，和 lldb 的打印一致。
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/源码中 class_ro_t 的结构.png
 
 ## 一、class_ro_t 的 ivars
    我们先来看一下class_ro_t 的 ivars 中都有什么：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/ivars lldb 打印.png
    确实有 SHPerson 中的四个成员变量，那如果我们在分类中添加属性或者成员变量，class_ro_t 的 ivars 和 baseProperties 是否也会存储呢？
 
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/分类中添加实例变量报错.png
    可以看到在分类中添加实例变量语法都不过，那我们只能添加属性了，但其实大概也能猜出来添加属性就算语法过了，class_ro_t 中也不会存储。先来验证一下吧。
 
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/分类添加属性的警告.png
    在分类中添加属性还要求添加相对应的 getter 和 setter。
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/height添加setter和gettew.png
 
    开始验证吧：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/分类中添加属性后ivars的打印.png
        
    没有 height 属性，我们的猜想正确！这也是分类中不能添加属性的原因，但如果想要添加属性，并且能正常使用，需要用到关联对象方法。
 
 ## 二、class_ro_t 的 baseMethodList
    那么，方法呢，是不是和 ivars 的存储的逻辑一样呢？我们来看一下：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/baseMethodList的类型.png
 
    我们发现 baseMethodList 是一个 void *const 的类型，还记得前面学过的，方法列表的类型吗？method_list_t，我们把 void *const 转成 method_list_t * 。然后通过前面所学的知识，打印出 method_list_t 中 get 返回的 method_t 的 big() 方法。
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/打印 big() 报错.png
    
    我们发现报错了，来看一下 big() 的实现：
    ```
     big &big() const {
         ASSERT(!isSmall());
         return *(struct big *)this;
     }
    ```
    再来看一下 baseMethodList 在源码中的注释：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/baseMethodList在源码中的注释.png
    大概的意思是： 如果它指向一个小列表，则这是有符号的，但是如果它指向一个大列表，则可能是无符号的。
 
    那既然 big() 不行，通过 name() 打印试试。
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/base MethodList打印 name() .png
    这个时候会发现，方法名称是打印出来了，但是会发现，baseMethodList 打印出了包括分类和协议中的所有实例方法！好像和 ivars 不太一样哦。
 
 ## 三、class_ro_t 的 baseProtocols
    既然如此，我们再来看一下 baseProtocols 中是否也有我们相对应的协议方法呢？
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/baseProtocols的结构打印.png
    
    这么一看好像看不出什么，我们来看下源码：
    ```
     struct protocol_list_t {
         // count is pointer-sized by accident.
         uintptr_t count;
         protocol_ref_t list[0]; // variable-size

         size_t byteSize() const {
             return sizeof(*this) + count*sizeof(list[0]);
         }

         protocol_list_t *duplicate() const {
             return (protocol_list_t *)memdup(this, this->byteSize());
         }

         typedef protocol_ref_t* iterator;
         typedef const protocol_ref_t* const_iterator;

         const_iterator begin() const {
             return list;
         }
         iterator begin() {
             return list;
         }
         const_iterator end() const {
             return list + count;
         }
         iterator end() {
             return list + count;
         }
     };
    ```
    源码中也看不出什么，但是这个 list 在源码中是 list[0]，我们把 list[0] 打印出来试试：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/list[0]的打印.png
    
    打印出来是这样的，我们再去看 protocol_ref_t 源码中是是什么一个结构：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/protocol_ref_t的定义.png
    
    我们发现，protocol_ref_t 后面有个注释，protocol_ref_t 是一个 protocol_t * 类型的，我们来看一下 protocol_t 在源码中的结构：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/protocol_t在源码中的结构.png
    
    我们看到了一些实例方法，类方法以及其它的信息，接下来通过 lldb 将 protocol_ref_t 强转成 protocol_t* 并打印出结构看看：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/protocol_t.png在lldb的打印.png
 
    完全有我们想要的东西，接下来就是一顿操作来验证：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/protocol_t实例方法和类方法的打印.png
 
    根据打印结果得知，baseProtocols 确实存在协议方法。
 
 ## 四、class_ro_t 的 baseProperties
    接着，我们来看一下 baseProperties 是否有属性相关的信息。
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/baseProperties打印.png
 
    不仅有 nickname 这个属性，还存有分类中的 height 属性和系统的其它属性。
 
 ## 五、firstSubclass
    关于为什么 firstSubclass 为 nil 的问题，通过一段 lldb 打印来看一下：
    /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/firstSubclass打印.png
    由此证明了就像 WWDC 中说一样，只有在使用的时候才会加载。
 
 ## 六、class_rw_ext_t
 为了验证 class_rw_ext_t 中是不是存着分类相关或者类扩展相关的东西，来看一下打印：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/class_rw_ext_t打印.png
 
 并没有分类相关的信息，那么类扩展呢？我们往代码里添加类扩展，再次重新运行并打印：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/04-类的成员变量和分类方法的存储/类的成员变量和分类方法的存储/SHPerson添加类扩展.png
 
 还是什么都没有。
 
 ## 七、总结
 class_rw_t 存储着类的实例方法，协议方法，属性相关的信息
 class_ro_t 存储着 Flags(一些其它的数据，比如引用计数相关的)，类的大小，类的名称，类的实例方法列表，协议方法列表，成员变量以及属性相关的信息。
 
 */
