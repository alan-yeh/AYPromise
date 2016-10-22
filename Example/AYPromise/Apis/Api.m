//
//  Api.m
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "Api.h"
#import <objc/runtime.h>

@implementation Api
+ (instancetype)api{
    const void * API_INSTANCE = &API_INSTANCE;
    __block id _api_ = objc_getAssociatedObject(self, API_INSTANCE);
    if (!_api_) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            if (!_api_) {
                _api_ = [self new];
                objc_setAssociatedObject(self, API_INSTANCE, _api_, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    }
    return _api_;
}
@end
