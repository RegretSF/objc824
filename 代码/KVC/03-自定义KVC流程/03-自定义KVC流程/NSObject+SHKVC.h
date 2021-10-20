//
//  NSObject+SHKVC.h
//  03-自定义KVC流程
//
//  Created by TT-Fangss on 2021/9/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (SHKVC)
/// 自定义  setValue:forKey:
/// @param value value
/// @param key key
- (void)sh_setValue:(id)value forKey:(NSString *)key;

/// 自定义 valueForKey:
/// @param key key
- (id)sh_valueForKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
