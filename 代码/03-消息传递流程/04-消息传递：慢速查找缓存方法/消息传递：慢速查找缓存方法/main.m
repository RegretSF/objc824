//
//  main.m
//  消息传递：快速查找缓存方法
//
//  Created by Fat brother on 2021/12/12.
//

#import <Foundation/Foundation.h>

/*
 objc_msgSend 函数在进行消息传递的过程中，会先进行快速查找缓存方法，快速查找缓存方法是用汇编实现，其汇编函数名为 CacheLookup 。如果 CacheLookup 函数中没有找到要匹配的方法，会跳转到 __objc_msgSend_uncached 函数。
 
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
 
 接下来，这个函数才是重点！
 
 */

/**
 二分查找：
 什么叫二分查找呢。
 举个例子：
 这里有一个区间 0～100，我需要找到 55 这个数的位置，按正常的逻辑用一个循环去遍历，也可以找到，但会有个问题，循环遍历需要一个一个的去找，会非常的消耗性能。
 如果用二分查找，是怎么查找呢。
 随便取一个数，比如 50 ，那么 50 是小于 55 。
 再取一个数，这个数是 50～100 区间内的数，比如 75，那么 75 大于 55 。
 再取一个数，50～75 区间内的数，比如 60，60 还是大于 55。
 再取一个数，50～60 区间内的数，比如 55，这个时候就找到了。
 那么通过这个二分查找呢，我们就用了 4 ，相比于循环一个一个去遍历是不是快了很多呢。
 下面的这个
 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
