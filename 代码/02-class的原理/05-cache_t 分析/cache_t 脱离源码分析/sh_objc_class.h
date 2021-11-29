//
//  sh_objc_class.h
//  objc
//
//  Created by TT-Fangss on 2021/11/25.
//
#import <Foundation/Foundation.h>
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

