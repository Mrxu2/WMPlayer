//
//  WMPlayerModel.m
//  
//
//  Created by zhengwenming on 2018/4/26.
//

#import "WMPlayerModel.h"

static unsigned long long defaultCache = 512 *1024 *1024;

@implementation WMPlayerModel
-(void)setPresentationSize:(CGSize)presentationSize{
    _presentationSize = presentationSize;
    if (presentationSize.width/presentationSize.height<1) {
        self.verticalVideo = YES;
    }
}
-(unsigned long long)maxCache{
    if(_maxCache <= 0){
        _maxCache = defaultCache;
    }
    return _maxCache;
}
-(BOOL)openCache{
    if (!_openCache) {
        _openCache = NO;
    }
    //.m3u8文件暂不缓存.
    if(_videoURL && _videoURL.path && _videoURL.path.length > 0){
        NSArray *paths = [_videoURL.path componentsSeparatedByString:@".m3u"];
        if(paths.count > 1){
            return NO;
        }
    }
    return _openCache;
}
@end
