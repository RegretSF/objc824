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
 
 这个时候，p10 是 buckets 的第一个 bucket，p11 是 mask，p12 是下标。
 拿到 index 和 buckets 之后，就开始，通过 index 取出 buckets 的 bucket，看看缓存中是否有当前要找的 sel。
 汇编代码如下：
 ```swift
 // - p12 是下标，p10 是 buckets 数组首地址，下标 * 1<<4(即16) 得到实际内存的偏移量，通过 buckets 的首地址偏移，获取 bucket 存入 p12。
 // - LSL #(1+PTRSHIFT)-- 实际含义就是得到一个 bucket 占用的内存大小 -- 相当于 mask = occupied -1 -- _cmd & mask -- 取余数
     add    p13, p10, p12, LSL #(1+PTRSHIFT)
                         // p13 = buckets + ((_cmd & mask) << (1+PTRSHIFT))，PTRSHIFT等于3

 // - 以下是 do while 遍历，遍历 buckets，获取每个 bucket，查找是否有需要的 sel-imp
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
 // - 所以如果找不着当前的 p1(sel)，跳转至 __objc_msgSend_uncached。
 3:    cbz    p9, \MissLabelDynamic        //     if (sel == 0) goto Miss;
 // 比较，是否取完，没有取完继续循环。
     cmp    p13, p10            // } while (bucket >= buckets)
 // - 继续循环
     b.hs    1b
 ```
 
 获取 buckets 占用内存的大小，从最后的 index 开始取 bucket，进行 do-while 循环。
 判断取出的 bucket 中的 sel 是否等于查找的 sel，如果相等，缓存命中，直接返回imp。
 如果不相等，判断是否循环结束，没有结束就继续循环。如果取出的 bucket 中的 sel 为 nil（找不到 sel），跳转至 __objc_msgSend_uncached。
 
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
