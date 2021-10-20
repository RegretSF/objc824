//
//  SHKVOInfo.h
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SHKVOInfo : NSObject
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, weak) id observer;
@property (nonatomic) NSKeyValueObservingOptions options;

- (instancetype)initWithObserver:(id)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options;
@end

NS_ASSUME_NONNULL_END
