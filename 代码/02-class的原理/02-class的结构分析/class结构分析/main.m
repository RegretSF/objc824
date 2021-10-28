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
        // 普通指针 --  地址->值
        int a = 10; //
        int b = 10; //
        NSLog(@"%d -- %p",a,&a);
        NSLog(@"%d -- %p",b,&b);
        
        // 对象指针 -- 地址->地址->值
        SHPerson *p1 = [SHPerson alloc];
        SHPerson *p2 = [SHPerson alloc];
        NSLog(@"%@ -- %p",p1,&p1);
        NSLog(@"%@ -- %p",p2,&p2);

        // 数组指针
        // 数组的首地址就是第0个元素的地址,通过元素的地址可以取元素的值。
        // 将数组c赋值给int类型的指针d，以d+n的形式获取值相当于&c[n]，表示获取数组元素的地址。
        int c[4] = {1,2,3,4};
        int *d   = c;
        NSLog(@"%p - %p - %p",&c,&c[0],&c[1]);
        NSLog(@"%p - %p - %p",d,d+1,d+2);
        
        // d+i是通过内存平移的方式获取内存中的地址，而*(d+i)是取内存中这个地址的值。
        for (int i = 0; i<4; i++) {
            int value =  *(d+i);
            NSLog(@"%d",value);
        }
        // OC 类 结构 首地址 - 平移一些大小 -> 内容
        // SHPerson.class地址 - 平移 所有的值
        NSLog(@"指针 - 内存偏移");
    }
    return 0;
}
