//
//  SHPerson.h
//  01-KVC简介
//
//  Created by TT-Fangss on 2021/9/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHPerson : NSObject
@property (nonatomic, copy)     NSString *name;
@property (nonatomic) NSInteger age;
@property (nonatomic, strong) NSArray *courseArr;
@property (nonatomic) NSInteger length;
@end

NS_ASSUME_NONNULL_END
