//
//  ViewController.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/9.
//

#import "ViewController.h"
#import "Person.h"
#import "AddObserverViewController.h"
#import "NSObject+SHKVO.h"
#import <objc/runtime.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) Person *p1;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"自定义 KVO";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"下一页" style:UIBarButtonItemStylePlain target:self action:@selector(nextClick)];
    
    self.p1 = [[Person alloc] init];
    
    [self registerAsObserver];
}

- (void)nextClick {
    AddObserverViewController *vc = [[AddObserverViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)dealloc {
    [self unregisterAsObserver];
}

- (void)sh_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"\n-------\nkeyPath：%@，\nobject：%@，\nchange：%@，\ncontext：%@\n-------", keyPath, object, change, context);
}

- (IBAction)changedClick {
    self.p1.name = @"li si";
}

- (IBAction)registerAsObserver {
    NSLog(@"添加观察者之前");
    [self.p1 printObjectInfo];
    [self.p1 sh_addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    
    NSLog(@"添加观察者之后");
    [self.p1 printObjectInfo];
//    [self.p1 sh_addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (IBAction)unregisterAsObserver {
    @try {
        [self.p1 sh_removeObserver:self forKeyPath:@"name"];
        NSLog(@"移除观察者之后");
        [self.p1 printObjectInfo];
    } @catch (NSException *exception) {
        NSLog(@"\n------\nname：%@，\nreason：%@，\nuserInfo：%@------", exception.name, exception.reason, exception.userInfo);
    }
}

@end
