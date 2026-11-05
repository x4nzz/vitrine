#import <UIKit/UIKit.h>
#import "Shared/AIDJ/SGAIDJEngine.h"
#import "Shared/AIDJ/SGAIDJSheet.m"
#import "Core/SGPrefs.h"

%hook NowPlayingViewController

- (void)viewDidLoad {
    %orig;
    
    if (!SGPrefBool(@"spotifyglass.ai_dj_enabled", NO)) return;

    // Add a floating AI Sparkle / DJ button to the player controls
    UIButton *djButton = [UIButton buttonWithType:UIButtonTypeCustom];
    djButton.frame = CGRectMake(self.view.bounds.size.width - 60, 60, 44, 44);
    [djButton setImage:[UIImage systemImageNamed:@"sparkles"] forState:UIControlStateNormal];
    djButton.tintColor = [UIColor colorWithRed:0.20 green:0.80 blue:0.45 alpha:1.0];
    [djButton addTarget:self action:@selector(sg_openAIDJSheet) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:djButton];
}

%new
- (void)sg_openAIDJSheet {
    SGAIDJSheetController *sheet = [[SGAIDJSheetController alloc] init];
    sheet.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 16.0, *)) {
        sheet.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent]];
        sheet.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

%end
