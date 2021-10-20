//
//  Person.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "Person.h"

@implementation Person
- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@",_firstName, _lastName];
}

+(NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    
    if ([key isEqualToString:@"fullName"]) {
        NSArray *affectingKeys = @[@"lastName", @"firstName"];
        keyPaths = [keyPaths setByAddingObjectsFromArray:affectingKeys];
    }
    return keyPaths;
}

//+ (NSSet<NSString *> *)keyPathsForValuesAffectingFullName {
//    return [NSSet setWithObjects:@"lastName", @"firstName", nil];
//}
@end
