//
//  SHPerson.h
//  02-KVC中访问器搜索模式
//
//  Created by TT-Fangss on 2021/9/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHPerson : NSObject {
    @public
    NSString *_name;
    NSString *_isName;
    NSString *name;
    NSString *isName;
    
//    NSMutableArray *_arrayM;
//    NSMutableArray *arrayM;
}


@property (nonatomic, strong) NSArray *arr;
@property (nonatomic, strong) NSSet   *set;

//@property (nonatomic, strong) NSMutableArray *arrayM;
@end

NS_ASSUME_NONNULL_END
