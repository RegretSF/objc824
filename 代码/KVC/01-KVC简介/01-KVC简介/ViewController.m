//
//  ViewController.m
//  01-KVC简介
//
//  Created by TT-Fangss on 2021/9/23.
//

#import "ViewController.h"
#import "SHClass.h"

@interface ViewController ()
@property (nonatomic, strong) SHClass *myClass;
@property (nonatomic, strong) NSMutableArray *arrayM;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.arrayM = [NSMutableArray arrayWithObjects:@"111", @"222", @"333", @"444", @"555", nil];
    
//    [self ordinaryFunction];
//    [self keyValueCodingFunction];
//    [self collectionOperators];
    [self nonObjectValues];
}
#pragma mark: - 普通赋值方式
- (void)ordinaryFunction {
    self.myClass = [[SHClass alloc] init];
    self.myClass.student = [[SHStudent alloc] init];
    self.myClass.teacher = [[SHTeacher alloc] init];
    self.myClass.student.name = @"小明";
    self.myClass.student.age = 18;
    self.myClass.teacher.name = @"张三";
    self.myClass.teacher.age = 28;
    NSLog(@"student - name：%@，age：%ld", self.myClass.student.name, (long)self.myClass.student.age);
    NSLog(@"teacher - name：%@，age：%ld", self.myClass.teacher.name, (long)self.myClass.teacher.age);
}

#pragma mark: - Key - Value Coding 的方式
- (void)keyValueCodingFunction {
    /*
     KVC（Key-Value Coding）:
      1. KVC是一种由NSKeyValueCoding非正式协议启用的机制，对象采用该机制来提供对其属性的间接访问。
         当对象符合键值编码时，其属性可通过字符串参数通过简洁、统一的消息传递接口进行寻址。这种间接访问
         机制补充了实例变量及其相关访问​​器方法提供的直接访问。
      
      2. 通常使用访问器方法来访问对象的属性。get 访问器（或 getter）返回属性的值。set 访问器（或 setter）设置属性的值。
         在 Objective-C 中，您还可以直接访问属性的底层实例变量。以任何这些方式访问对象属性都很简单，但需要调用特定于属性的方法或变量名称。
         随着属性列表的增长或变化，访问这些属性的代码也必须如此。相比之下，符合键值编码的对象提供了一个简单的消息传递接口，该接口在其所有属性中保持一致。
     
     一、访问对象属性：
        1.使用 key 获取属性值的方法：
            valueForKey:                 - 返回由 key 参数命名的属性的值。 如果根据访问器搜索模式中描述的规则无法找到由 key 命名的属性，则对象向自身发送 valueForUndefinedKey: 消息。 valueForUndefinedKey: 的默认实现会引发 NSUndefinedKeyException，但子类可能会覆盖此行为并更优雅地处理这种情况。
     
            valueForKeyPath:             - 返回相对于接收器的指定 keyPath 的值。 keyPath序列中任何不符合特定 key 的键值编码的对象（即 valueForKey: 的默认实现无法找到访问器方法）都会接收 valueForUndefinedKey: 消息。
     
            dictionaryWithValuesForKeys: - 返回相对于接收者的 key 数组的值。 该方法为数组中的每个 key 调用 valueForKey:。 返回的 NSDictionary 包含数组中所有 key 的值。
     
        注意：当您使用 keyPath 来查找属性时，如果 keyPath 中除最后一个 key 之外的任何 key 是一对多关系（即它引用一个集合，比如 NSArray），则返回的值是一个包含键的所有值的集合。
     
        2.使用 key 设置属性值的方法：
            setValue:forKey:                - 通过 key 设置对象属性值。 setValue:forKey: 的默认实现自动解包表示标量和结构的 NSNumber 和 NSValue 对象，并将它们分配给属性。如果指定的 key 对应于接收 setter 调用的对象没有的属性，则该对象向自身发送 setValue:forUndefinedKey: 消息。 setValue:forUndefinedKey: 的默认实现会引发 NSUndefinedKeyException。 但是，子类可以覆盖此方法以自定义方式处理请求。
     
            setValue:forKeyPath:            - 在相对于接收器的指定keyPath上设置给定值。keyPath 序列中不符合特定 key 的键值编码的任何对象都会收到 setValue:forUndefinedKey: 消息。
     
            setValuesForKeysWithDictionary: - 使用指定字典中的 value 设置接收器的属性，使用字典 key 来标识属性。默认实现调用setValue:forKey:为每个 key 对应的 value 赋值，根据需要用 nil 替换 NSNull 对象。。
     
            注：在默认实现中，当您尝试将非对象属性设置为 nil 值时，符合键值编码的对象会向自身发送一条 setNilValueForKey: 消息。 setNilValueForKey: 的默认实现会引发 NSInvalidArgumentException，但对象可能会覆盖此行为以替代默认值或标记值。
     
     访问集合属性：
        1.NSArray:      mutableArrayValueForKey:            - 返回一个行为类似于NSMutableArray对象的代理对象。
                        mutableArrayValueForKeyPath:        - 返回一个行为类似于NSMutableArray对象的代理对象。
     
        2.NSSet:        mutableSetValueForKey:              - 返回一个行为类似于NSMutableSet对象的代理对象。
                        mutableSetValueForKeyPath:          - 返回一个行为类似于NSMutableSet对象的代理对象。
     
        3.NSOrderedSet: mutableOrderedSetValueForKey:       - 返回一个行为类似于NSMutableOrderedSet对象的代理对象。
                        mutableOrderedSetValueForKeyPath:   - 返回一个行为类似于NSMutableOrderedSet对象的代理对象。
     
        当对代理对象进行操作、向其中添加对象、从中删除对象或替换其中的对象时，协议的默认实现会相应地修改底层属性。
        使用场景：这些方法一般是在使用观察者的时候会用到，举个例子：当想通过观察者观察 NSMutableArray 里元素的变化时，可以通过mutableArrayValueForKey:或者mutableArrayValueForKeyPath:方法返回的数组对象进行增删查改操作，就可以观察到NSMutableArray的变化
     */
    
    self.myClass = [[SHClass alloc] init];
    
    [self.myClass setValue:[[SHStudent alloc] init] forKey:@"student"];
    [self.myClass setValue:[[SHTeacher alloc] init] forKey:@"teacher"];

    [self.myClass setValue:@"小明" forKeyPath:@"student.name"];
    [self.myClass setValue:@18 forKeyPath:@"student.age"];
    [self.myClass.teacher setValue:@"张三" forKeyPath:@"name"];
    [self.myClass.teacher setValue:@28 forKeyPath:@"age"];

    NSLog(@"student - name：%@，age：%@", [self.myClass valueForKeyPath:@"student.name"],
                                         [self.myClass valueForKeyPath:@"student.age"]);
    NSLog(@"teacher - name：%@，age：%@", [self.myClass.teacher valueForKey:@"name"],
                                         [self.myClass.teacher valueForKey:@"age"]);
    
    [self.myClass setValuesForKeysWithDictionary:@{@"student": [[SHStudent alloc] init], @"teacher": [[SHTeacher alloc] init]}];
    [self.myClass.student setValuesForKeysWithDictionary:@{@"name": @"小王", @"age": @17}];
    [self.myClass.teacher setValuesForKeysWithDictionary:@{@"name": @"李四", @"age": @27}];
    
    NSLog(@"student：%@", [self.myClass.student dictionaryWithValuesForKeys:@[@"name", @"age"]]);
    NSLog(@"teacher：%@", [self.myClass.teacher dictionaryWithValuesForKeys:@[@"name", @"age"]]);
    
}

#pragma mark: - 集合运算符
- (void)collectionOperators {
    /*
     简介：
     1.当您发送符合键值编码的对象 valueForKeyPath: 消息时，您可以在keyPath中嵌入一个集合运算符。以符号(@)开头的小关键字，它指定 getter 在返回数据之前应执行的以某种方式操作数据的操作。 NSObject 提供的 valueForKeyPath: 的默认实现实现了这个行为。

     2.当keyPath包含集合运算符时，运算符之前的keyPath的任何部分（称为left key path）指定相对于消息接收者要对其进行操作的集合。如果将消息直接发送到集合对象，例如 NSArray 实例，则 left key path 可能会被省略。

     3.操作符后面的keyPath部分，称为right key path，指定操作符应该处理的集合中的属性。除了@count 之外的所有集合运算符都需要一个正确的keyPath
     
     集合运算符表现出三种基本类型的行为：
     聚合运算符(Aggregation Operators):以某种方式合并集合的对象，并返回一个对象，该对象通常与right key path中命名的属性的数据类型相匹配。@count是一个例外，它没有正确的关键路径并始终将返回一个NSNumber实例。

     数组运算符(Array Operators):返回一个NSArray实例，其中包含命名集合中保存的对象的某些子集。

     嵌套运算符(Nesting Operators):处理包含其他集合的集合，并根据运算符返回一个NSArrayorNSSet实例，该实例以某种方式组合嵌套集合的对象。
     
     
     聚合运算符：
     
     @avg：求平均值（当指定@avg 运算符时，valueForKeyPath: 读取集合中每个元素的right key path指定的属性，将其转换为双精度值（用 0 替换 nil 值），并计算这些值的算术平均值。 然后它返回存储在 NSNumber 实例中的结果。）
     
     @count：集合中对象的个数（当指定 @count 运算符时， valueForKeyPath: 返回 NSNumber 实例中集合中的对象数。 忽略正确的keyPath如果存在）。）
     
     @max：取最大值（当指定@max 运算符时，valueForKeyPath: 在以正确keyPath命名的集合条目中搜索并返回最大的一个。 搜索使用 compare: 方法进行比较，该方法由许多 Foundation 类（例如 NSNumber 类）定义。 因此，由right key path指定的属性必须持有一个对该消息做出有意义响应的对象。 搜索忽略 nil 值的集合条目。）
     
     @min：取最小值（当指定@min 运算符时， valueForKeyPath: 在以正确的keyPath命名的集合条目中搜索并返回最小的一个。 搜索使用 compare: 方法进行比较，该方法由许多 Foundation 类（例如 NSNumber 类）定义。 因此，由right key path指定的属性必须持有一个对该消息做出有意义响应的对象。 搜索忽略 nil 值的集合条目。）
     
     @sum：求和（当指定 @sum 运算符时， valueForKeyPath: 读取由集合中每个元素的right key path指定的属性，将其转换为双精度值（用 0 替换 nil 值），并计算这些值的总和。 然后它返回存储在 NSNumber 实例中的结果。）
     
     数组运算符：
     
     @distinctUnionOfObjects：返回操作对象指定属性的集合-去重（当您指定@distinctUnionOfObjects运算符时，valueForKeyPath:创建并返回一个数组，该数组包含与right key path指定的属性对应的集合的不同对象。）
     
     @unionOfObjects：返回操作对象指定属性的集合（当您指定@unionOfObjects运算符时，valueForKeyPath:创建并返回一个数组，该数组包含与right key path指定的属性对应的集合的所有对象。与@distinctUnionOfObjects不同，重复的对象不会被删除。）
     
     
     嵌套运算符：
     @distinctUnionOfArrays：返回操作对象指定属性的集合-去重（当您指定@distinctUnionOfArrays运算符时，valueForKeyPath:创建并返回一个数组，该数组包含与right key path指定的属性对应的所有集合的组合的不同对象。）
     
     @unionOfArrays：返回操作对象指定属性的集合（当您指定@unionOfArrays操作符时，valueForKeyPath:创建并返回一个数组，该数组包含与right key path指定的属性对应的所有集合的组合的所有对象，不删除重复项。）
     
     @distinctUnionOfSets：返回操作对象指定属性的集合-去重（当您指定@distinctUnionOfSets操作符时，valueForKeyPath:创建并返回一个NSSet对象，该对象包含与右键路径指定的属性对应的所有集合的组合的不同对象。这个运算符的行为就像@distinctUnionOfArrays，除了它需要一个包含对象的 NSSet 实例的 NSSet 实例而不是 NSArray 实例的 NSArray 实例。 此外，它返回一个 NSSet 实例。 假设示例数据已存储在集合中而不是数组中，示例调用和结果与@distinctUnionOfArrays 显示的相同。）
     */
    
    [self aggregationOperator];
    [self arrayOperator];
    [self arrayNesting];
    [self setNesting];
}

// @avg、@count、@max、@min、@sum
- (void)aggregationOperator{
    NSMutableArray *personArray = [NSMutableArray array];
    for (int i = 0; i < 6; i++) {
        SHStudent *student = [SHStudent new];
        NSDictionary* dict = @{
                               @"name":@"Tom",
                               @"age":@(18+i),
                               @"courseArr":@[@"语文"],
                               @"length":@(175 + 2*arc4random_uniform(6)),
                               };
        [student setValuesForKeysWithDictionary:dict];
        [personArray addObject:student];
    }
    NSLog(@"%@", [personArray valueForKey:@"length"]);
    
    /// 平均身高
    float avg = [[personArray valueForKeyPath:@"@avg.length"] floatValue];
    NSLog(@"%f", avg);
    
    int count = [[personArray valueForKeyPath:@"@count.length"] intValue];
    NSLog(@"%d", count);
    
    int sum = [[personArray valueForKeyPath:@"@sum.length"] intValue];
    NSLog(@"%d", sum);
    
    int max = [[personArray valueForKeyPath:@"@max.length"] intValue];
    NSLog(@"%d", max);
    
    int min = [[personArray valueForKeyPath:@"@min.length"] intValue];
    NSLog(@"%d", min);
}

// 数组操作符 @distinctUnionOfObjects @unionOfObjects
- (void)arrayOperator{
    NSMutableArray *personArray = [NSMutableArray array];
    for (int i = 0; i < 6; i++) {
        SHStudent *student = [SHStudent new];
        NSDictionary* dict = @{
                               @"name":@"Tom",
                               @"age":@(18+i),
                               @"courseArr":@[@"语文"],
                               @"length":@(175 + 2*arc4random_uniform(6)),
                               };
        [student setValuesForKeysWithDictionary:dict];
        [personArray addObject:student];
    }
    NSLog(@"%@", [personArray valueForKey:@"length"]);
    // 返回操作对象指定属性的集合
    NSArray* arr1 = [personArray valueForKeyPath:@"@unionOfObjects.length"];
    NSLog(@"arr1 = %@", arr1);
    // 返回操作对象指定属性的集合 -- 去重
    NSArray* arr2 = [personArray valueForKeyPath:@"@distinctUnionOfObjects.length"];
    NSLog(@"arr2 = %@", arr2);
    
}

// 嵌套集合(array&set)操作 @distinctUnionOfArrays @unionOfArrays @distinctUnionOfSets
- (void)arrayNesting{
    
    NSMutableArray *personArray1 = [NSMutableArray array];
    for (int i = 0; i < 6; i++) {
        SHStudent *student = [SHStudent new];
        NSDictionary* dict = @{
                               @"name":@"Tom",
                               @"age":@(18+i),
                               @"courseArr":@[@"语文"],
                               @"length":@(175 + 2*arc4random_uniform(6)),
                               };
        [student setValuesForKeysWithDictionary:dict];
        [personArray1 addObject:student];
    }
    
    NSMutableArray *personArray2 = [NSMutableArray array];
    for (int i = 0; i < 6; i++) {
        SHStudent *student = [SHStudent new];
        NSDictionary* dict = @{
                               @"name":@"Tom",
                               @"age":@(18+i),
                               @"courseArr":@[@"语文"],
                               @"length":@(175 + 2*arc4random_uniform(6)),
                               };
        [student setValuesForKeysWithDictionary:dict];
        [personArray2 addObject:student];
    }
    
    // 嵌套数组
    NSArray* nestArr = @[personArray1, personArray2];
    
    NSArray* arr = [nestArr valueForKeyPath:@"@distinctUnionOfArrays.length"];
    NSLog(@"arr = %@", arr);
    
    NSArray* arr1 = [nestArr valueForKeyPath:@"@unionOfArrays.length"];
    NSLog(@"arr1 = %@", arr1);
}

- (void)setNesting{
    
    NSMutableSet *personSet1 = [NSMutableSet set];
    for (int i = 0; i < 6; i++) {
        SHStudent *student = [SHStudent new];
        NSDictionary* dict = @{
                               @"name":@"Tom",
                               @"age":@(18+i),
                               @"courseArr":@[@"语文"],
                               @"length":@(175 + 2*arc4random_uniform(6)),
                               };
        [student setValuesForKeysWithDictionary:dict];
        [personSet1 addObject:student];
    }
    NSLog(@"personSet1 = %@", [personSet1 valueForKey:@"length"]);
    
    NSMutableSet *personSet2 = [NSMutableSet set];
    for (int i = 0; i < 6; i++) {
        SHStudent *student = [SHStudent new];
        NSDictionary* dict = @{
                               @"name":@"Tom",
                               @"age":@(18+i),
                               @"courseArr":@[@"语文"],
                               @"length":@(175 + 2*arc4random_uniform(6)),
                               };
        [student setValuesForKeysWithDictionary:dict];
        [personSet2 addObject:student];
    }
    NSLog(@"personSet2 = %@", [personSet2 valueForKey:@"length"]);

    // 嵌套set
    NSSet* nestSet = [NSSet setWithObjects:personSet1, personSet2, nil];
    // 交集
    NSArray* arr1 = [nestSet valueForKeyPath:@"@distinctUnionOfSets.length"];
    NSLog(@"arr1 = %@", arr1);
}

#pragma mark: - 表示非对象值
- (void)nonObjectValues {
    /*
     NSObject使用对象和非对象属性 提供的键值编码协议方法的默认实现。默认实现会自动在对象参数或返回值与非对象属性之间进行转换。这允许基于键的 getter 和 setter 的签名保持一致，即使存储的属性是标量或结构。
     当调用协议的 getter 时，例如 valueForKey:，默认实现会根据访问器搜索模式中描述的规则确定为指定键提供值的特定访问器方法或实例变量。 如果返回值不是一个对象，getter 使用这个值来初始化一个 NSNumber 对象（对于标量）或 NSValue 对象（对于结构）并返回它。
     类似地，默认情况下，setValue:forKey: 之类的 setter 确定属性的访问器或实例变量所需的数据类型，给定一个特定的键。 如果数据类型不是对象，setter 首先向传入的值对象发送一个适当的 <type>Value 消息以提取底层数据，并将其存储起来。
     当nil使用非对象属性的值调用键值编码协议 setter 时，setter 没有明显的一般操作过程。因此，它向setNilValueForKey:接收 setter 调用的对象发送消息。此方法的默认实现引发NSInvalidArgumentException异常，但子类可能会覆盖此行为，如处理非对象值中所述，例如设置标记值或提供有意义的默认值。
     */
    
    self.myClass = [[SHClass alloc] init];
    ThreeFloats floats = {1., 2., 3.};
    // 默认实现用getValue:消息解开该值，然后setThreeFloats:使用结果结构进行调用。
    NSValue* value = [NSValue valueWithBytes:&floats objCType:@encode(ThreeFloats)];
    [self.myClass setValue:value forKey:@"threeFloats"];
    NSLog(@"%0.2f, %0.2f, %0.2f", self.myClass.threeFloats.x, self.myClass.threeFloats.y, self.myClass.threeFloats.z);
    
    ThreeFloats resultFloats;
    // 默认实现valueForKey:调用threeFloatsgetter，然后返回包装在NSValue对象中的结果。
    NSValue* result = [self.myClass valueForKey:@"threeFloats"];
    [result getValue:&resultFloats];
    NSLog(@"%0.2f, %0.2f, %0.2f", resultFloats.x, resultFloats.y, resultFloats.z);
}
@end
