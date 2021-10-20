//
//  AddObserverViewController.m
//  01-KVO简介
//
//  Created by TT-Fangss on 2021/10/13.
//

#import "AddObserverViewController.h"
#import "Person.h"
#import "NSObject+SHKVO.h"
#import <objc/runtime.h>

@interface AddObserverViewController ()
@property (nonatomic, strong) Person *student;
@end

@implementation AddObserverViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = [NSString stringWithFormat:@"第%ld", self.navigationController.viewControllers.count];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"下一页" style:UIBarButtonItemStylePlain target:self action:@selector(nextClick)];
    
    self.view.backgroundColor = [UIColor colorWithRed:(CGFloat)arc4random_uniform(256.0) / 255.0 green:(CGFloat)arc4random_uniform(256.0) / 255.0 blue:(CGFloat)arc4random_uniform(256.0) / 255.0 alpha:1.0];
    self.student = [[Person alloc] init];
    [self registerAsObserver];
}

- (void)dealloc {
    NSLog(@"%s", __func__);
//    [self.student sh_removeObserver:self forKeyPath:@"name"];
}

- (void)nextClick {
    AddObserverViewController *vc = [[AddObserverViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)registerAsObserver {
    [self.student sh_addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

- (void)unregisterAsObserver {
    @try {
        [self.student sh_removeObserver:self forKeyPath:@"name"];
    } @catch (NSException *exception) {
        NSLog(@"\n------\nname：%@，\nreason：%@，\nuserInfo：%@------", exception.name, exception.reason, exception.userInfo);
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.student.name = @"li si";
}

- (void)sh_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"\n-------\nkeyPath：%@，\nobject：%@，\nchange：%@，\ncontext：%@\n-------", keyPath, object, change, context);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
