//
//  main.m
//  Objective-C运行时的改进
//
//  Created by TT-Fangss on 2021/11/16.
//

#import <Foundation/Foundation.h>

/**
 一、数据结构的变化
 类对象本身包含了最常被访问的信息：指向元类、超类和方法缓存的指针，它还有一个指向更多数据的指针，存储额外信息的地方叫做 class_ro_t。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/Class和class_ro_t.png
 class_ro_t：
“ro”代表只读，它包括像类名词，方法，协议，和实例变量的信息。Swift类和Objective-C类共享这一数据结构，所以每个Swift类也有这些数据结构。
 
 当类第一次从磁盘中加载到内存中时，它们一开始也是这样的，但一经使用，它们就会发生变化。
 
 了解这些变化之前，先了解一下 clean memory 和 dirty memory 的区别。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/clean memory 和 dirty memory.png
 clean memory：指加载后不会发生更改的内存。class_ro_t 就属于 clean memory，因为它是只读的。
 dirty memory：指在进程运行时会发生更改的内存。类结构一经使用就会变成 dirty memory，因为运行时会向它写入新的数据。例如，创建一个新的方法缓存并从类中指向它。
 
 dirty memory 比 clean memory 要昂贵得多，只要进程在运行，它就必须一直存在 。另一方面 clean memory 可以进行移除，从而节省更多的内存空间，当需要使用 clean memory 的时候系统可以从磁盘中重新加载。
 
 macOS 可以选择唤出 dirty memory，但因为 iOS 不使用 swap，所以 dirty memory 在iOS中的代价很大。
 
 dirty memory 是这个类数据被分成两部分的原因，可以保持清洁的数据越多越好，通过分离那些永远不会更改的数据，可以把大部分的类数据存储为 clean memory。
 
 虽然这些数据足以让我们开始，但运行时需要追踪每个类的更多信息，所以当一个类首次被使用，运行时会为它分配额外的存储容量。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/class_rw_t.png
 
 这个运行时分配的存储容量是 class_rw_t 用于读取-编写数据，在这个数据结构中，我们存储了只有在运行时才会生成的新信息，First Subclass，Next Sibling Class。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/First Subclass，Next Sibling Class.png
 
 例如，所有的类都会链接成一个树状结构，这是通过使用 First Subclass，Next Sibling Class 指针实现的，这允许运行时遍历当前使用的所有类，这对于使方法缓存无效非常有用。
 
 但为什么方法和属性也在只读数据中时，这里还要有方法和属性呢？
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/class_rw_t中的方法和属性.png
 
 因为它们可以在运行时进行更改，当 category 被加载时，它可以向类中添加新的方法，而且程序员可以使用运行时 API 动态的添加它们，而 class_ro_t 是只读的，所以我们需要在 class_rw_t 中追踪这些东西。
 
 现在，结果是这样做会占用相当多的内存，在任何给定的设备中都有许多类在使用，我们在 iPhone 上的整个系统中测量了大约30兆这些 class_rw_t 结构，那么我们如何缩小这些结构呢？记住，我们在读取-编写部分需要这些东西，因为它们可以在运行时进行更改，但是通过检查实际设备上的使用情况，我们发现，大约只有 10% 的类真正地更改了它们的方法。
 
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/Demangled Name.png
 只有 Swift 类会使用 demangled name 字段，并且 Swift 类并不需要这一字段，除非有东西访问它们的 Objective-C 名称时才需要。
 
 所以我们可以拆掉那些平时不用的部分，这将 class_rw_t 的大小减少了一半。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/class_rw_ext_t.png
 
 对于那些确实需要额外信息的类，我们可以分配这些扩展记录中的一个，并把它滑到类中供其使用。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/Class->class_rw_t->class_rw_ext_t->class_ro_t.png
 
 大约 90% 的类从不需要这些扩展数据，这在系统范围内可节省大约 14 MB 的内存，这些内存现在可用于更有效的用途，比如存储你的 app 的数据，因此，实际上你可以在你的 Mac 上看到这一变化带来的影响，只需要在终端机上运行一些简单的命令，现在让我们一起来看一下。
 在此我要进入我的 MacBook 的终端，我要运行一个命令，它在任何 Mac 上都可用，叫做 heap。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/heap.png
 
 它还允许你检查正在运行的进程所使用的堆内存，我将在 Mac 中的 Mail app 上运行它。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/heap Mail.png
 
 现在，如果我运行该命令，它会输出数千行，显示通过邮件进行的每个堆分配。所以，我只是要 egrep 我们今天一直谈论的 class_rw_t 类型，我还需要查询标头。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/heap Mail | egrep 'class_rw|COUNT'.png
 可以看到，我们在邮件 app 中使用了大约 9000 个这样的 class_rw_t 类型，但其中只有大约十分之一，900多一点实际上需要使用这一扩展信息。
 
 所以我们可以很容易地计算出通过这个改变所节省的内存，这是大小减半的类型。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/BYTES.png
 所以，如果我们从这个数字中减去我们必须分配给扩展类型的内存量，我们可以看到，我们节省了大约一兆字节数据的四分之一，这还只是对邮件 app 而言。如果我们在系统范围内进行扩展，对 dirty memory 而言这是真正的节省内存。
 
 现在，很多从类中获取数据的代码必须同时处理那些有扩展数据和没有扩展数据的类，当然，运行时会为你处理这一切，并且从外部看一切都像往常一样的工作，只是使用更少的内存。之所以会这样，是因为读取这些结构的代码都在运行时内并且还会同时进行更新，坚持使用这些 API 真的很重要，因为任何试图直接访问这些数据结构的代码，都将在今年(2020)的 OS 版本中停止工作，因为东西已经发生了变化，而且该代码不知道新的布局。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/Reading class data.png
 
 我们看到一些真实的代码由于这些变化而崩溃，除了你自己的代码之外，还要注意那些外部依赖性，你可能正把它们带入到你的 app 中，它们可能会在你没有意识到的情况下挖掘这些数据结构。
 
 这些结构中的所有信息都可通过官方 API 获得，有一些函数，如 class_getName 和 class_getSuperclass。
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/runtime API.png
 
 当你使用这些 API 访问信息时，你知道，无论我们在后台进行什么更改，它们都将继续工作，所有的 API 都可以在 Objective-C 运行时说明文档中找到。
 https://developer.apple.com/documentation/objectivec/objective-c_runtime
 
 二、Objective-C方法列表的变化
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/方法列表.png
 
 每一个类都附带一个方法列表，当你在类上编写新方法时，它就会被添加到列表中。运行时使用这些列表来解析消息发送。
 
 每个方法都包含三个信息。
 首先是方法的名称，或者说选择器，选择器时字符串，但它们具有唯一性，所以它们可以使用指针相等来进行比较。
 接下来时方法的类型编码，这是一个表示参数和返回类型的字符串，它不是用来发送消息的，但它时运行时 introspection 和消息 forwarding 所必需的东西。
 最后，还有一个指向方法实现的指针，方法的实际代码，当你编写一个方法时，它会编译成一个 c 函数，其中包含你的实施，然后方法列表中的 entry 会指向该函数
 
 三、tagged pointer
 0x00000001003041e0 的二进制表示如图所示：
 /Users/fatbrother/Fangss/Development/iOS/objc824/代码/02-class的原理/03-Objective-C运行时的改进/Objective-C运行时的改进/对象指针中使用的位.png
 我们把它分解成二进制表示法 我们有 64 位 然而 我们并没有真正地使用到所有这些位

 我们只在一个真正的对象指针中 使用了中间的这些位

 由于对齐要求的存在 低位始终为 0 对象必须总是位于 指针大小倍数的一个地址中

 由于地址空间有限 所以高位始终为 0 我们实际上不会用到 2^64

 这些高位和低位总是 0 所以 让我们从这些始终为 0 的位中 选择一个位并把它设置为 1

 这可以让我们立即知道 这不是一个真正的对象指针 然后我们可以给其他所有位 赋予一些其他的意义 我们称这种指针为 tagged pointer
 
 例如 我们可以在其他位中塞入一个数值 只要我们想教 NSNumber 如何读取这些位 并让运行时适当地处理 tagged pointer 系统的其他部分就可以 把这些东西当做对象指针来处理 并且永远不会知道其中的区别

 这样可以节省我们为每一种类似情况 分配一个小数字对象的代价 这是一个重大的改进

 */

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
    }
    return 0;
}
