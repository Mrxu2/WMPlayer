//
//  XMediaPlayer.m
//  PlayerDemo
//
//  Created by 陈艺坤 on 2023/11/7.
//  Copyright © 2023 DS-Team. All rights reserved.
//

#import "XMediaPlayer.h"
#import <VIMediaCache/VIMediaCache.h>






//整个屏幕代表的时间
#define TotalScreenTime 90
#define LeastDistance 15

static void *PlayViewCMTimeValue = &PlayViewCMTimeValue;
static void *PlayViewStatusObservationContext = &PlayViewStatusObservationContext;

@interface XMediaPlayer () <UIGestureRecognizerDelegate,AVRoutePickerViewDelegate,AVPictureInPictureControllerDelegate>

//是否初始化了播放器
@property (nonatomic,assign) BOOL  isInitPlayer;
//总时间
@property (nonatomic,assign)CGFloat totalTime;

//格式化时间（懒加载防止多次重复初始化）
@property (nonatomic,strong) NSDateFormatter *dateFormatter;

//播放器状态
@property (nonatomic,assign) XMediaPlayerStatus  state;
//所有的控件统一管理在此view中
@property (nonatomic,strong) UIView     *contentView;
//当前播放的item
@property (nonatomic,retain) AVPlayerItem   *currentItem;
//playerLayer,可以修改frame
@property (nonatomic,retain) AVPlayerLayer  *playerLayer;
//播放器player
@property (nonatomic,retain) AVPlayer   *player;
//播放资源路径URL
@property (nonatomic,strong) NSURL         *videoURL;
//播放资源
@property (nonatomic,strong) AVURLAsset    *urlAsset;
//跳到time处播放
@property (nonatomic,assign) double    seekTime;
//视频填充模式
@property (nonatomic, copy) NSString   *videoGravity;
//是否缓冲中
@property (nonatomic,assign)BOOL isBuffering;
//缓存
@property (nonatomic, strong) VIResourceLoaderManager *resourceLoaderManager;

@end
@implementation XMediaPlayer

- (instancetype)initWithCoder:(NSCoder *)coder{
    self = [super initWithCoder:coder];
    if (self) {
        [self initWMPlayer];
    }
    return self;
}
-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self initWMPlayer];
    }
    return self;
}
-(instancetype)initPlayerModel:(WMPlayerModel *)playerModel{
    self = [super init];
    if (self) {
        self.playerModel = playerModel;
    }
    return self;
}
+(instancetype)playerWithModel:(WMPlayerModel *)playerModel{
    XMediaPlayer *player = [[XMediaPlayer alloc] initPlayerModel:playerModel];
    return player;
}
- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    }
    return _dateFormatter;
}
- (NSString *)videoGravity {
    if (!_videoGravity) {
        _videoGravity = AVLayerVideoGravityResizeAspect;
    }
    return _videoGravity;
}

-(void)initWMPlayer{
    [UIApplication sharedApplication].idleTimerDisabled=YES;
    NSError *setCategoryErr = nil;
    NSError *activationErr  = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error: &setCategoryErr];
    [[AVAudioSession sharedInstance]setActive: YES error: &activationErr];
    //wmplayer内部的一个view，用来管理子视图
    self.contentView = [UIView new];
    self.contentView.backgroundColor = [UIColor blackColor];
    [self addSubview:self.contentView];
    self.backgroundColor = [UIColor blackColor];
}
#pragma mark - Gesture Delegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
        if ([touch.view isKindOfClass:[UIControl class]]) {
            return NO;
        }
    return YES;
}
#pragma mark
#pragma mark - layoutSubviews
-(void)layoutSubviews{
    [super layoutSubviews];
    self.contentView.frame = self.bounds;
    self.playerLayer.frame = self.contentView.bounds;
    
}
#pragma mark
#pragma mark 进入后台
- (void)appDidEnterBackground:(NSNotification*)note{
    
    if(self.state == XMediaPlayerStatusPlaying){
        [self pause];
    }
}
#pragma mark
#pragma mark 进入前台
- (void)appWillEnterForeground:(NSNotification*)note{
    if( self.state == XMediaPlayerStatusStopped){
        //进入前台不开启播放
//        [self play];
    }
}

//获取视频长度
- (double)duration{
    AVPlayerItem *playerItem = self.player.currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return CMTimeGetSeconds([[playerItem asset] duration]);
    }else{
        return 0.f;
    }
}
//获取视频当前播放的时间
- (double)currentTime{
    if (self.player) {
        return CMTimeGetSeconds([self.player currentTime]);
    }else{
        return 0.0;
    }
}
//获取播放器状态
-(XMediaPlayerStatus)playerStatus{
    return self.state;
}
//播放
-(void)play{
    if (self.isInitPlayer == NO) {
        [self creatWMPlayerAndReadyToPlay];
    }else{
        if (self.state == XMediaPlayerStatusStopped) {
            [self.player play];
        }else if(self.state == XMediaPlayerStatusFinished){
            //重新播放
            [self seekToTimeToPlay:0.0 completionHandler:nil];
        }
    }
}
//暂停
-(void)pause{

    [self.player pause];
}

-(void)setCurrentItem:(AVPlayerItem *)playerItem{
    if (_currentItem==playerItem) {
        return;
    }
    if (_currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];

        [_currentItem removeObserver:self forKeyPath:@"status"];
        [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [_currentItem removeObserver:self forKeyPath:@"duration"];
        [_currentItem removeObserver:self forKeyPath:@"presentationSize"];
        _currentItem = nil;
    }
    _currentItem = playerItem;
    if (_currentItem) {
        [_currentItem addObserver:self
                           forKeyPath:@"status"
                              options:NSKeyValueObservingOptionNew
                              context:PlayViewStatusObservationContext];
        
        [_currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 缓冲区空了，需要等待数据
        [_currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options: NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 缓冲区有足够数据可以播放了
        [_currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options: NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        
        [_currentItem addObserver:self forKeyPath:@"duration" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        
        [_currentItem addObserver:self forKeyPath:@"presentationSize" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
                
        [self.player replaceCurrentItemWithPlayerItem:_currentItem];
        
        // 添加视频播放结束通知
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];
        

    }
   
}
//设置静音
- (void)setMuted:(BOOL)muted{
    _muted = muted;
    self.player.muted = muted;
}
//设置playerLayer的填充模式
- (void)setPlayerLayerGravity:(XMediaPlayerLayerGravity)playerLayerGravity {
    _playerLayerGravity = playerLayerGravity;
    switch (playerLayerGravity) {
        case XMediaPlayerLayerGravityResize :
            self.playerLayer.videoGravity = AVLayerVideoGravityResize;
            self.videoGravity = AVLayerVideoGravityResize;
            break;
        case XMediaPlayerLayerGravityResizeAspect :
            self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            self.videoGravity = AVLayerVideoGravityResizeAspect;
            break;
        case XMediaPlayerLayerGravityResizeAspectFill :
            self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            self.videoGravity = AVLayerVideoGravityResizeAspectFill;
            break;
        default:
            break;
    }
}
//重写playerModel的setter方法，处理自己的逻辑
-(void)setPlayerModel:(WMPlayerModel *)playerModel{
    if (_playerModel==playerModel) {
        return;
    }
    _playerModel = playerModel;
    self.seekTime = playerModel.seekTime;
    if(playerModel.playerItem){
        self.currentItem = playerModel.playerItem;
    }else{
        self.videoURL = playerModel.videoURL;
    }
}
-(void)creatWMPlayerAndReadyToPlay{
    self.isInitPlayer = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    //设置player的参数
    if(self.currentItem){
        self.player = [AVPlayer playerWithPlayerItem:self.currentItem];
    }else{
        if(self.playerModel.openCache){
            self.resourceLoaderManager = [VIResourceLoaderManager new];
            self.urlAsset = [_resourceLoaderManager URLAssetWithURL:self.videoURL];
            self.currentItem = [_resourceLoaderManager playerItemWithURLAsset:self.urlAsset];
        }else{
                self.urlAsset = [AVURLAsset assetWithURL:self.videoURL];
                self.currentItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
        }
    
        self.player = [AVPlayer playerWithPlayerItem:self.currentItem];
    }
    if(self.loopPlay){
        self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    }else{
        self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    }
    //ios10新添加的属性，如果播放不了，可以试试打开这个代码
    if ([self.player respondsToSelector:@selector(automaticallyWaitsToMinimizeStalling)]) {
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    self.player.usesExternalPlaybackWhileExternalScreenIsActive=YES;
    
    [self.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];

    //AVPlayerLayer
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    //WMPlayer视频的默认填充模式，AVLayerVideoGravityResizeAspect
    self.playerLayer.frame = self.contentView.layer.bounds;
    self.playerLayer.videoGravity = self.videoGravity;
    [self.contentView.layer insertSublayer:self.playerLayer atIndex:0];
    [self.player play];
}
//是否循环播放
-(void)setLoopPlay:(BOOL)loopPlay{
    _loopPlay = loopPlay;
    if(self.player){
        if(loopPlay){
            self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        }else{
            self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
        }
    }
}
#pragma mark
#pragma mark--播放完成
- (void)moviePlayDidEnd:(NSNotification *)notification {
    
    // 视频已完全播放完
    if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerStateFinished:)]){
        [self.delegate XMediaPlayerStateFinished:XMediaPlayerStatusFinished];
    }
    
    [self seekToTimeToPlay:0.0 completionHandler:^(BOOL finished) {
        if (finished) {
            /// 播发完成发出代理
            if (!self.loopPlay) {
                [self pause];
            }
        }
    }];
}
#pragma mark
#pragma mark KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    /* AVPlayerItem "status" property value observer. */
    if (context == PlayViewStatusObservationContext){
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            switch (status){
                case AVPlayerItemStatusUnknown:{
                    self.state = XMediaPlayerStatusUnknown;
                    if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaplayerStatusUnknown:)]){
                        [self.delegate XMediaplayerStatusUnknown:XMediaPlayerStatusUnknown];
                    }
                }
                    break;
                case AVPlayerItemStatusReadyToPlay:{
                      /* Once the AVPlayerItem becomes ready to play, i.e.
                     [playerItem status] == AVPlayerItemStatusReadyToPlay,
                     its duration can be fetched from the item. */
                    self.state = XMediaPlayerStatusReadyToPlay;
                    if (self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerStatusReadyToPlay:)]){
                        [self.delegate XMediaPlayerStatusReadyToPlay:XMediaPlayerStatusReadyToPlay];
                    }

                    if (self.seekTime) {
                        [self seekToTimeToPlay:self.seekTime completionHandler:nil];
                    }
                    if (self.muted) {
                        self.player.muted = self.muted;
                    }
                }
                    break;
                    
                case AVPlayerItemStatusFailed:{
                    self.state = XMediaPlayerStatusFailed;
                    NSError *error = [self.player.currentItem error];
                    if (self.delegate&&[self.delegate respondsToSelector:@selector(XMediaPlayerStatusFailed:failedError:)]) {
                        [self.delegate XMediaPlayerStatusFailed:XMediaPlayerStatusFailed failedError:error];
                    }
 
                }
                    break;
            }
        }else if ([keyPath isEqualToString:@"duration"]) {
            if ((CGFloat)CMTimeGetSeconds(self.currentItem.duration) != self.totalTime) {
                self.totalTime = (CGFloat) CMTimeGetSeconds(self.currentItem.asset.duration);
                if (!isnan(self.totalTime)) {

                }else{
                    self.totalTime = MAXFLOAT;
                }
                if (self.delegate && [self.delegate respondsToSelector:@selector(XMediaplayerDuration:)]) {
                    [self.delegate XMediaplayerDuration:self.totalTime];
                }
            }
        }else if ([keyPath isEqualToString:@"presentationSize"]) {
            self.playerModel.presentationSize = self.currentItem.presentationSize;
            if (self.delegate&&[self.delegate respondsToSelector:@selector(XMediaplayerGotVideoSize:)]) {
                [self.delegate XMediaplayerGotVideoSize:self.playerModel.presentationSize];
            }
        }else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            // 计算缓冲进度 timeInterval(当前已缓冲的总时长)
            NSTimeInterval timeInterval = [self availableDuration];
            CMTime duration             = self.currentItem.duration;
            CGFloat totalDuration       = CMTimeGetSeconds(duration);
            if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerLoadedTimeRangesTimeInterval:totalDuration:playbackLikelyToKeepUp:)]){
                [self.delegate XMediaPlayerLoadedTimeRangesTimeInterval:timeInterval totalDuration:totalDuration playbackLikelyToKeepUp:self.currentItem.playbackLikelyToKeepUp];
            }
        } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            // 当缓冲是空的时候
            if (self.currentItem.playbackBufferEmpty) {
                self.state = XMediaPlayerStatusBuffering;
                [self pause];
                if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerPlaybackBufferEmpty)]){
                    [self.delegate XMediaPlayerPlaybackBufferEmpty];
                }
            }
        }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            //here
            // 当缓冲好的时候(缓冲区域充足)
            if (self.currentItem.playbackLikelyToKeepUp){
                //当前为缓冲时自动暂停状态 - 则自动播放
                if(self.isBuffering && self.state == XMediaPlayerStatusStopped){
                    [self play];
                }
                if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerplaybackLikelyToKeepUp)]){
                    [self.delegate XMediaPlayerplaybackLikelyToKeepUp];
                }
            }
        }else if([keyPath isEqualToString:@"rate"]){
            float rate = _player.rate;
            if(rate > 0){
                //播放中
                self.state = XMediaPlayerStatusPlaying;
                self.isBuffering = NO;
                if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerStatePlaying:)]){
                    [self.delegate XMediaPlayerStatePlaying:XMediaPlayerStatusPlaying];
                }
            }else{
                if(self.state == XMediaPlayerStatusBuffering){
                    // 当前为缓冲状态
                    self.isBuffering = YES;
                }
                self.state = XMediaPlayerStatusStopped;
                // 播放暂停
                if(self.delegate && [self.delegate respondsToSelector:@selector(XMediaPlayerStateStopped:)]){
                    [self.delegate XMediaPlayerStatePlaying:XMediaPlayerStatusStopped];
                }
                
            }
        }
    }
}

#pragma mark
#pragma mark autoDismissControlView

//seekTime跳到time处播放
- (void)seekToTimeToPlay:(double)seekTime completionHandler:(void (^)(BOOL finished))completionHandler{
    if (self.player&&self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        if (seekTime>=self.totalTime) {
            seekTime = 0.0;
        }
        if (seekTime<0) {
            seekTime=0.0;
        }
//        int32_t timeScale = self.player.currentItem.asset.duration.timescale;
        //currentItem.asset.duration.timescale计算的时候严重堵塞主线程，慎用
        /* A timescale of 1 means you can only specify whole seconds to seek to. The timescale is the number of parts per second. Use 600 for video, as Apple recommends, since it is a product of the common video frame rates like 50, 60, 25 and 24 frames per second*/
        [self.player seekToTime:CMTimeMakeWithSeconds(seekTime, self.currentItem.currentTime.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            self.seekTime = 0;
            if(completionHandler){
                completionHandler(finished);
            }
        }];
    }
}
- (CMTime)playerItemDuration{
    AVPlayerItem *playerItem = self.currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return([playerItem duration]);
    }
    return(kCMTimeInvalid);
}
//计算缓冲进度
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [_currentItem loadedTimeRanges];
    CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds        = CMTimeGetSeconds(timeRange.start);
    float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result     = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}
//重置播放器
-(void )resetWMPlayer{
    
    if(self.playerModel.openCache){
        [VICacheManager cleanCacheWithMaxCache:self.playerModel.maxCache Error:nil];
        [self.resourceLoaderManager cancelLoaders];
    }
    
    self.currentItem = nil;
    self.isInitPlayer = NO;
    _playerModel = nil;
    self.seekTime = 0;
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 暂停
    [self pause];
   
    // 移除原来的layer
    [self.playerLayer removeFromSuperlayer];
    [self.player removeObserver:self forKeyPath:@"rate"];
    // 替换PlayerItem为nil
    [self.player replaceCurrentItemWithPlayerItem:nil];
    // 把player置为nil
    self.player = nil;
}
-(void)dealloc{
    NSLog(@"WMPlayer dealloc");
    if(self.playerModel.openCache){
        [VICacheManager cleanCacheWithMaxCache:self.playerModel.maxCache Error:nil];
        [self.resourceLoaderManager cancelLoaders];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    [self.player pause];
    
    //移除观察者
    [_currentItem removeObserver:self forKeyPath:@"status"];
    [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [_currentItem removeObserver:self forKeyPath:@"duration"];
    [_currentItem removeObserver:self forKeyPath:@"presentationSize"];
    _currentItem = nil;

    [self.playerLayer removeFromSuperlayer];
    [self.player removeObserver:self forKeyPath:@"rate"];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    self.player = nil;
    self.playerLayer = nil;
    [UIApplication sharedApplication].idleTimerDisabled=NO;
}
@end
