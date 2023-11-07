//
//  XMediaPlayer.h
//  PlayerDemo
//
//  Created by 陈艺坤 on 2023/11/7.
//  Copyright © 2023 DS-Team. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>
#import "WMPlayerModel.h"


//****************************枚举*******************************
// 播放器的几种状态
typedef NS_ENUM(NSInteger, XMediaPlayerStatus) {
    XMediaPlayerStatusUnknown,  //播放器状态未知
    XMediaPlayerStatusReadyToPlay, //播放器状态准备完成
    XMediaPlayerStatusFailed,   //播放器状态错误
    
    XMediaPlayerStatusPlaying,       // 播放中
    XMediaPlayerStatusStopped,       //暂停播放
    XMediaPlayerStatusBuffering,     // 缓冲中
    XMediaPlayerStatusFinished,       //完成播放

};

// playerLayer的填充模式（默认：等比例填充，直到一个维度到达区域边界）
typedef NS_ENUM(NSInteger, XMediaPlayerLayerGravity) {
     XMediaPlayerLayerGravityResize,           // 非均匀模式。两个维度完全填充至整个视图区域
     XMediaPlayerLayerGravityResizeAspect,     // 等比例填充，直到一个维度到达区域边界
     XMediaPlayerLayerGravityResizeAspectFill  // 等比例填充，直到填充满整个视图区域，其中一个维度的部分区域会被裁剪
};


@class XMediaPlayer;
@protocol XMediaPlayerDelegate <NSObject>

@optional
//未知状态()
-(void)XMediaplayerStatusUnknown:(XMediaPlayerStatus)Status;
//视频准备完成
-(void)XMediaPlayerStatusReadyToPlay:(XMediaPlayerStatus)Status;
//播放错误
-(void)XMediaPlayerStatusFailed:(XMediaPlayerStatus)Status failedError:(NSError *)error;
//开始播放(播放中)
-(void)XMediaPlayerStatePlaying:(XMediaPlayerStatus)Status;
//暂停播放(未播放)
-(void)XMediaPlayerStateStopped:(XMediaPlayerStatus)Status;
//完成播放
-(void)XMediaPlayerStateFinished:(XMediaPlayerStatus)Status;


//当前缓冲为空
-(void)XMediaPlayerPlaybackBufferEmpty;
///视频缓冲回调,timeInterval已缓冲的时间(秒) totalDuration视频总时长
///(该回调表示媒体项目已经开始缓冲，但不一定足够长，playbackLikelyToKeepUp为YES时,表示播放器认为当前的缓冲状态足够，可以继续播放而不会中断。)
-(void)XMediaPlayerLoadedTimeRangesTimeInterval:(NSTimeInterval)timeInterval totalDuration:(CGFloat)totalDuration playbackLikelyToKeepUp:(BOOL)playbackLikelyToKeepUp;
///当前缓冲区域已充足
///(该回调表示表示播放器认为当前的缓冲状态足够，可以继续播放而不会中断。)
-(void)XMediaPlayerplaybackLikelyToKeepUp;


//播放器已经拿到视频的尺寸大小
-(void)XMediaplayerGotVideoSize:(CGSize )presentationSize;
//播放器已经拿到视频的总时长
-(void)XMediaplayerDuration:(CGFloat)duration;
@end


NS_ASSUME_NONNULL_BEGIN

@interface XMediaPlayer : UIView

//播放状态
@property (nonatomic,assign) XMediaPlayerStatus  playerStatus;
/**
 播放器对应的model
 */
@property (nonatomic,strong) WMPlayerModel   *playerModel;
/**
 播放器的代理
 */
@property (nonatomic, weak)id <XMediaPlayerDelegate> delegate;
/**
 是否静音
 */
@property (nonatomic,assign) BOOL  muted;
/**
 是否循环播放（不循环则意味着需要手动触发第二次播放），default NO
 */
@property (nonatomic,assign) BOOL  loopPlay;
/**
 设置playerLayer的填充模式
 */
@property (nonatomic, assign) XMediaPlayerLayerGravity     playerLayerGravity;

/**
 自定义实例化方法初始化方式（-方法）

 @param playerModel 播放model
 @return 播放器实例
 */
-(instancetype)initPlayerModel:(WMPlayerModel *)playerModel;

/**
 自定义类方法+初始化方式（+方法）

 @param playerModel 播放model
 @return 播放器实例
 */
+(instancetype)playerWithModel:(WMPlayerModel *)playerModel;

/**
 播放
 */
- (void)play;

/**
 暂停
 */
- (void)pause;

/**
 获取正在播放的时间点

 @return double的一个时间点
 */
- (double)currentTime;
/**
 获取视频长度
 
 @return double的一个时间点
 */
- (double)duration;
/**
 重置播放器,然后切换下一个播放资源
 */
- (void )resetWMPlayer;

@end

NS_ASSUME_NONNULL_END
