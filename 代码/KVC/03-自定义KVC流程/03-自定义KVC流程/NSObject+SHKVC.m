//
//  NSObject+SHKVC.m
//  03-自定义KVC流程
//
//  Created by TT-Fangss on 2021/9/28.
//

#import "NSObject+SHKVC.h"
#import <objc/runtime.h>

@implementation NSObject (SHKVC)
- (void)sh_setValue:(id)value forKey:(NSString *)key {
    //0: nil 处理
    if (key == nil || key.length == 0) return;
    
    //1: set<Key>: 、_set<Key>: or setIs<Key>:
    // key 首字母要大写
    // 拼接方法
    NSString *setKey = [NSString stringWithFormat:@"set%@:", key.capitalizedString];
    NSString *_setKey = [NSString stringWithFormat:@"_set%@:", key.capitalizedString];
    NSString *setIsKey = [NSString stringWithFormat:@"setIs%@:", key.capitalizedString];
    
    // 查找相关方法
    if ([self respondsToSelector:NSSelectorFromString(setKey)]) {
        [self sh_performSelectorWithMethodName:setKey value:value];
        return;
        
    }else if ([self respondsToSelector:NSSelectorFromString(_setKey)]) {
        [self sh_performSelectorWithMethodName:_setKey value:value];
        return;
        
    }else if ([self respondsToSelector:NSSelectorFromString(setIsKey)]) {
        [self sh_performSelectorWithMethodName:setIsKey value:value];
        return;
    }
    
    //2:
    //  1) 判断 accessInstanceVariablesDirectly 的返回值
    if ([self.class accessInstanceVariablesDirectly] == NO) {
        @throw [NSException exceptionWithName:@"NSUnknownKeyException" reason:[NSString stringWithFormat:@"****[%@ valueForUndefinedKey:]: this class is not key value coding-compliant for the key name.****",self] userInfo:nil];
        return;
    }
    
    //  2) _<key>、_is<Key>、<key>、is<Key>
    // 间接访问成员变量
    NSArray *ivars = [self sh_getIvarListName];
    NSString *_key = [NSString stringWithFormat:@"_%@", key];
    NSString *_isKey = [NSString stringWithFormat:@"_is%@", key.capitalizedString];
    NSString *isKey = [NSString stringWithFormat:@"is%@", key.capitalizedString];
    if ([ivars containsObject:_key]) {
        // 获取对应的 ivar
        Ivar ivar = class_getInstanceVariable([self class], _key.UTF8String);
        // 给 ivar 赋值
        object_setIvar(self , ivar, value);
        return;
        
    }else if ([ivars containsObject:_isKey]) {
        // 获取对应的 ivar
        Ivar ivar = class_getInstanceVariable([self class], _isKey.UTF8String);
        // 给 ivar 赋值
        object_setIvar(self , ivar, value);
        return;
        
    }else if ([ivars containsObject:key]) {
        // 获取对应的 ivar
        Ivar ivar = class_getInstanceVariable([self class], key.UTF8String);
        // 给 ivar 赋值
        object_setIvar(self , ivar, value);
        return;
        
    }else if ([ivars containsObject:isKey]) {
        // 获取对应的 ivar
        Ivar ivar = class_getInstanceVariable([self class], isKey.UTF8String);
        // 给 ivar 赋值
        object_setIvar(self , ivar, value);
        return;
        
    }
    
    //3: 如果找不到
    @throw [NSException exceptionWithName:@"NSUnknownKeyException" reason:[NSString stringWithFormat:@"****[%@ %@]: this class is not key value coding-compliant for the key name.****",self,NSStringFromSelector(_cmd)] userInfo:nil];
}

- (id)sh_valueForKey:(NSString *)key {
    //0: nil 处理
    if (key == nil || key.length == 0) return nil;
    
    //1. 简单的访问器方法 get<Key>、<key>、is<Key>、_<key>
    NSString *getKey = [NSString stringWithFormat:@"get%@", key.capitalizedString];
    NSString *isKey = [NSString stringWithFormat:@"is%@", key.capitalizedString];
    NSString *_key = [NSString stringWithFormat:@"_%@", key];
    
    if ([self respondsToSelector:NSSelectorFromString(getKey)]) {
        return [self sh_performSelectorWithMethodName:getKey];
        
    }else if ([self respondsToSelector:NSSelectorFromString(key)]) {
        return [self sh_performSelectorWithMethodName:key];
        
    }else if ([self respondsToSelector:NSSelectorFromString(isKey)]) {
        return [self sh_performSelectorWithMethodName:isKey];
        
    }else if ([self respondsToSelector:NSSelectorFromString(_key)]) {
        return [self sh_performSelectorWithMethodName:_key];
    }
    
    //2. 查找NSArray相关方法 countOf<Key>、objectIn<Key>AtIndex:、<key>AtIndexes:。
    NSString *countOfKey = [NSString stringWithFormat:@"countOf%@", key.capitalizedString];
    NSString *objectInKeyAtIndex = [NSString stringWithFormat:@"objectIn%@AtIndex:", key.capitalizedString];
    NSString *keyAtIndexes = [NSString stringWithFormat:@"%@AtIndexes:", key];
    
    if ([self respondsToSelector:NSSelectorFromString(countOfKey)]) {
        if ([self respondsToSelector:NSSelectorFromString(objectInKeyAtIndex)]) {
            int num = (int)[self performSelector:NSSelectorFromString(countOfKey)];
            NSMutableArray *mArray = [NSMutableArray arrayWithCapacity:1];
            for (int i = 0; i<num-1; i++) {
                num = (int)[self performSelector:NSSelectorFromString(countOfKey)];
            }
            for (int j = 0; j<num; j++) {
                id objc = [self performSelector:NSSelectorFromString(objectInKeyAtIndex) withObject:@(num)];
                [mArray addObject:objc];
            }
            return mArray;
        }
    }
    
    //3. 查找NSSet相关方法 countOf<Key>、enumeratorOf<Key> 和 memberOf<Key>:
    NSString *enumeratorOfKey = [NSString stringWithFormat:@"enumeratorOf%@", key.capitalizedString];
    NSString *memberOfKey = [NSString stringWithFormat:@"memberOf%@:", key.capitalizedString];
    
    if ([self respondsToSelector:NSSelectorFromString(countOfKey)]) {
        if ([self respondsToSelector:NSSelectorFromString(enumeratorOfKey)]) {
            int count = (int)[self performSelector:NSSelectorFromString(countOfKey)];
            for (int i = 0; i < count - 1; i++) {
                count = (int)[self performSelector:NSSelectorFromString(countOfKey)];
            }
            return [self sh_performSelectorWithMethodName:enumeratorOfKey];
            
        }else if ([self respondsToSelector:NSSelectorFromString(memberOfKey)]) {
            return [self performSelector:NSSelectorFromString(memberOfKey)];
        }
    }
    
    //4. 间接访问成员变量
    //  1) 判断 accessInstanceVariablesDirectly 的返回值
    if ([self.class accessInstanceVariablesDirectly] == NO) {
        @throw [NSException exceptionWithName:@"NSUnknownKeyException" reason:[NSString stringWithFormat:@"****[%@ valueForUndefinedKey:]: this class is not key value coding-compliant for the key name.****",self] userInfo:nil];
    }
    
    //  2) 间接访问 _<key>、_is<Key>、<key>、is<Key>
    NSArray *ivars = [self sh_getIvarListName];
    NSString *_isKey = [NSString stringWithFormat:@"_is%@", key.capitalizedString];
    
    if ([ivars containsObject:_key]) {
        // 获取对应的 ivar
        Ivar ivar = class_getInstanceVariable([self class], _key.UTF8String);
        return object_getIvar(self, ivar);
        
    }else if ([ivars containsObject:_isKey]) {
        Ivar ivar = class_getInstanceVariable([self class], _isKey.UTF8String);
        return object_getIvar(self, ivar);
        
    }else if ([ivars containsObject:key]) {
        Ivar ivar = class_getInstanceVariable([self class], key.UTF8String);
        return object_getIvar(self, ivar);
        
    }else if ([ivars containsObject:isKey]) {
        Ivar ivar = class_getInstanceVariable([self class], isKey.UTF8String);
        return object_getIvar(self, ivar);
        
    }
    
    //6. 异常处理
    @throw [NSException exceptionWithName:@"NSUnknownKeyException" reason:[NSString stringWithFormat:@"****[%@ %@]: this class is not key value coding-compliant for the key name.****",self,NSStringFromSelector(_cmd)] userInfo:nil];
}

#pragma mark - 相关方法
- (void)sh_performSelectorWithMethodName:(NSString *)methodName value:(id)value{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(methodName) withObject:value];
#pragma clang diagnostic pop
}

- (id)sh_performSelectorWithMethodName:(NSString *)methodName{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [self performSelector:NSSelectorFromString(methodName)];
#pragma clang diagnostic pop
}

- (NSArray *)sh_getIvarListName{
    NSMutableArray *mArray = [NSMutableArray arrayWithCapacity:1];
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (int i = 0; i<count; i++) {
        Ivar ivar = ivars[i];
        const char *ivarNameChar = ivar_getName(ivar);
        NSString *ivarName = [NSString stringWithUTF8String:ivarNameChar];
        [mArray addObject:ivarName];
    }
    free(ivars);
    return mArray.copy;
}
@end
