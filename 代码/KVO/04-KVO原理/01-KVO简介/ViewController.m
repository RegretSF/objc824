//
//  ViewController.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "ViewController.h"
#import "Person.h"
#import <objc/runtime.h>

/*
 Automatic key-value observing is implemented using a technique called isa-swizzling.

 The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.

 When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.

 You should never rely on the isa pointer to determine class membership. Instead, you should use the class method to determine the class of an object instance.
 
 自动键值观察是使用一种称为 isa-swizzling 的技术实现的。

 顾名思义，isa 指针指向维护调度表的对象的类。 该调度表主要包含指向类实现的方法的指针，以及其他数据。

 当观察者为对象的属性注册时，被观察对象的 isa 指针被修改，指向中间类而不是真正的类。 因此，isa 指针的值不一定反映实例的实际类。

 您永远不应该依赖 isa 指针来确定类成员资格。 相反，您应该使用类方法来确定对象实例的类。
 */

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) Person *p1;
@property (nonatomic, strong) Person *p2;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.p1 = [[Person alloc] init];
    self.p2 = [[Person alloc] init];
    
//    [self registerAsObserver];
}

- (void)dealloc {
    [self unregisterAsObserver];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    NSLog(@"\n-------\nkeyPath：%@，\nobject：%@，\nchange：%@，\ncontext：%@\n-------", keyPath, object, change, context);
}

- (IBAction)changedClick {
    self.p1.name = @"zhang shan";
//    self.p1.age = 18;
//    [self printSubClassOfClass:[self.p1 class]];
}

/// 打印这个这个类的子类信息
- (void)printSubClassOfClass:(Class)cls {
    int numClasses;
    Class * classes = NULL;
     
    classes = NULL;
    numClasses = objc_getClassList(NULL, 0);
     
    if (numClasses > 0 )
    {
        classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        free(classes);
    }
    
    NSMutableArray<Class> *subClasses = [NSMutableArray<Class> array];
    for (int i = 0; i < numClasses; i++) {
        Class subCls = classes[i];
        if (cls == class_getSuperclass(subCls)) {
            [subClasses addObject:subCls];
        }
    }
    
    NSLog(@"%@", subClasses);
}

- (IBAction)registerAsObserver {
    /*
     通过 printObjectInfo 的打印发现：
     1. p1在没有添加观察者模式前 class 对象和 metaclass 对象都是 Pseson，父类为 NSObject。
     
        添加观察者模式后 class 对象和 metaclass 对象都变成了 NSKVONotifying_Person，父类为 Person。
     
        由此可见，当观察者为对象的属性注册时，被观察对象的 isa 指针被修改，指向中间类（该类通常以 NSKVONotifying_<className> 的方式命名）。
     
        总结：所谓的“指向中间类”本质上就是把 isa 指向的 class 对象和 metaclass 对象换成了 NSKVONotifying_Person。并且，在 NSKVONotifying_Person 里实现 KVO 相关的代码。
        
        注意：上面拿到的 class 对象和 metaclass 对象都是通过 runtime 的 object_getClass 方法拿到的，如果通过 [p1 class] 的方式去获取 class 对象和 metaclass 对象的话，拿到的是 Person，这是因为 NSKVONotifying_Person 这个类重写了 class 方法，并且内部的实现可能是类似 return [Person class] 这种。
        
     2. 通过 LLDB 打印：p (IMP)<方法编号的地址>
        没有添加 KVO 之前，setName: 方法 和 setAge: 方法是 Person 在调用。
        打印结果：(IMP) $0 = 0x0000000102ee1900 (01-KVO简介`-[Person setName:] at Person.h:13)
                (IMP) $1 = 0x0000000100bf9900 (01-KVO简介`-[Person setAge:] at Person.h:14)
     
        添加 KVO 之后，setName: 方法 和 setAge: 的地址变了，并且打印发现，它调用的是 Foundation 中对应的 _NSSetObjectValueAndNotify 和 _NSSetIntValueAndNotify 函数。
        打印结果：(IMP) $2 = 0x0000000180797e00 (Foundation`_NSSetObjectValueAndNotify)
                (IMP) $3 = 0x0000000180798634 (Foundation`_NSSetIntValueAndNotify)
     
     
     3. 通过 class_copyMethodList 可以知道该中间类重写的方法
        1. 重写被监听的属性相应的 setter 方法。
            当修改 instance 对象的属性值时：
            调用 setter 对应的 _NSSet<xxx>ValueAndNotify（由setter 参数的类型决定）、willChangeValueForKey: 、super setter、didChangeValueForKey:，随后，内部会触发监听器(observer) observeValueForKeyPath:ofObject:change:context: 方法。
     
        2. 重写 class 方法。
            猜测内部的实现应该类似 return class_getSuperclass(object_getClass(self)) 这种，所以才会在添加观察者模式后调用实例方法 class 时返回的和 object_getClass 返回的 class 对象不一致，其原因可能是为了屏蔽内部实现，让开发者不要多想，用就行了。
     
        3. 重写 dealloc 方法。
            做一些收尾工作，比如将 isa 指针指回 Person。
     
        3. 会新生成的一个 _isKVOA 方法。
            猜测内部实现应该是 return YES。应该是作为使用了 KVO 的标记。
     */
    
    NSLog(@"添加 Observer 之前");
    [self.p1 printObjectInfo];
//    [self.p2 printObjectInfo];
    
    [self.p1 addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
//    [self.p1 addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    
    NSLog(@"p1 添加 Observer 之后");
    [self.p1 printObjectInfo];
//    [self.p2 printObjectInfo];
    
//    [self.p2 addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
//    [self.p2 addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
//
//    NSLog(@"p2 添加 KVO 之后");
//    [self.p1 printObjectInfo];
//    [self.p2 printObjectInfo];
}

- (IBAction)unregisterAsObserver {
    @try {
        [self.p1 removeObserver:self forKeyPath:@"name"];
//        [self.p1 removeObserver:self forKeyPath:@"age"];
        NSLog(@"p1 移除 Observer 之后");
        [self.p1 printObjectInfo];
        
//        [self.p2 removeObserver:self forKeyPath:@"name"];
//        [self.p2 removeObserver:self forKeyPath:@"age"];
        
        /*
         问：kvo观察者取消观察后，自动生成的子类是否会销毁？
         在移除观察者后，自动生成的子类不会随着观察者的移除而销毁，而是将其缓存起来，可以通过 objc_getClass 方法或者打印出 Person 的子类验证。
         */
        
        NSLog(@"检查 NSKVONotifying_Person 是否被释放");
        Class cls = objc_getClass("NSKVONotifying_Person");
        [self printMethodNamesOfClass:cls];
        NSLog(@"检查结束");
        
    } @catch (NSException *exception) {
        NSLog(@"\n------\nname：%@，\nreason：%@，\nuserInfo：%@------", exception.name, exception.reason, exception.userInfo);
    } @finally {
        NSLog(@"不管是否抛出异常，都会执行");
    }
}

- (void)printMethodNamesOfClass:(Class)cls {
    unsigned int count;
    Method *methodList = class_copyMethodList(cls, &count);
    NSMutableArray<NSString *> *methodNames = [NSMutableArray<NSString *> array];
    for (int i = 0; i < count; i++) {
        Method method = methodList[i];
        SEL selector = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        [methodNames addObject:methodName];
    }
    
    free(methodList);
    
    NSLog(@"对象的方法列表:%@", methodNames);
}
@end
