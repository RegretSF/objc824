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
