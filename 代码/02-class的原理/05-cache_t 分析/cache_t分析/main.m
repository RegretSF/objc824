////
////  main.m
////  cache_t分析
////
////  Created by TT-Fangss on 2021/11/23.
////
//
#import <Foundation/Foundation.h>

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
