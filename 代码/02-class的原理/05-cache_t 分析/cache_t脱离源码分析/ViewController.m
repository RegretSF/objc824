//
//  ViewController.m
//  cache_t脱离源码分析
//
//  Created by TT-Fangss on 2021/11/23.
//

#import "ViewController.h"

typedef uint32_t mask_t;

struct sh_bucket_t {
    IMP _imp;
    SEL _sel;
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

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    SHPerson *p = [[SHPerson alloc] init];
    struct sh_objc_class *p_class = (__bridge struct sh_objc_class *)([SHPerson class]);
    [self print_sel_and_imp:p_class];

    [p play_basketball];
    [p play_football];
    [self print_sel_and_imp:p_class];
    
    [p play_badminton];
    [p play_table_tennis];
    [self print_sel_and_imp:p_class];
    
    NSLog(@"%@", p);
}

// 打印
- (void)print_sel_and_imp:(struct sh_objc_class *)class {
    NSLog(@"_occupied: %hu - _maybeMask: %u",class->cache._occupied, class->cache._maybeMask);

    for (int i = 0; i < (int)class->cache._maybeMask; i++) {
        struct sh_bucket_t bucket = class->cache._buckets[i];
        NSLog(@"sel: %@ - imp: %p",NSStringFromSelector(bucket._sel),bucket._imp);
    }
}

@end
