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
        _student.firstName = @"zhang";
        _student.lastName = @"shan";
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
    if ([_student.fullName isEqualToString:@"zhang shan"]) {
        _student.firstName = @"li";
        _student.lastName = @"si";
    }else if ([_student.fullName isEqualToString:@"li si"]) {
        _student.firstName = @"wang";
        _student.lastName = @"wu";
    }else if ([_student.fullName isEqualToString:@"wang wu"]) {
        _student.firstName = @"zhang";
        _student.lastName = @"shan";
    }

    _nameLabel.text = _student.fullName;
}

- (IBAction)registerAsObserver {
    [self.student addObserver:self forKeyPath:@"fullName" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}

- (IBAction)unregisterAsObserver {
    @try {
        [self.student removeObserver:self forKeyPath:@"fullName"];
    } @catch (NSException *exception) {
        NSLog(@"\n------\nname：%@，\nreason：%@，\nuserInfo：%@------", exception.name, exception.reason, exception.userInfo);
    } @finally {
        NSLog(@"不管是否抛出异常，都会执行");
    }
}

@end
