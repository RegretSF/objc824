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
        
        FNPerson *objc1 = [FNPerson alloc];
        FNPerson *objc2 = [FNPerson alloc];
        
        NSLog(@"Hello, World! -- %@ -- %@", objc1, objc2);
    }
    return 0;
}
