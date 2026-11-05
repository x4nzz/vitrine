#import <UIKit/UIKit.h>
#import "SGAIDJEngine.h"
#import "Core/SGGlass.h"

@interface SGAIDJSheetController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *promptField;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SGAIDJSheetController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    self.view.layer.cornerRadius = 24.0;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(24, 24, self.view.bounds.size.width - 48, 30)];
    title.text = @"AI DJ & Martini";
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    [self.view addSubview:title];

    self.promptField = [[UITextField alloc] initWithFrame:CGRectMake(24, 72, self.view.bounds.size.width - 48, 44)];
    self.promptField.placeholder = @"What do you want to hear? (e.g. Late night R&B)";
    self.promptField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    self.promptField.textColor = [UIColor whiteColor];
    self.promptField.layer.cornerRadius = 12;
    self.promptField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.promptField.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:self.promptField];

    UIButton *generateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    generateBtn.frame = CGRectMake(24, 130, self.view.bounds.size.width - 48, 44);
    generateBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.80 blue:0.45 alpha:1.0];
    [generateBtn setTitle:@"Drop the Beat" forState:UIControlStateNormal];
    [generateBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    generateBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    generateBtn.layer.cornerRadius = 12;
    [generateBtn addTarget:self action:@selector(onGenerateTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:generateBtn];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 190, self.view.bounds.size.width - 48, 60)];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
}

- (void)onGenerateTapped {
    [self.promptField resignFirstResponder];
    self.statusLabel.text = @"Consulting your AI DJ...";
    
    [[SGAIDJEngine sharedEngine] generateSessionForPrompt:self.promptField.text
                                           includeCurrent:YES
                                               completion:^(NSString *djMessage, NSArray<NSString *> *trackURIs, NSError *error) {
        if (error) {
            self.statusLabel.text = error.localizedDescription;
            return;
        }
        self.statusLabel.text = [NSString stringWithFormat:@"\"%@\"\nQueued %lu tracks!", djMessage, (unsigned long)trackURIs.count];
        [[SGAIDJEngine sharedEngine] queueTracks:trackURIs];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end
