//
//  sh_objc_class.h
//  objc
//
//  Created by TT-Fangss on 2021/11/25.
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

