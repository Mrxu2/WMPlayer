//
//  VCRotateViewController.m
//  PlayerDemo
//
//  Created by apple on 2020/6/3.
//  Copyright © 2020 DS-Team. All rights reserved.
//

#import "VCRotateViewController.h"

@interface VCRotateViewController ()<XMediaPlayerDelegate>
@property (nonatomic, strong)XMediaPlayer  *wmPlayer;
@end

@implementation VCRotateViewController
- (BOOL)shouldAutorotate{
    if (self.wmPlayer.playerModel.verticalVideo) {
           return NO;
       }
        return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
    [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationLandscapeRight) forKey:@"orientation"];
    return UIInterfaceOrientationLandscapeRight;
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(onDeviceOrientationChange:)
                                                name:UIDeviceOrientationDidChangeNotification
                                              object:nil
    ];
    WMPlayerModel *playerModel = [WMPlayerModel new];
    playerModel.title = @"这是视频标题";
    playerModel.videoURL = [NSURL URLWithString:@"http://static.tripbe.com/videofiles/20121214/9533522808.f4v.mp4"];
    playerModel.videoURL = [NSURL URLWithString:@"https://www.apple.com/105/media/cn/mac/family/2018/46c4b917_abfd_45a3_9b51_4e3054191797/films/bruce/mac-bruce-tpl-cn-2018_1280x720h.mp4"];
    
    self.wmPlayer = [[XMediaPlayer alloc] initWithFrame:CGRectMake(0, 34, self.view.frame.size.width, self.view.frame.size.width*(9.0/16))];
    self.wmPlayer.delegate = self;
    self.wmPlayer.playerModel =playerModel;
    [self.view addSubview:self.wmPlayer];
    [self.wmPlayer play];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapClick)];
    [self.wmPlayer addGestureRecognizer:tap];
}
-(void)tapClick{
    if (self.wmPlayer.playerStatus == XMediaPlayerStatusStopped) {
        [self.wmPlayer play];

    }else if(self.wmPlayer.playerStatus == XMediaPlayerStatusPlaying){
        [self.wmPlayer pause];
    }else{
        [self.wmPlayer pause];
    }
}
- (void)changeInterfaceOrientation:(UIInterfaceOrientation)ori {
    @try {
            // ios16使用新的api
            if (@available(iOS 16.0, *)) {
                UIInterfaceOrientationMask oriMask = UIInterfaceOrientationMaskPortrait;
                if (ori == UIDeviceOrientationPortrait) {
                    oriMask = UIInterfaceOrientationMaskPortrait;
                } else if (ori == UIDeviceOrientationLandscapeLeft) {
                    oriMask = UIInterfaceOrientationMaskLandscapeRight;
                } else if (ori == UIDeviceOrientationLandscapeRight) {
                    oriMask = UIInterfaceOrientationMaskLandscapeLeft;
                } else {
                    return;
                }
                // 防止appDelegate supportedInterfaceOrientationsForWindow方法不调用
                UINavigationController *nav = self.navigationController;
                SEL selUpdateSupportedMethod = NSSelectorFromString(@"setNeedsUpdateOfSupportedInterfaceOrientations");
                if ([nav respondsToSelector:selUpdateSupportedMethod]) {
                    (((void (*)(id, SEL))[nav methodForSelector:selUpdateSupportedMethod])(nav, selUpdateSupportedMethod));
                }
                
                NSArray *array = [[[UIApplication sharedApplication] connectedScenes] allObjects];
                UIWindowScene *ws = (UIWindowScene *)array.firstObject;
                Class GeometryPreferences = NSClassFromString(@"UIWindowSceneGeometryPreferencesIOS");
                id geometryPreferences = [[GeometryPreferences alloc] init];
                [geometryPreferences setValue:@(oriMask) forKey:@"interfaceOrientations"];
                SEL selGeometryUpdateMethod = NSSelectorFromString(@"requestGeometryUpdateWithPreferences:errorHandler:");
                void (^ErrorBlock)(NSError *error) = ^(NSError *error){
                      NSLog(@"iOS 16 转屏Error: %@",error);
                };
                if ([ws respondsToSelector:selGeometryUpdateMethod]) {
                    (((void (*)(id, SEL,id,id))[ws methodForSelector:selGeometryUpdateMethod])(ws, selGeometryUpdateMethod,geometryPreferences,ErrorBlock));
                }
//                [self onDeviceOrientationChange:nil];
            } else {
                
                if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
                    SEL selector = NSSelectorFromString(@"setOrientation:");

                    if ([UIDevice currentDevice].orientation == ori) {
                        NSInvocation *invocationUnknow = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
                        [invocationUnknow setSelector:selector];
                        [invocationUnknow setTarget:[UIDevice currentDevice]];
                        UIDeviceOrientation unKnowVal = UIDeviceOrientationUnknown;
                        [invocationUnknow setArgument:&unKnowVal atIndex:2];
                        [invocationUnknow invoke];
                    }
                    
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
                    [invocation setSelector:selector];
                    [invocation setTarget:[UIDevice currentDevice]];
                    UIDeviceOrientation val = ori;
                    [invocation setArgument:&val atIndex:2];
                    [invocation invoke];
                }
            }

        } @catch (NSException *exception) {
            
        } @finally {
            
        }
}
//旋转屏幕通知方法
- (void)onDeviceOrientationChange:(NSNotification *)notification{
    
   
}
- (void)dealloc{
    [self.wmPlayer pause];
       [self.wmPlayer removeFromSuperview];
       self.wmPlayer = nil;    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"DetailViewController dealloc");
}
@end
