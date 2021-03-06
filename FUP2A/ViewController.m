//
//  ViewController.m
//  FUP2A
//
//  Created by L on 2018/6/1.
//  Copyright © 2018年 L. All rights reserved.
//

#import "ViewController.h"
#import "FUP2ADefine.h"
#import "FUCamera.h"
#import "FUOpenGLView.h"
#import "FUManager.h"
#import "FUAvatar.h"
#import "FUP2AColor.h"
#import "FUTool.h"
#import "FUTakePhotoController.h"
#import "FUEditViewController.h"
#import "FURequestManager.h"
#import "FUHomeBarView.h"
#import "FUHistoryViewController.h"

@interface ViewController ()<
FUCameraDelegate,
UIGestureRecognizerDelegate,
FUHomeBarViewDelegate,
FUHistoryViewControllerDelegate
>
{
    CGFloat preScale; // 捏合比例
    FURenderMode renderMode ;
    BOOL loadingBundles ;
}
@property (weak, nonatomic) IBOutlet UIImageView *lanchImage;

@property (nonatomic, strong) FUCamera *camera ;
@property (weak, nonatomic) IBOutlet FUOpenGLView *displayView;
@property (weak, nonatomic) IBOutlet FUOpenGLView *preView;

// views
@property (nonatomic, strong) FUHomeBarView *homeBar ;
@property (weak, nonatomic) IBOutlet UIButton *trackBtn;

// 版本号 debug view
@property (weak, nonatomic) IBOutlet UILabel *appVersionLabel;
@property (weak, nonatomic) IBOutlet UILabel *sdkVersionLabel;
@property (weak, nonatomic) IBOutlet UIView *debugView;
@end

@implementation ViewController
{
    BOOL firstLoad ;// 首次进入页面
}

- (BOOL)prefersStatusBarHidden{
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addObserver];
    
    firstLoad = YES ;
    
    [[FUManager shareInstance] setMaxFaceNum:1];

    [self loadDefaultAvatar];
    
    [self setLanchImage];
    
    renderMode = FURenderCommonMode ;
    [self.camera startCapture ];
    
    self.appVersionLabel.text = [FUManager shareInstance].appVersion;
    self.sdkVersionLabel.text = [FUManager shareInstance].sdkVersion;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (firstLoad) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.lanchImage.hidden = NO ;
            [self.view sendSubviewToBack:self.lanchImage];
        });
        firstLoad = NO ;
    }else {
        
        [self.homeBar reloadModeData];
        [self.camera startCapture ];
    }
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.camera stopCapture];
    
    if (!self.preView.hidden) {
        self.trackBtn.selected = NO ;
        self.preView.hidden = YES ;
        
        self.preView.hidden = YES ;
        FUAvatar *avatar = [FUManager shareInstance].avatarList.firstObject;
        // 加载默认动画
        [avatar loadStandbyAnimation];
        
        renderMode = FURenderCommonMode ;
        
        self.appVersionLabel.hidden = NO ;
        self.sdkVersionLabel.hidden = NO ;
        self.debugView.hidden = NO ;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    NSString *identifier = segue.identifier ;
    if ([identifier isEqualToString:@"FUHomeBar"]) {
        
        UIViewController *itemsViewc = segue.destinationViewController;
        self.homeBar = (FUHomeBarView *)itemsViewc.view ;
        self.homeBar.delegate = self ;
    }else if ([identifier isEqualToString:@"PushToTakePicView"]){   // 生成页
        
        [self.camera stopCapture];
    }else if ([identifier isEqualToString:@"PushToEditView"]){      // 形象页
        [self.camera stopCapture];
        
    }else if ([identifier isEqualToString:@"PushToARView"]){        // AR
        [self.camera stopCapture];
    }
}

- (void)setLanchImage {
    
    CGFloat scale = [UIScreen mainScreen].scale;
    int width = (int)(self.view.frame.size.width * scale);
    int height = (int)(self.view.frame.size.height * scale);
    
    NSString *imageName = [NSString stringWithFormat:@"LanchImage%dx%d", width, height];
    
    UIImage *image = [UIImage imageNamed:imageName];
    self.lanchImage.image = image ;
    self.lanchImage.hidden = NO ;
    [self.view bringSubviewToFront:self.lanchImage];
}

- (void)loadDefaultAvatar {
    loadingBundles = YES ;

    FUAvatar *avatar = [FUManager shareInstance].avatarList.firstObject;
    [[FUManager shareInstance] reloadRenderAvatar:avatar];
    [avatar loadStandbyAnimation];

    loadingBundles = NO ;
}

// Avatar 旋转
-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    
    CGFloat locationX = [touch locationInView:self.displayView].x;
    CGFloat preLocationX = [touch previousLocationInView:self.displayView].x;
    
    float dx = (locationX - preLocationX) / self.displayView.frame.size.width;
    
    CGFloat locationY = [touch locationInView:self.displayView].y;
    CGFloat preLocationY = [touch previousLocationInView:self.displayView].y;
    
    float dy = (locationY - preLocationY) / self.displayView.frame.size.height ;
    
    FUAvatar *avatar = [FUManager shareInstance].currentAvatars.firstObject;
    [avatar resetRotDelta:dx];
    [avatar resetTranslateDelta:-dy];
}

// track face
- (IBAction)trackAction:(UIButton *)sender {
    sender.selected = !sender.selected ;
    self.preView.hidden = !sender.selected ;
    renderMode = sender.selected ? FURenderPreviewMode : FURenderCommonMode ;

    FUAvatar *avatar = [FUManager shareInstance].currentAvatars.firstObject;

    if (sender.selected) {
        [avatar loadTrackFaceModePose];
        [avatar enterTrackFaceMode];

    }else{
        [avatar quitTrackFaceMode];
        [avatar loadStandbyAnimation];
    }
    self.appVersionLabel.hidden = sender.selected ;
    self.sdkVersionLabel.hidden = sender.selected ;
    self.debugView.hidden = sender.selected ;
}

#pragma mark ---- loading

-(FUCamera *)camera {
    if (!_camera) {
        _camera = [[FUCamera alloc] init];
        _camera.delegate = self ;
        _camera.shouldMirror = NO ;
        [_camera changeCameraInputDeviceisFront:YES];
    }
    return _camera ;
}

#pragma mark ---- FUCameraDelegate

-(void)didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (loadingBundles) {
        return ;
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) ;
    
    float landmarks[150] ;
    CVPixelBufferRef buffer = [[FUManager shareInstance] renderP2AItemWithPixelBuffer:pixelBuffer RenderMode:renderMode Landmarks:landmarks];
    
    [self.displayView displayPixelBuffer:buffer withLandmarks:nil count:0 Mirr:YES];
    
    if (renderMode == FURenderPreviewMode) {
        [self.preView displayPixelBuffer:pixelBuffer withLandmarks:landmarks count:150 Mirr:YES];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark ---- FUHomeBarViewDelegate

- (void)homeBarViewShouldCreateAvatar {
    [self performSegueWithIdentifier:@"PushToTakePicView" sender:nil];
}

- (void)homeBarViewShouldDeleteAvatar {
    [self.camera stopCapture];
    FUHistoryViewController *historyView = [[FUHistoryViewController alloc] initWithNibName:@"FUHistoryViewController" bundle:[NSBundle mainBundle]];
    historyView.mDelegate = self ;
    [self presentViewController:historyView animated:YES completion:nil];
}

- (void)homeBarViewDidSelectedAvatar:(FUAvatar *)avatar {
    
    self->loadingBundles = YES ;
    
    [[FUManager shareInstance] reloadRenderAvatar:avatar];
    
    switch (self->renderMode) {
        case FURenderCommonMode:
            [avatar loadStandbyAnimation];
            break;
        case FURenderPreviewMode:
            [avatar loadTrackFaceModePose];
            [avatar enterTrackFaceMode];
            break ;
    }
    
    self->loadingBundles = NO ;
}

-(void)homeBarViewShouldShowTopView:(BOOL)show {
    FUAvatar *avatar = [FUManager shareInstance].currentAvatars.firstObject;
    
    if (show) {
        
        [avatar resetScaleToFace];
        
        [UIView animateWithDuration:0.5 animations:^{
            self.trackBtn.transform = CGAffineTransformMakeTranslation(0, -200) ;
        }];
    }else {
        
        if (!CGAffineTransformEqualToTransform(self.trackBtn.transform, CGAffineTransformIdentity)) {
            
            [avatar resetScaleToBody];
            
            [UIView animateWithDuration:0.5 animations:^{
                self.trackBtn.transform = CGAffineTransformIdentity ;
            }];
        }
    }
}
- (void)homeBarSelectedActionWithAR:(BOOL)isAR {
    if (isAR) {     // AR 滤镜
        FUAvatar *avatar = [FUManager shareInstance].avatarList.firstObject;
        [avatar quitTrackFaceMode];
        [self performSegueWithIdentifier:@"PushToARView" sender:nil];
    }else {         // 形象
        [self performSegueWithIdentifier:@"PushToEditView" sender:nil];
    }
}

// 合影
- (void)homeBarSelectedGroupBtn {
    [self performSegueWithIdentifier:@"showGroupPhotoController" sender:nil];
}

// zoom
- (void)homeBarViewReceiveZoom:(float)zoomScale {
    FUAvatar *avatar = [FUManager shareInstance].currentAvatars.firstObject;
    [avatar resetScaleDelta:zoomScale];
}

#pragma mark ---- FUHistoryViewControllerDelegate
-(void)historyViewDidDeleteCurrentItem {
    [self loadDefaultAvatar];
    [self.homeBar reloadModeData];
}

#pragma mark --- Observer

- (void)addObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)willResignActive    {
    
    if (self.navigationController.visibleViewController == self) {
        [self.camera stopCapture];
    }
}

- (void)willEnterForeground {
    
    if (self.navigationController.visibleViewController == self) {
        [self.camera startCapture];
    }
}

- (void)didBecomeActive {
    
    if (self.navigationController.visibleViewController == self) {
        [self.camera startCapture];
    }
}

@end
