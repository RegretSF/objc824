//
//  main.m
//  class结构分析
//
//  Created by TT-Fangss on 2021/10/28.
//

#import <Foundation/Foundation.h>

@interface SHPerson : NSObject
@end
@implementation SHPerson
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
//        // 普通指针 --  地址->值
//        int a = 10; //
//        int b = 10; //
//        NSLog(@"%d -- %p",a,&a);
//        NSLog(@"%d -- %p",b,&b);
//
//        // 对象指针 -- 地址->地址->值
//        SHPerson *p1 = [SHPerson alloc];
//        SHPerson *p2 = [SHPerson alloc];
//        NSLog(@"%@ -- %p",p1,&p1);
//        NSLog(@"%@ -- %p",p2,&p2);
//
//        // 数组指针
//        // 数组的首地址就是第0个元素的地址,通过元素的地址可以取元素的值。
//        // 将数组c赋值给int类型的指针d，以d+n的形式获取值相当于&c[n]，表示获取数组元素的地址。
//        int c[4] = {1,2,3,4};
//        int *d   = c;
//        NSLog(@"%p - %p - %p",&c,&c[0],&c[1]);
//        NSLog(@"%p - %p - %p",d,d+1,d+2);
//
//        // d+i是通过内存平移的方式获取内存中的地址，而*(d+i)是取内存中这个地址的值。
//        for (int i = 0; i<4; i++) {
//            int value =  *(d+i);
//            NSLog(@"%d",value);
//        }
//        // OC 类 结构 首地址 - 平移一些大小 -> 内容
//        // SHPerson.class地址 - 平移 所有的值
//        NSLog(@"指针 - 内存偏移");
        
        SHPerson *person = [[SHPerson alloc] init];
        NSLog(@"类的结构内存计算");
        /*
         isa_t isa;             // 8字节
         Class superclass;      // 8字节
         cache_t cache;         // 16字节
         class_data_bits_t bits;
         
         求出 bits 的内存地址
         isa的内存大小 + superclass的内存大小 + cache的内存大小
         8 + 8 + 16 = 32
         SHPerson.class首地址 + 32个字节
         
         (lldb) x/4gx SHPerson.class
         0x1000080e8: 0x00000001000080c0 0x0000000100379140
         0x1000080f8: 0x0001000100797e90 0x0001801000000000
         (lldb) po 0x0000000100379140
         NSObject

         (lldb) p/x NSObject.class
         (Class) $3 = 0x0000000100379140 NSObject
         (lldb) x/6gx SHPerson.class
         0x1000080e8: 0x00000001000080c0 0x0000000100379140
         0x1000080f8: 0x0001000100797e90 0x0001801000000000
         0x100008108: 0x0000000100797e74 0x000000010009d910
         (lldb) p/x 0x1000080e8+0x20
         (long) $5 = 0x0000000100008108
         (lldb) p (class_data_bits_t *)0x0000000100008108
         (class_data_bits_t *) $6 = 0x0000000100008108
         (lldb)
         */
    }
    return 0;
}
