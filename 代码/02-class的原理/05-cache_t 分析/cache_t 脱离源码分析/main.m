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
 
 接下来我们不通过 lldb 的打印去打印 cache_t 的值，直接通过 NSLog 方法打印。那么就需要模仿源码，自己也搞个 cache_t, 自己也搞个 objc_class，请看下面的代码。
 ```
 struct sh_preopt_cache_entry_t {
     uint32_t sel_offs;
     uint32_t imp_offs;
 };

 struct sh_preopt_cache_t {
     int32_t  fallback_class_offset;
     union {
         struct {
             uint16_t shift       :  5;
             uint16_t mask        : 11;
         };
         uint16_t hash_params;
     };
     uint16_t occupied    : 14;
     uint16_t has_inlines :  1;
     uint16_t bit_one     :  1;
     struct sh_preopt_cache_entry_t entries[];
 };

 struct sh_bucket_t {
     IMP _imp;
     SEL _sel;
 };

 struct sh_cache_t {
     struct sh_bucket_t *_buckets;
     
     uint32_t    _maybeMask;
     
     uint16_t _flags;
     uint16_t _occupied;
     
     struct sh_preopt_cache_t * _originalPreoptCache;
 };

 struct sh_class_data_bits_t {
     uintptr_t bits;
 };

 struct sh_objc_class {
     Class ISA;
     Class superclass;
     struct sh_cache_t cache;
     struct sh_class_data_bits_t bits;
 };

 ```
 
 定义一个 SHPerson 对象，并添加方法。
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
 
 我们还需要一个打印的方法，打印出 _occupied 和 _maybeMask 的变化，并且把 bucket_t*(_bucketsAndMaybeMask) 的所有 bucket_t 打印出来。
 来看打印方法的实现：
 ```
 void print_sel_and_imp(struct sh_objc_class *class) {
     // 打印 _occupied，_maybeMask，观察其变化
     NSLog(@"_occupied: %hu - _maybeMask: %u",class->cache._occupied, class->cache._maybeMask);

     for (int i = 0; i < (int)class->cache._maybeMask; i++) {
         struct sh_bucket_t bucket = class->cache._buckets[i];
         // 打印 bucket_t 的信息
         NSLog(@"sel: %@ - imp: %p",NSStringFromSelector(bucket._sel),bucket._imp);
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
 ```
 
 */

// 打印
void print_sel_and_imp(struct sh_objc_class *class) {
    NSLog(@"_occupied: %hu - _maybeMask: %u",class->cache._occupied, class->cache._maybeMask);
    for (int i = 0; i < (int)class->cache._maybeMask; i++) {
        struct sh_bucket_t bucket = class->cache._buckets[i];
        NSLog(@"sel: %p - imp: %p",bucket._sel,bucket._imp);
    }
    
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        SHPerson *p = [SHPerson alloc];
        
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

