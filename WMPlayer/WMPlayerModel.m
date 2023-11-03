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
@end
