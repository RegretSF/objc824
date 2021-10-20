//
//  SHClass.h
//  01-KVC简介
//
//  Created by TT-Fangss on 2021/9/23.
//

#import <Foundation/Foundation.h>
#import "SHTeacher.h"
#import "SHStudent.h"

NS_ASSUME_NONNULL_BEGIN
typedef struct {
    float x, y, z;
} ThreeFloats;


@interface SHClass : NSObject
@property (nonatomic, strong) SHStudent *student;
@property (nonatomic, strong) SHTeacher *teacher;

@property (nonatomic) ThreeFloats threeFloats;
@end

NS_ASSUME_NONNULL_END
