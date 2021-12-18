//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>

/*
 objc_msgSend 函数在进行消息传递的过程中，会先进行快速查找缓存方法，快速查找缓存方法是用汇编实现，其汇编函数名为 CacheLookup 。如果 CacheLookup 函数中没有找到要匹配的方法，会跳转到 __objc_msgSend_uncached 函数。
 
 ## 一、__objc_msgSend_uncached
__objc_msgSend_uncached 的实现如下：
 ```swift
 STATIC_ENTRY __objc_msgSend_uncached
 UNWIND __objc_msgSend_uncached, FrameWithNoSaves

 // THIS IS NOT A CALLABLE C FUNCTION
 // Out-of-band p15 is the class to search
 
 MethodTableLookup
 TailCallFunctionPointer x17

 END_ENTRY __objc_msgSend_uncached
 ```
 
 在 __objc_msgSend_uncached 函数中会执行 MethodTableLookup 函数，MethodTableLookup 函数实现如下：
 ```swift
 .macro MethodTableLookup
     
     SAVE_REGS MSGSEND

     // lookUpImpOrForward(obj, sel, cls, LOOKUP_INITIALIZE | LOOKUP_RESOLVER)
     // receiver and selector already in x0 and x1
     mov    x2, x16
     mov    x3, #3
     bl    _lookUpImpOrForward

     // IMP in x0
     mov    x17, x0

     RESTORE_REGS MSGSEND

 .endmacro
 ```
 
 bl 指令：带链接程序跳转，也就是要带返回地址。也就是说，MethodTableLookup 函数调用后，会跳转到 _lookUpImpOrForward 函数，查找 IMP。
 注意：
 * C/C++ 中调用汇编 ，去查找汇编时，需要将 C/C++ 调用的方法多加一个下划线。例如 objc_msgSend 在汇编中是 _objc_msgSend。
 * 汇编中调用 C/C++ 方法时，去查找 C/C++ 方法，需要将汇编调用的方法去掉一个下划线。例如 例如 _objc_msgSend 在C/C++中是 objc_msgSend。
 
 ## 二、lookUpImpOrForward
 
 所以，_lookUpImpOrForward 的实现是用 C/C++ 写的，实现代码如下：
 ```swift
 IMP lookUpImpOrForward(id inst, SEL sel, Class cls, int behavior)
{
    const IMP forward_imp = (IMP)_objc_msgForward_impcache;
    IMP imp = nil;
    Class curClass;
    // ...... --> 中间代码先省略，太长了，下面会贴出来。
    return imp;
}
 ```
 
 由于代码过长，就省略中间部分的代码，先来看 lookUpImpOrForward 函数第一段关键的代码。
 ```swift
 // We don't want people to be able to craft a binary blob that looks like
 // a class but really isn't one and do a CFI attack.
 //
 // To make these harder we want to make sure this is a class that was
 // either built into the binary or legitimately registered through
 // objc_duplicateClass, objc_initializeClassPair or objc_allocateClassPair.
 // 检查 cls 是否注册到当前的缓存表里（注册类）。
 checkIsKnownClass(cls);

 // 类的初始化流程，主要是 isa 的流程初始化，比如对类的superclass和isa进行初始化，为的就是之后的查找方法。
 cls = realizeAndInitializeIfNeeded_locked(inst, cls, behavior & LOOKUP_INITIALIZE);
 // runtimeLock may have been dropped but is now locked again
 runtimeLock.assertLocked();
 curClass = cls;
 ```
 
 首先检查是否注册过当前要查找的类，其次是 isa 和 superclass 的初始化流程，为下面的查找流程做铺垫。
 
 接下来就是 lookUpImpOrForward 函数里最重要的代码了。
 ```swift
 // 核心重点!
 // 这个 for 循环是一个死循环，因为没有 i < count; i++ 或者 i-- 这些条件判断。
 // 如果要退出当前的死循环，需要有退出循环的语句，比如 break，goto 或者 return。
 for (unsigned attempts = unreasonableClassCount();;) {
     // 快速查找缓存方法
     if (curClass->cache.isConstantOptimizedCache(true)) {
#if CONFIG_USE_PREOPT_CACHES
         // cache_getImp 也是快速查找缓存方法的流程，它是在 CacheLookup 之后，慢速查找之前。
         // 为什么在 CacheLookup 快速查找后还需要 调用 cache_getImp 进行快速查找。
         // 因为如果在快速查找的过程中可能在对 class_rw_t 进行操作，那么就导致在第一次快速查找的时候会漏掉。
         // 所以会在慢速查找之前调用 cache_getImp 再进行一次快速查找，以防万一。
         imp = cache_getImp(curClass, sel);
         if (imp) goto done_unlock;
         curClass = curClass->cache.preoptFallbackClass();
#endif
     } else {
         // curClass method list.
         // 二分查找法入口
         Method meth = getMethodNoSuper_nolock(curClass, sel);
         // 如果找到 meth，跳转到 done
         if (meth) {
             imp = meth->imp(false);
             goto done;
         }
         
         // 如果没有找到，去父类查找。
         // 注意！获取父类的是写在了 if 条件判断里：(curClass = curClass->getSuperclass()) == nil)
         // 如果父类不为nil，继续往下走。
         // 找到根类的 superclass 后，进行消息转发，退出循环。
         if (slowpath((curClass = curClass->getSuperclass()) == nil)) {
             // No implementation found, and method resolver didn't help.
             // Use forwarding.
             // 没有找到，进行消息转发。
             imp = forward_imp;
             break;
         }
     }

     // Halt if there is a cycle in the superclass chain.
     if (slowpath(--attempts == 0)) {
         _objc_fatal("Memory corruption in class list.");
     }

     // Superclass cache.
     // 快速查找父类的缓存方法
     imp = cache_getImp(curClass, sel);
     if (slowpath(imp == forward_imp)) {
         // Found a forward:: entry in a superclass.
         // Stop searching, but don't cache yet; call method
         // resolver for this class first.
         break;
     }
     
     // 在父类中找到方法，开始进行缓存。
     if (fastpath(imp)) {
         // Found the method in a superclass. Cache it in this class.
         goto done;
     }
 }
 ```
 
 这个 for 循环是一个死循环，因为没有 i < count; i++ 或者 i-- 这些条件判断。如果要退出当前的死循环，需要有退出循环的语句，比如 break，goto 或者 return。
 
 进入 for 循环后，第一点先判断 cache.isConstantOptimizedCache(true) 是否成立，成立的话调用 cache_getImp ，这也是一个快速查找缓存的方法，为什么是快速查找，下面会解释。
 
 那为什么在 CacheLookup 快速查找后还需要调用 cache_getImp 进行快速查找。因为如果在快速查找的过程中可能在对 class_rw_t 进行操作，那么就导致在第一次快速查找的时候会漏掉。所以会在慢速查找之前调用 cache_getImp 再进行一次快速查找，以防万一。
 
 
 ## 三、慢速查找入口
 如果快速查找缓存方法没有找到，那么，接下来才是我们的重点。请看 getMethodNoSuper_nolock 函数：
 ```swift
 static method_t *
 getMethodNoSuper_nolock(Class cls, SEL sel)
 {
     runtimeLock.assertLocked();

     ASSERT(cls->isRealized());
     // fixme nil cls?
     // fixme nil sel?

     auto const methods = cls->data()->methods();
     for (auto mlists = methods.beginLists(),
               end = methods.endLists();
          mlists != end;
          ++mlists)
     {
         // <rdar://problem/46904873> getMethodNoSuper_nolock is the hottest
         // caller of search_method_list, inlining it turns
         // getMethodNoSuper_nolock into a frame-less function and eliminates
         // any store from this codepath.
         method_t *m = search_method_list_inline(*mlists, sel);
         if (m) return m;
     }

     return nil;
 }
 ```
 
 最终定位到 search_method_list_inline 函数。
 
 但是，注意看，在 cls->data()->methods() 拿到方法列表了之后，还需要进行 for 循环，从 methods 里再取出 mlists。再调用 search_method_list_inline 对 mlists 进行操作。
 
 那为什么会这样呢，方法列表不是只有一个么？OC 是一门动态运行时语言，那就意味着，可以动态的添加方法，所以 methods() 拿到的可能是一个二维数组。
 
 接下来看一下 search_method_list_inline 函数实现：
 ```swift
 ALWAYS_INLINE static method_t *
 search_method_list_inline(const method_list_t *mlist, SEL sel)
 {
     int methodListIsFixedUp = mlist->isFixedUp();
     int methodListHasExpectedSize = mlist->isExpectedSize();
     
     if (fastpath(methodListIsFixedUp && methodListHasExpectedSize)) {
         return findMethodInSortedMethodList(sel, mlist);
     } else {
         // Linear search of unsorted method list
         if (auto *m = findMethodInUnsortedMethodList(sel, mlist))
             return m;
     }

 #if DEBUG
     // sanity-check negative results
     if (mlist->isFixedUp()) {
         for (auto& meth : *mlist) {
             if (meth.name() == sel) {
                 _objc_fatal("linear search worked when binary search did not");
             }
         }
     }
 #endif

     return nil;
 }
 ```
 首先进来会判断，方法列表是否已经排序好，如果没有，调用 findMethodInUnsortedMethodList 函数，否则调用 findMethodInSortedMethodList。
 findMethodInUnsortedMethodList 函数的实现简单粗暴，就是把 mlist 的 sel 全部遍历出来，和下面的 DEBUG 下的那个 for 一致。这里代码就不贴了。
 
 我们看方法列表已排序的情况，findMethodInSortedMethodList 函数的实现：
 ```swift
 findMethodInSortedMethodList(SEL key, const method_list_t *list)
 {
     if (list->isSmallList()) {
         if (CONFIG_SHARED_CACHE_RELATIVE_DIRECT_SELECTORS && objc::inSharedCache((uintptr_t)list)) {
             return findMethodInSortedMethodList(key, list, [](method_t &m) { return m.getSmallNameAsSEL(); });
         } else {
             return findMethodInSortedMethodList(key, list, [](method_t &m) { return m.getSmallNameAsSELRef(); });
         }
     } else {
         return findMethodInSortedMethodList(key, list, [](method_t &m) { return m.big().name; });
     }
 }
 ```
 
 里面是对大小列表的处理，架构的不同是走不同的判断的，因为有的可以通过 big() 函数拿到 sel，有的不行。在拿到 sel 之前走的都是 findMethodInSortedMethodList 函数。
 
 并且，findMethodInSortedMethodList 函数是重载函数，函数名相同，参数个数不同。
 ```swift
 template<class getNameFunc>
 ALWAYS_INLINE static method_t *
 findMethodInSortedMethodList(SEL key, const method_list_t *list, const getNameFunc &getName)
 ```
 
 ## 四、慢速查找方法实现
 接下来，这个函数才是重点！那么在看这个函数之前，我们来了解一下什么叫二分查找法。
 举个例子：
 这里有一个区间 0～100，我需要找到 55 这个数的位置，按正常的逻辑用一个循环从0去遍历，也可以找到，但会有个问题，从0去遍历需要一个一个的去找，会非常的消耗性能。
 如果用二分查找，是怎么查找呢。
 
 * 取一个中间数，比如 50 ，那么 50 是小于 55 。
 * 再取一个数，这个数是 50～100 区间内的数，比如 75，那么 75 大于 55 。
 * 再取一个数，50～75 区间内的数，比如 60，60 还是大于 55。
 * 再取一个数，50～60 区间内的数，比如 55，这个时候就找到了。
 
 那么通过这个二分查找呢，我们就用了 4 次，相比于循环一个一个去遍历是不是快了很多呢。
 
 下面这个方法，就是很经典的二分查找法。通过二分查找法可以快速的找到要找的方法。
 
 ```swift
 template<class getNameFunc>
 ALWAYS_INLINE static method_t *
 findMethodInSortedMethodList(SEL key, const method_list_t *list, const getNameFunc &getName)
 {
     ASSERT(list);

     // auto 自动推断类型，
     auto first = list->begin();
     auto base = first;
     // decltype被称作类型说明符，它的作用是选择并返回操作数的数据类型。
     // probe 为 （auto first）类型的指针。
     decltype(first) probe;

     uintptr_t keyValue = (uintptr_t)key;
     uint32_t count;
 
     // count >>= 1：右移一位。
     // 假设 count = 8 -> 1000。
     // base = 0。
     // count 右移一位变成 0100 -> 4。
     // 所以 probe = 0 + 4 = 4。
     // 如果不匹配，并且 (keyValue > probeValue)，这个时候 count = 7，base = 5。
     //
     // 下一次循环：
     // count = 7 -> 0111。右移一位：0011(3)，count = 3。
     // 根据二分查找的规则，因为 (keyValue > probeValue)，那么 keyValue 正确位置应该在 base(5)~8 之间，它们之间只有两个数 6 和 7。
     // base = 5。
     // probe = 5 + (3 >> 1) = 6。
     // 取出来的位置正好是 5~8 之间，这就是二分查找法的代码实现。
     
     for (count = list->count; count != 0; count >>= 1) {
         // 二分查找，取 base ~ count 的区间数。
         probe = base + (count >> 1);
         
         // 取 sel
         uintptr_t probeValue = (uintptr_t)getName(probe);
         // 如果匹配
         if (keyValue == probeValue) {
             // `probe` is a match.
             // Rewind looking for the *first* occurrence of this value.
             // This is required for correct category overrides.
             // 那么 sel 都匹配上了，为什么还要做一步 while 循环。
             // 方法有可能是分类中的方法，并且和主类中的方法名字一模一样。相当于主类中的方法被重写了 这个时候就考虑到调用顺序的问题。
             while (probe > first && keyValue == (uintptr_t)getName((probe - 1))) {
                 probe--;
             }
             // &*probe,即&(*probe),*probe 解引用，&取地址。
             return &*probe;
         }
         
         // 如果不匹配
         if (keyValue > probeValue) {
             base = probe + 1;
             count--;
         }
     }
     
     return nil;
 }
 ```
 
 首先：
 * keyValue 就是要查找的 SEL。
 * base 为要查找的区间的开。
 * count 是方法列表的方法个数，为要查找区间的末尾。
 * probe 为取出的中间数。
 
 假设，当第一次进入 for 循环，并且 count = 8，base = 0，那么 probe = 0 + (8 >> 1) = 0 + 4。
 接下来取出 probe 对应的 SEL -> probeValue，
 如果 keyValue == probeValue，说明找到了，返回 method_t *。
 如果 keyValue < probeValue，继续循环。
 如果 keyValue > probeValue，base = probe + 1;count--，继续循环。
 
 假设这个 keyValue > probeValue，base = 4 + 1 = 5; count-- = 7。
 继续循环，count >>= 1 -> count = 3，probe = 5 + (3 >> 1) = 5 + 1 = 6。
 取出来的位置正好是 5~8 之间，这就是二分查找法的代码实现。
 
 ## 五、log_and_fill_cache - 缓存方法
 通过二分查找法，如果找到 Method ，就会跳转到 done。
 ```swift
 Method meth = getMethodNoSuper_nolock(curClass, sel);
 // 如果找到 meth，跳转到 done
 if (meth) {
     imp = meth->imp(false);
     goto done;
 }
 ```
 
 done 的实现：
 ```swift
 done:
    if (fastpath((behavior & LOOKUP_NOCACHE) == 0)) {
#if CONFIG_USE_PREOPT_CACHES
        while (cls->cache.isConstantOptimizedCache(true)) {
            cls = cls->cache.preoptFallbackClass();
        }
#endif
        // 查找到了 sel-imp，对 sel-imp 进行缓存
        // 调用 cache_t 的 insert 方法。
        log_and_fill_cache(cls, imp, sel, inst, curClass);
    }
```
 
 log_and_fill_cache 的实现：
 ```swift
 static void
 log_and_fill_cache(Class cls, IMP imp, SEL sel, id receiver, Class implementer)
 {
 #if SUPPORT_MESSAGE_LOGGING
     if (slowpath(objcMsgLogEnabled && implementer)) {
         bool cacheIt = logMessageSend(implementer->isMetaClass(),
                                       cls->nameForLogging(),
                                       implementer->nameForLogging(),
                                       sel);
         if (!cacheIt) return;
     }
 #endif
 // 调用 insert 将 sel-imp 缓存到 buckets。
     cls->cache.insert(sel, imp, receiver);
 }
 ```
 
 如果在类中找到了 sel-imp，就会将 sel-imp 缓存到 buckets，并且在 lookUpImpOrForward 中返回 imp。
 
 ## 六、查找父类方法
 如果在当前类没有找到 sel，会去父类查找，看看父类有没有要找的 sel。
 ```swift
 // 如果没有找到，去父类查找。
 // 注意！获取父类的是写在了 if 条件判断里：(curClass = curClass->getSuperclass()) == nil)
 // 如果父类不为nil，继续往下走。
 // 找到根类的 superclass 后，进行消息转发，退出循环。
 if (slowpath((curClass = curClass->getSuperclass()) == nil)) {
     // No implementation found, and method resolver didn't help.
     // Use forwarding.
     // 没有找到，进行消息转发。
     imp = forward_imp;
     break;
 }
 ```
  
 去查找父类方法的时候，会先调用 cache_getImp 函数，此函数为快速查找缓存方法的函数。
 如果在快速查找父类缓存中查找到了 imp，会缓存到子类，并且返回 imp。
 如果没有，就继续循环，开始对父类进行慢速查找。如果还是没找到，就一直找到 NSObject(根类)。
 ```swift
 // Halt if there is a cycle in the superclass chain.
 if (slowpath(--attempts == 0)) {
     _objc_fatal("Memory corruption in class list.");
 }

 // Superclass cache.
 // 快速查找父类的缓存方法
 imp = cache_getImp(curClass, sel);
 if (slowpath(imp == forward_imp)) {
     // Found a forward:: entry in a superclass.
     // Stop searching, but don't cache yet; call method
     // resolver for this class first.
     break;
 }
 
 // 在父类中找到方法，开始进行缓存。
 if (fastpath(imp)) {
     // Found the method in a superclass. Cache it in this class.
     goto done;
 }
 ```
 
 在函数的开始有两个变量：
 ```swift
 const IMP forward_imp = (IMP)_objc_msgForward_impcache;
 IMP imp = nil;
 ```
 如果找到根类还是没找到，这个时候 imp = nil，接下来就开始把 forward_imp 赋值给 imp 并返回。进入下一个流程，消息转发流程。
 
 ## 六、cache_getImp - 快速查找缓存方法
 为什么 cache_getImp 也是快速查找缓存的方法呢？还记得在上一篇文章里讲的快速查找缓存方法的函数是什么吗。
 
 在上一篇文章讲的快速查找缓存方法的函数为 CacheLookup，我们来看一下 cache_getImp 的汇编实现。
 ```swift
 STATIC_ENTRY _cache_getImp

 GetClassFromIsa_p16 p0, 0
 CacheLookup GETIMP, _cache_getImp, LGetImpMissDynamic, LGetImpMissConstant

LGetImpMissDynamic:
 // 把 nil 赋值给 p0 并返回 p0。
 mov    p0, #0
 ret

LGetImpMissConstant:
 mov    p0, p2
 ret

 END_ENTRY _cache_getImp
 ```
 
 _cache_getImp 里会调用 CacheLookup 函数，这个不就是快速查找缓存方法的函数么。
 
 这里需要注意！_cache_getImp 调用 CacheLookup 和 _objc_msgSend 调用 CacheLookup 是有区别的。
 _objc_msgSend 里传的 Mode 为 NORMAL，MissLabelDynamic 为 __objc_msgSend_uncached。
 _cache_getImp 里传的 Mode 为 GETIMP，MissLabelDynamic 为 LGetImpMissDynamic。
 
 那么也就是缓存命中的处理和没有找到 sel 的处理不一样，缓存命中的处理可以去看源码，这里只对没有快速查找到 sel 的处理做说明。
 如果没有找到 sel，就会跳转到 LGetImpMissDynamic，看汇编 LGetImpMissDynamic 的实现，其实就是返回一个 nil。
 
 
 
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
