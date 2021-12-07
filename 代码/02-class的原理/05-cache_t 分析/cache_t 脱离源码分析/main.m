//
//  main.m
//  cache_t 脱离源码分析
//
//  Created by Fat brother on 2021/11/25.
//

#import <Foundation/Foundation.h>
#import "sh_objc_class.h"
#import "SHPerson.h"
#import <objc/runtime.h>



/*
 脱离源码分析 cache_t
 ## 一、自定义 objc_class 打印 cache
 接下来我们不通过 lldb 的打印去打印 cache_t 的值，直接通过 NSLog 方法打印。那么就需要模仿源码，自己也搞个 cache_t, 自己也搞个 objc_class，请看下面的代码。
 ```
 typedef uint32_t mask_t;  // x86_64 & arm64 asm are less efficient with 16-bits

 struct sh_bucket_t {
     SEL _sel;
     IMP _imp;
 };

 struct sh_cache_t {
     struct sh_bucket_t *_buckets;
     
     mask_t    _maybeMask;
     
     uint16_t _flags;
     uint16_t _occupied;
 };

 struct sh_class_data_bits_t {
     uintptr_t bits;
 };

 struct sh_objc_class {
     Class isa;
     Class superclass;
     struct sh_cache_t cache;
     struct sh_class_data_bits_t bits;
 };
 ```
 这里需要注意的是，sh_bucket_t 的 _imp 和 _sel 定义的顺序一定不能错！以下是 bucket_t 的源码实现，当为 arm64 架构的时候 _imp 是在结构体的第一个位置，否则是 _sel 在第一个位置。当我们用 M1 系列的电脑或者真机调试的时候走的是 arm64，我的电脑是 intel 的，所以是 _sel 在第一个位置。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t 脱离源码分析/bucket_t的细节.png
 
 
 定义一个 SHPerson 对象，并添加方法。
 ```
 @interface SHPerson : NSObject
 - (void)play1;
 - (void)play2;
 - (void)play3;
 - (void)play4;
 @end
 
 @implementation SHPerson
 - (void)play1 {
     NSLog(@"%s", __func__);
 }

 - (void)play2 {
     NSLog(@"%s", __func__);
 }

 - (void)play3 {
     NSLog(@"%s", __func__);
 }

 - (void)play4 {
     NSLog(@"%s", __func__);
 }
 @end
 ```
 
 我们还需要一个打印的方法，打印出 _occupied 和 _maybeMask 的变化，并且把 bucket_t*(_bucketsAndMaybeMask) 的所有 bucket_t 打印出来。
 来看打印方法的实现：
 ```
 void print_sel_and_imp(struct sh_objc_class *class) {
     NSLog(@"_occupied: %hu - _maybeMask: %u",class->cache._occupied, class->cache._maybeMask);
     for (mask_t i = 0; i < class->cache._maybeMask; i++) {
         struct sh_bucket_t bucket = class->cache._buckets[i];
         NSLog(@"sel: %@ - imp: %p",NSStringFromSelector(bucket._sel), bucket._imp);
     }
 }

 ```
 
 分三个部分，1：没调用方法的打印。2：调用部分方法的打印。3：调用全部方法的打印。
 ```
 int main(int argc, const char * argv[]) {
     @autoreleasepool {
         // insert code here...
         SHPerson *p = [SHPerson alloc];
         
         struct sh_objc_class *p_class = (__bridge struct sh_objc_class *)([SHPerson class]);
         print_sel_and_imp(p_class);

         [p play1];
         [p play2];
         print_sel_and_imp(p_class);
         
         [p play3];
         [p play4];
         print_sel_and_imp(p_class);
         
         NSLog(@"Hello, World!");
     }
     return 0;
 }
 ```
 
 我们来看一下打印结果：
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t 脱离源码分析/打印结果.png
 
 我们抛出几个疑问：
 1. _maybeMask 这个掩码具体是什么？为什么从 0-3-7
 2、_occupied 是什么？0-2-2
 3.bucket数据为什么会有丢失的情况？原来缓存的 play1 和 play2 去哪儿了。
 4.为什么缓存的方法是无序的？
 
 注意：M1 芯片的 Mac 电脑是拿不到 _maybeMask 的，并且在 M1 芯片的电脑同以上的方式强行取 _buckets 的值是不正常的。以上的脱离源码的打印，只是为了抛出上面四个疑问，所以在用 M1 芯片的电脑操作到这里的时候，不要纠结这个 _maybeMask。
 
 ## 二、insert(SEL sel, IMP imp, id receiver) 分析
 ```
 // 第一个参数：传一个 SEL(方法编号)
 // 第二个参数：传一个 IMP(方法地址)
 // 第三个参数：传一个 id 对象，接收者
 void insert(SEL sel, IMP imp, id receiver);
 ```
 我们在 cache_t 中找到了 insert 这个方法，很明显，这个是在进行缓存的时候，将方法插入 _buckets 的方法。我们来看一下它的实现，并且，我在源码中添加的相关的注释，方便阅读。
 ```
 void cache_t::insert(SEL sel, IMP imp, id receiver)
 {
     runtimeLock.assertLocked();

     // Never cache before +initialize is done
     if (slowpath(!cls()->isInitialized())) {
         return;
     }

     if (isConstantOptimizedCache()) {
         _objc_fatal("cache_t::insert() called with a preoptimized cache for %s",
                     cls()->nameForLogging());
     }

 #if DEBUG_TASK_THREADS
     return _collecting_in_critical();
 #else
 #if CONFIG_USE_CACHE_LOCK
     mutex_locker_t lock(cacheUpdateLock);
 #endif

     ASSERT(sel != 0 && cls()->isInitialized());

     // Use the cache as-is if until we exceed our expected fill ratio.
     // 1.计算出当前的缓存占用量
     // 没有属性赋值的情况下 occupied() == 0, newOccupied == 1。
     mask_t newOccupied = occupied() + 1;
     unsigned oldCapacity = capacity(), capacity = oldCapacity;
     
     // 2.根据缓存占用量判断执行的操作
     // 2.1 初始化创建
     if (slowpath(isConstantEmptyCache())) {
         // 小概率发生的，即当 occupied() == 0时，创建缓存，创建属于小概率事件
         
         // Cache is read-only. Replace it.
         // 初始化时，capacity == 4(1 << 2)。
         if (!capacity) capacity = INIT_CACHE_SIZE;
         // 开辟空间
         reallocate(oldCapacity, capacity, /false);
     }
     else if (fastpath(newOccupied + CACHE_END_MARKER <= cache_fill_ratio(capacity))) {
         // Cache is less than 3/4 or 7/8 full. Use it as-is.
         
         // 2.2
         // 如果小于等于占用内存的 3/4 或者满 7/8 就什么都不做。
         // 第一次时，申请开辟的内存是4个，如果此时已经有3个从 bucket 插入到 cache 里面，再插入一个就是 4 个。
         // 当大于 4(当前下标为4)，就越界了，所以要在原来的容量上进行两倍扩容。
     }
 #if CACHE_ALLOW_FULL_UTILIZATION
     else if (capacity <= FULL_UTILIZATION_CACHE_SIZE && newOccupied + CACHE_END_MARKER <= capacity) {
         // Allow 100% cache utilization for small buckets. Use it as-is.
     }
 #endif
     // 2.3
     else {  // 如果超出 3/4，进行两倍扩容
         capacity = capacity ? capacity * 2 : INIT_CACHE_SIZE;
         if (capacity > MAX_CACHE_SIZE) {
             capacity = MAX_CACHE_SIZE;
         }
         // 走到这里表示曾经有，但是已满了，需要重新梳理
         reallocate(oldCapacity, capacity, true);
     }

     // 3. 针对需要存储的bucket进行内部imp和sel赋值
     bucket_t *b = buckets();
     mask_t m = capacity - 1;    // mask = capacity - 1
     // 3.1 求 cache 哈希，即哈希下标---通过哈希算法函数计算 sel 存储的下标。
     mask_t begin = cache_hash(sel, m);
     mask_t i = begin;

     // Scan for the first unused slot and insert there.
     // There is guaranteed to be an empty slot.
     // 3.2 如果存在哈希冲突，则从冲突的下标开始遍历 do-while
     do {
         // 3.3 第一个插槽未使用，将 bucket 插入第一个插槽。
         // 即遍历的下标拿不到 sel，表示当前没有存储 bucket，可以在第一个插槽存储。
         if (fastpath(b[i].sel() == 0)) {
             // _occupied++;
             incrementOccupied();
             // 将 bucket 插入
             b[i].set<Atomic, Encoded>(b, sel, imp, cls());
             return;
         }
         
         // 3.4 如果将要插入的卡槽中存有 sel 并且等于要插入的 sel，直接返回
         if (b[i].sel() == sel) {
             // The entry was added to the cache by some other thread
             // before we grabbed the cacheUpdateLock.
             return;
         }
         
         // 3.5 如果当前下标有 sel，且和准备插入的 sel不相等，需要重新进行哈希计算，得到新下标，遍历。
     } while (fastpath((i = cache_next(i, m)) != begin));

     bad_cache(receiver, (SEL)sel);
 #endif // !DEBUG_TASK_THREADS
 }
 ```
 
 前面一些锁的处理和一些相关的判断我们可以忽略掉，insert 方法主要分三步：
 1. 计算出当前的缓存占用量
 没有属性赋值的情况下 occupied() == 0, newOccupied == 1。
 
 2. 根据缓存占用量判断执行的操作
 2.1 初始化创建
 小概率发生的，即当 occupied() == 0时，创建缓存，创建属于小概率事件，初始化时，capacity == 4(1 << 2)。
 
 2.2 是否需要扩容
 如果小于等于占用内存的 3/4 或者满 7/8 就什么都不做。第一次时，申请开辟的内存是4个，如果此时已经有3个从 bucket 插入到 cache 里面，再插入一个就是 4 个，当大于 4(当前下标为4)，就越界了，所以要在原来的容量上进行两倍扩容。
 走到 reallocate 方法表示曾经有，但是已满了，需要重新梳理。
 
 3. 针对需要存储的bucket进行内部imp和sel赋值
 3.1 求 cache 哈希，即哈希下标---通过哈希算法函数计算 sel 存储的下标。
 3.2 如果存在哈希冲突，则从冲突的下标开始遍历 do-while
 第一个插槽未使用，将 bucket 插入第一个插槽。即遍历的下标拿不到 sel，表示当前没有存储 bucket，可以在第一个插槽存储。这个时候 _occupied++。
 如果将要插入的卡槽中存有 sel 并且等于要插入的 sel，直接返回。
 如果当前下标有 sel，且和准备插入的 sel不相等，需要重新进行哈希计算，得到新下标，遍历。
 
 根据第3点提到的哈希算法和哈希冲突，我们来看一下源码如何实现的：
 ```
 static inline mask_t cache_hash(SEL sel, mask_t mask)
 {
     uintptr_t value = (uintptr_t)sel;
 #if CONFIG_USE_PREOPT_CACHES
     // 如果使用缓存
     value ^= value >> 7;
 #endif
     // 通过 sel & mask(),即 _maybeMask = capacity - 1
     return (mask_t)(value & mask);
 }

 ```
 
 ```
 #if CACHE_END_MARKER
 static inline mask_t cache_next(mask_t i, mask_t mask) {
     // （将当前的哈希下标 + 1）& mask，重新进行哈希计算，得到一个新的下标。
     return (i+1) & mask;
 }
 #elif __arm64__
 static inline mask_t cache_next(mask_t i, mask_t mask) {
     // 如果 i 是 null，则等于 mask（mask = capacity - 1），否则向前一个下标（i-1）。
     return i ? i-1 : mask;
 }
 #else
 #error unexpected configuration
 #endif
 ```
 
 ## 三、reallocate 分析
 我们来看一下源码的实现和添加的注释。
 ```
 void cache_t::reallocate(mask_t oldCapacity, mask_t newCapacity, bool freeOld)
 {
     // 取出旧的 buckets
     bucket_t *oldBuckets = buckets();
     // 开辟一个新的 buckets
     bucket_t *newBuckets = allocateBuckets(newCapacity);

     // Cache's old contents are not propagated.
     // This is thought to save cache memory at the cost of extra cache fills.
     // fixme re-measure this

     ASSERT(newCapacity > 0);
     ASSERT((uintptr_t)(mask_t)(newCapacity-1) == newCapacity-1);

     // 将 buckets 存入缓存中
     setBucketsAndMask(newBuckets, newCapacity - 1);
     
     // 如果有旧的 buckets，进行清除处理
     if (freeOld) {
         collect_free(oldBuckets, oldCapacity);
     }
 }
 ```
 
 1. 取出旧的 buckets 并开辟一个新的 buckets（allocateBuckets）。
 
 2. 将新的 buckets 存储缓存中。（调用setBucketsAndMask 方法）。架构的不同，缓存的处理也不一样，具体可看源码。
 
 3. 如果有旧的 buckets，进行清除相关的处理。（调用 collect_free方法）。
 3.1 创建垃圾回收空间（_garbage_make_room）。
 3.2 垃圾回收，清理旧的 buckets（collectNolock）。
 
 四、解答 NSLog 打印 cache_t 后的疑问点。
 1. _maybeMask 这个掩码具体是什么？为什么从 0-3-7
 _maybeMask 是一个掩码，用于哈希算法取下标（cache_hash）和哈希冲突取下标（cache_next）中的计算需要，并且 _maybeMask 的值等于 capacity - 1。
 cache_hash：sel & _maybeMask 取得下标。
 cache_next：根据架构的不同做处理，arm64 的时候：如果 i 是 null，则等于 mask（mask = capacity - 1），否则向前一个下标（i-1）。arm64 以外的架构的时候：（当前下标 + 1）& mask，重新进行哈希计算，得到一个新的下标。
 
 2、_occupied 是什么？0-2-2
 _occupied 表示 buckets 中 sel-imp 占用的大小，还记得在 NSLog 打印的时候，只有 play1 和 play2 的时候，_occupied 等于 2。只有 play3 和 play4 的时候，_occupied 等于 2。所以可以理解为，_occupied 表示 buckets 中，包含 sel-imp 的 bucket_t 的个数。
 
 3.buckets 数据为什么会有丢失的情况？原来缓存的 play1 和 play2 去哪儿了。
 原来的 buckets 数据丢失是因为当超出 3/4 的容量时，需要进行扩容，而扩容时，会新开辟一个 buckets，并且把原来的 buckets 进行回收清除处理。
 
 4.为什么缓存的方法是无序的？
 其实了解到 _maybeMask 具体是什么就知道了为什么缓存的方法是无序的了，因为需要通过哈希算法算法取出的下标拿到的 bucket_t 可能含有不等于将要存储的 sel-imp，所以进行了哈希冲突处理，哈希冲突将产生冲突的下标进行 （sel & _maybeMask）或者（当前下标 + 1）& mask，具体根据架构来采取。
 
 5. 为什么是在 3/4 时进行扩容
 这个问题是一个扩展，在哈希这种数据结构里面，有一个概念用来表示空位的多少叫做装载因子——装载因子越大，说明空闲位置越少，冲突越多，散列表的性能会下降负载因子是3/4的时候，空间利用率比较高，而且避免了相当多的Hash冲突，提升了空间效率，具体可以阅读HashMap的负载因子为什么默认是0.75（https://baijiahao.baidu.com/s?id=1656137152537394906&wfr=spider&for=pc）？
 
 另外，缓存的主要目的就是通过一系列策略让编译器更快的执行消息发送的逻辑。
 
 */

// 打印
void print_sel_and_imp(struct sh_objc_class *class) {
    NSLog(@"_occupied: %hu - _maybeMask: %u",class->cache._occupied, class->cache._maybeMask);
    for (mask_t i = 0; i < class->cache._maybeMask; i++) {
        struct sh_bucket_t bucket = class->cache._buckets[i];
        NSLog(@"sel: %@ - imp: %p",NSStringFromSelector(bucket._sel), bucket._imp);
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        SHPerson *p = [SHPerson alloc];
        
        struct sh_objc_class *p_class = (__bridge struct sh_objc_class *)([SHPerson class]);
        print_sel_and_imp(p_class);

        [p play1];
        [p play2];
        print_sel_and_imp(p_class);
        
        [p play3];
        [p play4];
        print_sel_and_imp(p_class);
        
        NSLog(@"Hello, World!");
    }
    return 0;
}

/*
 # objc-cache.mm 的注解翻译。
 
 分析完了 cache_t 我们来看一下 cache _t 的 objc-cache.mm 的实现文件中，最顶部的注释，并且将这些注释翻译一下。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/05-cache_t 分析/cache_t 脱离源码分析/objc_cache.mm 的 注解.png

 objc-cache.mm 的实现功能
 * 方法缓存管理
 * 缓存刷新
 * 缓存垃圾收集
 * 缓存检测
 * 大缓存专用分配器
 
 ## 一、方法缓存锁定
 * 为了速度，objc_msgSend 读取时不获取任何锁方法缓存。相反，会执行所有缓存更改，以便任何objc_msgSend 与缓存修改器同时运行不会崩溃、挂起或从缓存中获得不正确的结果。
 * 当缓存内存未使用时（例如缓存后的旧缓存扩展），它不会立即释放，因为并发的objc_msgSend可能仍在使用它。相反，内存与数据结构断开连接并放置在垃圾列表中。
 * 内存现在只能被内存断开时正在运行的 objc_msgSend 实例访问；任何对 objc_msgSend 的进一步调用都不会看到垃圾内存，因为其他数据结构不再指向它。
 * collect_in_critical 函数检查所有线程的 PC，当发现所有线程都在 objc_msgSend 之外时返回 FALSE。这意味着任何可以访问垃圾的 objc_msgSend 调用都已完成或移动到缓存查找阶段，因此释放内存是安全的。
 * 所有修改缓存数据或结构的函数都必须获取 cacheUpdateLock 以防止并发修改的干扰。释放缓存垃圾的函数必须获取cacheUpdateLock 并使用collection_in_critical() 来刷新缓存读取器。
 * cacheUpdateLock 还用于保护用于大型方法缓存块的自定义分配器。
 
 ## 二、读取缓存（通过collection_in_critical() 进行PC 检查）
 objc_msgSend
 cache_getImp
 
 ## 三、读/写缓存（在访问期间保持 cacheUpdateLock ；未通过 PC 检查）
 * cache_t::copyCacheNolock (调用者必须持有锁)
 * cache_t::eraseNolock (调用者必须持有锁)
 * cache_t::collectNolock (调用者必须持有锁)
 * cache_t::insert（获取锁）
 * cache_t::destroy（获取锁）
 
 ## 四、 UNPROTECTED 读取缓存（线程不安全；仅用于调试信息）
 * cache_print
 * _class_printMethodCaches
 * _class_printDuplicateCacheEntries
 * _class_printMethodCacheStatistics
 
 看了苹果官方的注解，大概明白了，底层在进行方法的缓存、读取的时候，用到一个很重要的方法：objc_msgSend。并且，我们 insert 之前会调用 cache_getImp检查有没有缓存。
 */
