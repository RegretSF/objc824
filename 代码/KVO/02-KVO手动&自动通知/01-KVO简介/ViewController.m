//
//  ViewController.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "ViewController.h"
#import "Person.h"

@interface ViewController ()
@property (nonatomic, strong) Person *student;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@end

@implementation ViewController

- (Person *)student {
    if (!_student) {
        _student = [[Person alloc] init];
        _student.name = @"zhang shan";
        _nameLabel.text = _student.name;
    }
    return _student;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self registerAsObserver];
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
    if ([_student.name isEqualToString:@"zhang shan"]) {
        [_student setValue:@"li si" forKey:@"name"];
    }else if ([_student.name isEqualToString:@"li si"]) {
        [_student setValue:@"wang wu" forKey:@"name"];
    }else if ([_student.name isEqualToString:@"wang wu"]) {
        [_student setValue:@"zhang shan" forKey:@"name"];
    }
    
    _nameLabel.text = _student.name;
}

- (IBAction)removeCourse {
    NSMutableArray *courses = [self.student mutableArrayValueForKey:@"courses"];
    [courses removeLastObject];
}

- (IBAction)addCourse {
    NSMutableArray *courses = [self.student mutableArrayValueForKey:@"courses"];
    [courses addObject:@"biology"];
}

- (IBAction)registerAsObserver {
    [self.student addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    [self.student addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    [self.student addObserver:self forKeyPath:@"courses" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}

- (IBAction)unregisterAsObserver {
    @try {
        [self.student removeObserver:self forKeyPath:@"name"];
        [self.student removeObserver:self forKeyPath:@"age"];
        [self.student removeObserver:self forKeyPath:@"courses"];
    } @catch (NSException *exception) {
        NSLog(@"\n------\nname：%@，\nreason：%@，\nuserInfo：%@------", exception.name, exception.reason, exception.userInfo);
    } @finally {
        NSLog(@"不管是否抛出异常，都会执行");
    }
}

@end
