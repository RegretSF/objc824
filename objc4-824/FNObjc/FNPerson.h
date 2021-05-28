//
//  FNPerson.h
//  FNObjc
//
//  Created by Fat brother on 2021/5/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FNPerson : NSObject

/*
 iOS 内存 小端模式
 
 对象开辟内存的影响因素：属性 -> 8 + 8 + 8 = 24, 但结果是 32
 内存的布局 - 字节对齐
 */

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *age;
@end

NS_ASSUME_NONNULL_END
