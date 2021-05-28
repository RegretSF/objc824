//
//  main.m
//  FNObjc
//
//  Created by Fat brother on 2021/5/28.
//

#import <Foundation/Foundation.h>
#import "FNPerson.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        // alloc 开辟内存 - init - new
        // init: return (id)self; 构造方法 工厂设计 --
        // -- init 只是一个工厂设计的方法，提供给开发人员一个构造方法的入口
        // array objc 初始化出来的东西相同吗？ - 不相同
        // new -> [FNPerson new] == [callAlloc(self, false/*checkNil*/) init] == [allon init]
        // 不建议使用 new 来初始化对象，因为当重写 init{}方法，在里面写一些东西，
        // 然后调用 new 方法时，会发现，new 方法并没有你重写的 init{} 方法之后里面所写的东西。
        
        FNPerson *objc1 = [FNPerson alloc];
        FNPerson *objc2 = [FNPerson alloc];
        
        NSLog(@"Hello, World! -- %@ -- %@", objc1, objc2);
    }
    return 0;
}
