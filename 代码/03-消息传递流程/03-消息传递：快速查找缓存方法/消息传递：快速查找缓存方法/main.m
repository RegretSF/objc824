//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>

/*
 在 Class 结构中，我们已经知道 cache_t 是缓存类的方法，并且已经知道了它的 insert 方法流程。objc_msgSend 的汇编流程，在最后会调用 CacheLookup 方法，通过名字猜得到，这是一个缓存查找方法。
 
 CacheLookup 方法找的是类中的 cache_t 的缓存方法，我们来看一下在 objc_msgSend 中的调用：
 ```swift
 CacheLookup NORMAL, _objc_msgSend, __objc_msgSend_uncached
 ```
 
 再来看一下 CacheLookup 的实现：
 ```swift
 .macro CacheLookup Mode, Function, MissLabelDynamic, MissLabelConstant
 ```
 
 在汇编中，‘.macro’ 代表宏定义。CacheLookup 是一个宏定义实现，它有四个参数，分别为 Mode，Function，MissLabelDynamic，MissLabelConstant。
 Mode：对应 objc_msgSend 调用中传的 NORMAL。
 Function：对应 objc_msgSend 调用中传的 _objc_msgSend。
 MissLabelDynamic：对应 objc_msgSend 调用中传的 __objc_msgSend_uncached。
 MissLabelConstant：这个参数没有传代表有默认值。
 
 首先注意一点，在开始执行这个方法时，代码中有段注释：
 ```swift
 //   NORMAL and LOOKUP:
 //   - x0 contains the receiver
 //   - x1 contains the selector
 //   - x16 contains the isa
 //   - other registers are set as per calling conventions
 ```
 p0 是传过来的消息接收者，p1 是传过来的 sel，p16 是传过来的 isa(类对象的地址)，这点需要达成共识。
 
 先来看第一段 CacheLookup 汇编实现的代码：
 ```swift
 #if CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS
 
 // - p1 = SEL, p16 = isa --- #define CACHE (2 * __SIZEOF_POINTER__)，其中 __SIZEOF_POINTER__表示pointer的大小 ，即 2*8 = 16。
 // - p10 = mask|buckets -- 从 x16（即isa）中平移16字节，取出 cache 存入p10
 // - isa 距离 cache 正好16字节：isa（8字节）- superClass（8字节）- cache（mask 高16位 + buckets 低48位）
 ldr    p10, [x16, #CACHE]                // p10 = mask|buckets
 lsr    p11, p10, #48            // p11 = mask
 and    p10, p10, #0xffffffffffff    // p10 = buckets
 and    w12, w1, w11            // x12 = _cmd & mask
 ```
 * 这一段代码在通过内存平移的方式，取出 cache，存入 p10。
 * p10 右移 48 位，取出 mask，并赋值给 p11。
 * p10 & #0xffffffffffff，取出 buckets 并存入 p10。
 
 但真机并不是走这里，这里贴出来只是为了方便下面的理解，真机中走的是下面这一段：
 ```swift
 // - 64位真机
 #elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16
 // - p11 = mask|buckets = cache
     ldr    p11, [x16, #CACHE]            // p11 = mask|buckets
     #if CONFIG_USE_PREOPT_CACHES
         #if __has_feature(ptrauth_calls)
     tbnz    p11, #0, LLookupPreopt\Function
 //  - p11(cache) & 0x0000ffffffffffff ，mask高16位抹零，得到 buckets 存入p10 -- 即去掉mask，留下buckets。
     and    p10, p11, #0x0000ffffffffffff    // p10 = buckets
         #else
     and    p10, p11, #0x0000fffffffffffe    // p10 = buckets
     tbnz    p11, #0, LLookupPreopt\Function
     #endif
     eor    p12, p1, p1, LSR #7
     and    p12, p12, p11, LSR #48        // x12 = (_cmd ^ (_cmd >> 7)) & mask
     #else
     and    p10, p11, #0x0000ffffffffffff    // p10 = buckets
 // - p11(cache)右移48位，得到 mask（即 p11 存储 mask），mask & p1(msgSend的第二个参数 cmd)
 // - 得到 sel 的下标 index（即搜索下标），存入p12。
 // - cache insert 时的哈希下标计算是 通过 sel & mask，读取时也需要通过这种方式，objc-cache.mm 文件的 cache_hash 函数。
     and    p12, p1, p11, LSR #48        // x12 = _cmd & mask
 ```
 
 同样的，取出 cache 存入 p11。
 p11 & #0x0000ffffffffffff 拿到 buckets 赋值给 p10。
 p11 右移 48 位，拿到 mask，mask & p1 得到下标，存入 p12。
 为什么 mask & p1 就能得到下标，还记得那个 insert 函数中用到的哈希算法取的下标吗，里面的实现和这一步一样的，所以 mask & p1 拿到的就是当前 p1 对应 bucket 的下标。
 
 这个时候，p10 是 buckets 的第一个 bucket，p11 是 mask，p12 是下标。
 拿到 index 和 buckets 之后，就开始，通过 index 取出 buckets 的 bucket，看看缓存中是否有当前要找的 sel。
 汇编代码如下：
 ```swift
 // 注意：LSL 指令代表左移，p12 是下标，(1+PTRSHIFT) 等于4。那么 p12, LSL #(1+PTRSHIFT) 相当于：下标左移4位(index << 4)
 // add 指令代表相加，p10 是 buckets 的首地址，整句代码的意思是：p10 + 当前下标左移4位后的值存入 p13。
 // sel 和 imp 占 8 字节，所以一个 bucket 占用 16 个字节。
 // 那么 index << 4 中，index 代表从 buckets 的第一个下标到 index 的 bucket 的个数，左移 4 位代表一个 bucket 占 16 字节。
 // 总体来说 index << 4 就是 index 个 16，这个时候 p13 等于 buckets 首地址平移 index 个 16 位后拿到的 bucket。
     add    p13, p10, p12, LSL #(1+PTRSHIFT)
                         // p13 = buckets + ((_cmd & mask) << (1+PTRSHIFT))，PTRSHIFT等于3

 // - 以下是 do while 循环，从 p13 开始往前遍历，如果 p13 前面的所以 bucket 找不到要查找的 sel，退出循环，继续往下走
                         // do {
 // - 取出 bucket，并把 bucket 的 imp 赋值给 p17，sel 赋值给p9
 1:    ldp    p17, p9, [x13], #-BUCKET_SIZE    //     {imp, sel} = *bucket--
 // - 判断 p1(sel) 是否等于 p9(bucket 的 sel)
     cmp    p9, p1                //     if (sel != _cmd) {
 // - 如果不相等，跳转至 3f
     b.ne    3f                //         scan more
                         //     } else {
 // - 如果相等 即 CacheHit 缓存命中，直接返回imp
 2:    CacheHit \Mode                // hit:    call or return imp
                         //     }
 // - 在 _objc_msgSend 调用 CacheLookup(当前方法)时，MissLabelDynamic 传的是 __objc_msgSend_uncached。
 // - 所以如果 p9 = nil，跳转至 __objc_msgSend_uncached。
 3:    cbz    p9, \MissLabelDynamic        //     if (sel == 0) goto Miss;
 // 比较，是否取完，没有取完继续循环。
     cmp    p13, p10            // } while (bucket >= buckets)
 // - 继续循环
     b.hs    1b
 ```
 
 这段代码需要重点注意！并且一定要理解 add    p13, p10, p12, LSL #(1+PTRSHIFT) 这一行汇编代码的含义，具体请看代码的注释。
 这一行代码的目的是为了拿到要查找的 sel 的下标的 bucket，通过拿到的 bucket 开始往前遍历查找是否有要查找的 sel。
 通过 bucket >= buckets 判断是否找到了 buckets 的第一个元素，如果找到第一个元素还是没匹配到要查找的 sel，流程继续往下走。
 
 来看下下面的流程，看这段代码：
 ```swift
 // 这里是根据不同的环境，计算要开始重新查找的下标。
 #if CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS
 这一步是重新计算要开始重新遍历 buckets 的下标，以 CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS 环境下为例。还记得在前面探索的 insert 么，mask 等于 capacity - 1，那么 capacity 是什么，capacity 是 buckets 的大小！
 那么这一小段代码相当于，把 buckets 的最后一个 bucket 存入 p13。
     add    p13, p10, w11, UXTW #(1+PTRSHIFT)
                         // p13 = buckets + (mask << 1+PTRSHIFT)
 #elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_HIGH_16
     add    p13, p10, p11, LSR #(48 - (1+PTRSHIFT))
                         // p13 = buckets + (mask << 1+PTRSHIFT)
                         // see comment about maskZeroBits
 #elif CACHE_MASK_STORAGE == CACHE_MASK_STORAGE_LOW_4
     add    p13, p10, p11, LSL #(1+PTRSHIFT)
                         // p13 = buckets + (mask << 1+PTRSHIFT)
 #else
 #error Unsupported cache mask storage for ARM64.
 #endif
 ```
 这一步是重新计算要开始重新遍历 buckets 的下标，以 CACHE_MASK_STORAGE_HIGH_16_BIG_ADDRS 环境下为例。还记得在前面探索的 insert 么，mask 等于 capacity - 1，那么 capacity 是什么，capacity 是 buckets 的大小！
 
 那么这一小段代码相当于，把 buckets 的最后一个 bucket 存入 p13，这意味着什么呢，我们继续来看下一个流程代码：
 ```swift
 // 注意看这里，在来到这之前，p12 是下标，是上面第一次循环开始的下标，那么它通过下标找到下标对应的 bucket，并且将 bucket 存到 p12。这个时候，p12 变成上面第一次开始循环的 bucket。
 // 当前的 p13 存着的 bucket 是往前遍历 buckets 的开始，通过 (sel != 0 && bucket > first_probed) 判断，是否遍历到了第一次循环遍历的临界点。
 // 如果到达临界点，走下一个流程 __objc_msgSend_uncached。
     add    p12, p10, p12, LSL #(1+PTRSHIFT)
                         // p12 = first probed bucket

 // - 以下是 do while 遍历，遍历 buckets，获取每个 bucket，查找是否有需要的 sel-imp
                         // do {
 // - 取出 bucket，并把 bucket 的 imp 赋值给 p17，sel 赋值给p9
 4:    ldp    p17, p9, [x13], #-BUCKET_SIZE    //     {imp, sel} = *bucket--
 // - 判断 p1(sel) 是否等于 p9(bucket 的 sel)
     cmp    p9, p1                //     if (sel == _cmd)
 // - 如果相等 即 CacheHit 缓存命中，跳转到 CacheHit 方法
     b.eq    2b                //         goto hit
 // - 如果不相等，并且 sel 不等于 nil，bucket > first_probed，继续循环
     cmp    p9, #0                // } while (sel != 0 &&
     ccmp    p13, p12, #0, ne        //     bucket > first_probed)
     b.hi    4b

 LLookupEnd\Function:
 LLookupRecover\Function:
 // 跳转至 MissLabelDynamic（__objc_msgSend_uncached）
     b    \MissLabelDynamic
 ```
 
 前面第一次 do while 循环是查找传进来的 sel 的下标开始往前遍历 buckets，那么只能查找下标前面的 bucket。
 那么如果在没找到要匹配的 sel，重新计算要开始查找的下标，也就是 后面要匹配的 sel 下标后面的 bucket。
 所以才会继续拿到重新计算的下标，继续 do while 往下标前遍历，查找 sel。
 为了不重复遍历之前查找过的 bucket，就通过 (sel != 0 && bucket > first_probed) 条件判断，是否遍历到了第一次循环遍历的临界点，如果到达临界点，走下一个流程 __objc_msgSend_uncached。
 
 到这里，消息传递流程的快速查找缓存方法到这里就结束了。
 
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
