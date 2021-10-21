//
//  SHPerson.h
//  KCObjcBuild
//
//  Created by cooci on 2021/1/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHPerson : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic) int age;
@property (nonatomic) long height;
@property (nonatomic, copy) NSString *nickName;


- (void)saySomething;

@end

NS_ASSUME_NONNULL_END
