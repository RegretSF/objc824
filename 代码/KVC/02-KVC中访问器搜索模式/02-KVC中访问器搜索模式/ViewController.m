//
//  ViewController.m
//  02-KVC中访问器搜索模式
//
//  Created by TT-Fangss on 2021/9/26.
//

#import "ViewController.h"
#import "SHPerson.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    /*
     NSObject 提供的 NSKeyValueCoding 协议的默认实现使用一组明确定义的规则将基于 key 的访问器调用映射到对象的底层属性。 这些协议方法使用一个关键参数来搜索它们自己的对象实例以查找访问器、实例变量和遵循某些命名约定的相关方法。
     */
    
    [self searchPatternForTheBasicSetter];
//    [self searchPatternForTheBasicGetter];
//    [self searchPatternForMutableArrays];
}

#pragma mark: - Getter 的基本搜索模式
- (void)searchPatternForTheBasicGetter {
    /*
     valueForKey: 的默认实现，给定一个 key 参数作为输入，执行以下过程，从接收 valueForKey: 调用的类实例中操作。
     
     1.查找简单的访问器方法
     在实例中按顺序查找 get<Key>、<key>、is<Key>、_<key>,如果找到，调用它并使用结果继续执行步骤 5，否则继续下一步。
     
     2.查找NSArray相关的方法
     如果没有找到步骤 1 的方法，则在实例中查找这三个方法，countOf<Key>、objectIn<Key>AtIndex:、<key>AtIndexes:。
     如果找到其中的第一个和至少其他两个中的一个，则创建一个集合代理对象，该对象响应所有 NSArray 方法并返回该对象。 否则，继续执行步骤 3。
     代理对象随后将它接收到的任何 NSArray 消息转换为 countOf<Key>、objectIn<Key>AtIndex: 和 <key>AtIndexes: 消息的某种组合，并将其转换为创建它的键值编码兼容对象。 如果原始对象还实现了一个可选方法，其名称类似于 get<Key>:range:，则代理对象也会在适当的时候使用它。
     
     3.查找NSSet相关的方法
     如果没有找到步骤 1 或步骤 2 的方法，则查找名为 countOf<Key>、enumeratorOf<Key> 和 memberOf<Key>: 的三个方法。
     如果找到这三个方法，则创建一个集合代理对象，该对象响应所有 NSSet 方法并返回该对象。 否则，继续执行步骤 4。
     这个代理对象随后将它接收到的任何 NSSet 消息转换为 countOf<Key>、enumeratorOf<Key> 和 memberOf<Key> 的某种组合：消息到创建它的对象。
     
     4.间接访问成员变量
     如果通过 1、2、3 步骤依次查找还是没有找到，并且如果接收者的类方法accessInstanceVariables直接返回YES，则搜索名为_<key>、_is<Key>、<key>或is<Key>的实例变量， 以该顺序。 如果找到，直接获取实例变量的值并进行步骤5，否则进行步骤6。
     
     5.返回值处理
     如果检索到的属性值是一个对象指针，只需返回结果即可。
     如果该值是 NSNumber 支持的标量类型，则将其存储在 NSNumber 实例中并返回。
     如果结果是 NSNumber 不支持的标量类型，则转换为 NSValue 对象并返回。
     
     6.异常处理
     如果以上所有的方法都查找不到，调用 valueForUndefinedKey:。 默认情况下，这会抛出异常，但可以重写valueForUndefinedKey:方法自定义处理方式。
     
     
     */
    
    // 普通类型
    SHPerson *p = [[SHPerson alloc] init];
//    [p setValue:@"jack" forKey:@"name"];
//    NSString *name = [p valueForKey:@"name"];
//    NSLog(@"完毕！ -- %@", name);
    
    // KVC - 集合类型
    p.arr = @[@"pen0", @"pen1", @"pen2", @"pen3"];
    NSArray *array = [p valueForKey:@"pens"];
//    NSLog(@"%@",[array objectsAtIndexes:[NSIndexSet indexSetWithIndex:1]]);
//    NSLog(@"%@",[array objectAtIndex:0]);
//    NSLog(@"%d",[array containsObject:@"pen0"]);
//
    // set 集合
    p.set = [NSSet setWithArray:array];
    NSSet *set = [p valueForKey:@"books"];
    [set enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSLog(@"set遍历 %@",obj);
    }];
    
    NSLog(@"%@",[set member:@"pen2"]);
}

#pragma mark: - Setter 的基本搜索模式
- (void)searchPatternForTheBasicSetter {
    /*
     setValue:forKey: 的默认实现，给定 key 和 value 参数作为输入，尝试将名为 key 的属性设置 value
     
     1.查找简单的访问器方法
     按顺序查找名为 set<Key>: 、_set<Key> 或 setIs<Key> 的第一个访问器。 如果找到，则使用输入值（或根据需要展开的值）调用它并完成。
     
     2.间接访问成员变量
     如果没有找到步骤 1 的方法，并且类方法 accessInstanceVariablesDirectly 返回 YES，则按顺序查找名称类似于 _<key>、_is<Key>、<key> 或 is<Key> 的实例变量。 如果找到，直接使用输入值（或解包值）设置变量并完成。
     3.异常处理
     在未找到访问器或实例变量时，调用 setValue:forUndefinedKey:。 默认情况下，这会引发异常，但 NSObject 的子类可能会提供特定于键的行为。
     */
    
    SHPerson *p = [[SHPerson alloc] init];
    [p setValue:@"jack" forKey:@"name"];
//    NSLog(@"%@ - %@ - %@ - %@", p->_name, p->_isName, p->name, p->isName);
//    NSLog(@"%@ - %@ - %@", p->_isName, p->name, p->isName);
//    NSLog(@"%@ - %@", p->name, p->isName);
//    NSLog(@"%@ ", p->isName);
    NSLog(@"完毕！");
}

#pragma mark: - 可变数组的搜索模式
- (void)searchPatternForMutableArrays {
    /*
     mutableArrayValueForKey: 的默认实现，给定一个 key 参数作为输入，为接收访问器调用的对象内名为 key 的属性返回一个可变代理数组，使用以下过程：
     
     1.寻找一对名称类似 insertObject:in<Key>AtIndex: 和 removeObjectFrom<Key>AtIndex:（分别对应于 NSMutableArray 原始方法 insertObject:atIndex: 和 removeObjectAtIndex:）的方法，或名称类似 insert<Key>:atIndexes:  的方法和 remove<Key>AtIndexes:（对应于 NSMutableArray 的 insertObjects:atIndexes: 和 removeObjectsAtIndexes: 方法）。
     
     如果对象至少有一个插入方法和至少一个删除方法，则返回一个代理对象，该对象通过发送 insertObject:in<Key>AtIndex 的某种组合来响应 NSMutableArray 消息：, removeObjectFrom<Key>AtIndex:、insert<Key>:atIndexes: 和 remove<Key>AtIndexes: 消息发送到 mutableArrayValueForKey: 的原始接收者。
     
     当接收到 mutableArrayValueForKey: 消息的对象也实现了一个可选的替换对象方法，其名称类似于 replaceObjectIn<Key>AtIndex:withObject: 或 replace<Key>AtIndexes:with<Key>:，代理对象在适当的时候也会利用这些以获得最佳性能。
     
     2.如果对象没有可变数组方法，则查找名称与模式 set<Key>: 匹配的访问器方法。 在这种情况下，通过向 mutableArrayValueForKey: 的原始接收者发出 set<Key>: 消息，返回一个响应 NSMutableArray 消息的代理对象。
     
     3.如果既没有找到可变数组方法，也没有找到访问器，并且如果接收者的类对 accessInstanceVariablesDirectly 响应 YES，则按该顺序搜索名称类似于 _<key> 或 <key> 的实例变量。
     
     如果找到这样的实例变量，则返回一个代理对象，该对象将它接收到的每个 NSMutableArray 消息转发给实例变量的值，该值通常是 NSMutableArray 或其子类之一的实例。
     
     4.如果所有其他方法都失败，则返回一个可变集合代理对象，该对象在收到 NSMutableArray 消息时向 mutableArrayValueForKey: 消息的原始接收者发出 valueForUndefinedKey: 消息。
     
     在未找到访问器或实例变量时，调用 valueForUndefinedKey:。 默认情况下，这会引发异常，但 NSObject 的子类可能会提供特定于键的行为。
     
     应用场景
     当我们需要对可变数组元素的改变进行观察时，可以用 mutableArrayValueForKey: 和 mutableArrayValueForKeyPath: 方法返回的可变数组对象进行增删改。
     
     
     另外，苹果的文档还有对 NSMutableOrderedSet 和 NSMutableSet 的 的搜索模式介绍，在思路上和 NSMutableArray 差不多。
     NSMutableOrderedSet、NSMutableSet 的搜索模式地址：https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/SearchImplementation.html#//apple_ref/doc/uid/20000955-CJBBBFFA
     */
    
    SHPerson *p = [[SHPerson alloc] init];
//    p.arrayM = [NSMutableArray arrayWithArray:@[@"p1", @"p2", @"p3", @"p4", @"p5"]];
//    p->arrayM = [NSMutableArray arrayWithArray:@[@"p1", @"p2", @"p3", @"p4", @"p5"]];
    
    NSMutableArray *arrayM = [p mutableArrayValueForKey:@"arrayM"];
//    [arrayM addObject:@"p8"];
//    [arrayM insertObject:@"p6" atIndex:4];
//    [arrayM removeObjectAtIndex:0];
//    [arrayM replaceObjectAtIndex:3 withObject:@"p7"];
    
    NSLog(@"arrayM: %@", arrayM);
}
@end
