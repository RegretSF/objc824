//
//  Person.h
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject
@property (nonatomic, copy) NSString *fullName;
@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSString *lastName;
@end

NS_ASSUME_NONNULL_END
