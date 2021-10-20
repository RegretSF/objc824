//
//  NSObject+SHKVO.h
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/11.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (KVO)
/// 自定义KVO添加观察者方法
- (void)sh_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void * _Nullable )context;

/// 自定义移除观察者
- (void)sh_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

/// 自定义KVO观察者方法
- (void)sh_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void * _Nullable)context;
@end

NS_ASSUME_NONNULL_END
