//
//  Person.h
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) int age;


/**打印对象的一些信息，验证*/
- (void)printObjectInfo;
@end

NS_ASSUME_NONNULL_END
