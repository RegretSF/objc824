//
//  SHPerson.h
//  03-自定义KVC流程
//
//  Created by TT-Fangss on 2021/9/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHPerson : NSObject{
@public
NSString *_name;
NSString *_isName;
NSString *name;
NSString *isName;
}

@property (nonatomic, strong) NSArray *arr;
@property (nonatomic, strong) NSSet   *set;

//@property (nonatomic, strong) NSMutableArray *arrayM;
@end

NS_ASSUME_NONNULL_END
