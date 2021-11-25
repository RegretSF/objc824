////
////  main.m
////  cache_t分析
////
////  Created by TT-Fangss on 2021/11/23.
////
//
#import <Foundation/Foundation.h>
#import "sh_objc_class.h"
#import "SHPerson.h"

// 打印
void print_sel_and_imp(struct sh_objc_class *class) {
    NSLog(@"_occupied: %hu - _maybeMask: %u",class->cache._occupied, class->cache._maybeMask);

    for (int i = 0; i < (int)class->cache._maybeMask; i++) {
        struct sh_bucket_t bucket = class->cache._buckets[i];
        NSLog(@"sel: %@ - imp: %p",NSStringFromSelector(bucket._sel),bucket._imp);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        SHPerson *p = [SHPerson alloc];
        NSLog(@"%@", p);
        
        
        
        
        
        
        
        
        struct sh_objc_class *p_class = (__bridge struct sh_objc_class *)([SHPerson class]);
        print_sel_and_imp(p_class);

        [p play_basketball];
        [p play_football];
        print_sel_and_imp(p_class);
        
        [p play_badminton];
        [p play_table_tennis];
        print_sel_and_imp(p_class);
        
        NSLog(@"%@", p);
        NSLog(@"Hello, World!");
    }
    return 0;
}

/**
 cache_t
 
 在分析类的结构时我们知道类中有 cache_t cache 这个成员变量，通过名称我们大概能猜到是缓存，但是缓存什么呢？
 来看一下源码中 cache_t 的结构：
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/cache_t源码结构.png
 
 它有5个成员变量，分别为 _bucketsAndMaybeMask，_maybeMask，_flags，_occupied，_originalPreoptCache，虽然有5个，但内存中不是有5个的，它有一个 union，union 的特性是互斥，所以其实在下面的探索中 _originalPreoptCache 可以先不管。另外 _flags 是其它一些数据，也可以先不管。
 所以在这几个成员变量中，我们只关注 _bucketsAndMaybeMask，_maybeMask，_occupied 这三个。
 
 ## 一、_bucketsAndMaybeMask 和 _maybeMask
 /Users/tt-fangss/Fangss/TmpeCode/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/_bucketsAndMaybeMask和_maybeMask的注释.png
 
 在不同的环境的编译下，_bucketsAndMaybeMask 和 _maybeMask 的注释不一样。
 当 CACHE_MASK_STORAGE 为 CACHE_MASK_STORAGE_OUTLINED 的时候，_bucketsAndMaybeMask 是一个 buckets_t 指针，_maybeMask 是 buckets 掩码。
 当 CACHE_MASK_STORAGE 为 CACHE_MASK_STORAGE_HIGH_16 的时候，_bucketsAndMaybeMask 是低 48 位的 buckets_t 指针，_maybeMask 未使用，掩码存储在前 16 位。
 
 那么，CACHE_MASK_STORAGE 是什么？来看一下它的定义：
 ```
 #define CACHE_MASK_STORAGE_OUTLINED 1
 #define CACHE_MASK_STORAGE_HIGH_16 2
 #define CACHE_MASK_STORAGE_LOW_4 3
 #define CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS 4

 #if defined(__arm64__) && __LP64__
 #if TARGET_OS_OSX || TARGET_OS_SIMULATOR       // macOS、模拟器
 #define CACHE_MASK_STORAGE CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS
 #else
 #define CACHE_MASK_STORAGE CACHE_MASK_STORAGE_HIGH_16  // 真机
 #endif
 #elif defined(__arm64__) && !__LP64__
 #define CACHE_MASK_STORAGE CACHE_MASK_STORAGE_LOW_4
 #else
 #define CACHE_MASK_STORAGE CACHE_MASK_STORAGE_OUTLINED
 #endif
 ```
 所以，当 CACHE_MASK_STORAGE 为 CACHE_MASK_STORAGE_OUTLINED 的时候是 macOS 和模拟器，为 CACHE_MASK_STORAGE_HIGH_16 的时候是真机。
 
 ## 二、bucket_t 分析
 通过分析 _bucketsAndMaybeMask 和 _maybeMask ，我们知道了 _bucketsAndMaybeMask 是一个指向 bucket_t 的指针，bucket 翻译过来是‘桶’的意思，而苹果的注释是 buckets，个人理解应该就是很多桶的意思，后面的 _t 表示是结构体的意思。
 那么 bucket_t 是什么呢？，我们来看一下源码：
 ```
 struct bucket_t {
 private:
     // IMP-first is better for arm64e ptrauth and no worse for arm64.
     // SEL-first is better for armv7* and i386 and x86_64.
 #if __arm64__
     explicit_atomic<uintptr_t> _imp;
     explicit_atomic<SEL> _sel;
 #else
     explicit_atomic<SEL> _sel;
     explicit_atomic<uintptr_t> _imp;
 #endif

     // Compute the ptrauth signing modifier from &_imp, newSel, and cls.
     uintptr_t modifierForSEL(bucket_t *base, SEL newSel, Class cls) const {
         return (uintptr_t)base ^ (uintptr_t)newSel ^ (uintptr_t)cls;
     }

     // Sign newImp, with &_imp, newSel, and cls as modifiers.
     uintptr_t encodeImp(UNUSED_WITHOUT_PTRAUTH bucket_t *base, IMP newImp, UNUSED_WITHOUT_PTRAUTH SEL newSel, Class cls) const {
         if (!newImp) return 0;
 #if CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_PTRAUTH
         return (uintptr_t)
             ptrauth_auth_and_resign(newImp,
                                     ptrauth_key_function_pointer, 0,
                                     ptrauth_key_process_dependent_code,
                                     modifierForSEL(base, newSel, cls));
 #elif CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_ISA_XOR
         return (uintptr_t)newImp ^ (uintptr_t)cls;
 #elif CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_NONE
         return (uintptr_t)newImp;
 #else
 #error Unknown method cache IMP encoding.
 #endif
     }

 public:
     static inline size_t offsetOfSel() { return offsetof(bucket_t, _sel); }
     inline SEL sel() const { return _sel.load(memory_order_relaxed); }

 #if CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_ISA_XOR
 #define MAYBE_UNUSED_ISA
 #else
 #define MAYBE_UNUSED_ISA __attribute__((unused))
 #endif
     inline IMP rawImp(MAYBE_UNUSED_ISA objc_class *cls) const {
         uintptr_t imp = _imp.load(memory_order_relaxed);
         if (!imp) return nil;
 #if CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_PTRAUTH
 #elif CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_ISA_XOR
         imp ^= (uintptr_t)cls;
 #elif CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_NONE
 #else
 #error Unknown method cache IMP encoding.
 #endif
         return (IMP)imp;
     }

     inline IMP imp(UNUSED_WITHOUT_PTRAUTH bucket_t *base, Class cls) const {
         uintptr_t imp = _imp.load(memory_order_relaxed);
         if (!imp) return nil;
 #if CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_PTRAUTH
         SEL sel = _sel.load(memory_order_relaxed);
         return (IMP)
             ptrauth_auth_and_resign((const void *)imp,
                                     ptrauth_key_process_dependent_code,
                                     modifierForSEL(base, sel, cls),
                                     ptrauth_key_function_pointer, 0);
 #elif CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_ISA_XOR
         return (IMP)(imp ^ (uintptr_t)cls);
 #elif CACHE_IMP_ENCODING == CACHE_IMP_ENCODING_NONE
         return (IMP)imp;
 #else
 #error Unknown method cache IMP encoding.
 #endif
     }

     inline void scribbleIMP(uintptr_t value) {
         _imp.store(value, memory_order_relaxed);
     }

     template <Atomicity, IMPEncoding>
     void set(bucket_t *base, SEL newSel, IMP newImp, Class cls);
 };
 ```
 
 源码很长，但我们发现，bucket_t 中有 _imp 和 _sel 两个成员变量，并且，还有 sel，rawImp，imp方法。所以 bucket_t 存放着方法的 IMP(方法地址) 和 SEL(方法编号) ,并且我们可以通过 sel 方法和 imp 方法拿到对应的 IMP 和 SEL。
 这个时候我们知道 cache_t 是用来缓存方法的，bucket_t 存的是 IMP 和 SEL 相关的，假如我们要存放很多个方法呢？一个 bucket_t 只能存放一个 IMP 和一个 SEL，那怎么能存放更多的方法呢？
 在 cache_t 中有这么一个方法：
 ```
 struct bucket_t *buckets() const;
 ```
 
 这个方法是获取所有的缓存中的 bucket_t，可它是一个结构体指针，怎么回事呢？还记得我们前面讲到的内存平移的么，接下来我们通过llbd的方式进行内存平移，拿到 SEL 和 IMP 。
 
 ## 三、lldb 获取 cache_t 中缓存的 SEL 和 IMP
 先定义一个 SHPerson 对象，并添加方法。
 ```
 @interface SHPerson : NSObject
 - (void)play_basketball;
 - (void)play_football;
 - (void)play_badminton;
 - (void)play_volleyball;
 - (void)play_table_tennis;
 @end
 
 @implementation SHPerson
 - (void)play_basketball {
     NSLog(@"%s", __func__);
 }

 - (void)play_football {
     NSLog(@"%s", __func__);
 }

 - (void)play_badminton {
     NSLog(@"%s", __func__);
 }

 - (void)play_volleyball {
     NSLog(@"%s", __func__);
 }

 - (void)play_table_tennis {
     NSLog(@"%s", __func__);
 }
 @end
 ```
 
 接下来我们 alloc 一下，并且打个断点，打印出 cache_t 的结构，再调用 buckets() 拿到 bucket_t*。这里需要注意的是先不要 init，减少不必要的干扰。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/cache_t在内存中的结构.png

 我们发现 bucket_t 的 _sel 等于 nil，_imp 等于 0，并且 _maybeMask 和 _occupied 的值都为0，会不会是我们没有调用方法的原因呢？
 接下来我们调用 play_basketball 方法，再取 bucket_t* 试试。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/调用方法后再次打印 bucket_t 的内存.png
 
 首先 bucket_t * 的内存地址由 0x00000001003623d0 变成了 0x000000010175ef30，其次 _sel 和 _imp 都有值了，接下来调用 imp 方法打印出 _imp 的值，看看是否是我们调用后的 play_basketball 方法。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/$6.imp($5,[SHPerson class]) 打印.png
 
 成功的打印出 play_basketball 方法，那么我们再调用 play_football 方法。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/调用 play_football后打印 imp.png
 
 我们看到再次打印 bucket_t的 imp 没有变化，然后想到了内存平移，但 p *($9+1) 打印出的 bucket_t 并不是我们想象的 play_football 方法，而是一个 class 的系统方法，那我们再平移，p *($9+2)，打印的才是我们的 play_football 方法。
 到这里我们知道，bucket_t* 缓存的方法并不是按顺序进行存储的吧。
 
 ## 四、验证 _bucketsAndMaybeMask 是否是 bucket_t 指针
 还记得第一点里源码分析 _bucketsAndMaybeMask 吗？，_bucketsAndMaybeMask 是 bucket_t 指针，我们重新运行，来验证一下。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t分析/_bucketsAndMaybeMask验证.png
 
 我们发现，_bucketsAndMaybeMask 的地址和 bucket_t* 内存地址一摸一样，由此可见，_bucketsAndMaybeMask 存放的确实是 bucket_t 指针，并且，是 bucket_t* 的首地址，因为我们还可以通过内存平移拿到别的方法。
 另外 _occupied 和 _maybeMask 有值了，我们知道 _maybeMask 是一个掩码，那么 _occupied 是什么呢？方法是如何插入到 bucket_t* 的呢？我们来继续探索下一个内容。

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 但从性能的角度上思考，这个 bucket_t* 不一定是通过内存平移按顺序存储方法的，那么它是怎么存到 bucket_t* 的呢？
 在 cache_t 中有这么一个方法：
 ```
 // 第一个参数：传一个 SEL(方法编号)
 // 第二个参数：传一个 IMP(方法地址)
 // 第三个参数：传一个 id 对象，接收者
 void insert(SEL sel, IMP imp, id receiver);
 ```
 
 */


























