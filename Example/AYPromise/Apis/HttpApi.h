//
//  HttpApi.h
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Api.h"
#import <AYPromise/AYPromise.h>

@interface HttpApi : Api

//传统模式
- (void)GET:(NSString *)url
      param:(id)param
    success:(void(^)(NSData *data))success
    failure:(void (^)(NSString *errMsg, NSError *error))failure;

- (void)serialize:(NSData *)data
            success:(void (^)(id result))success
            failure:(void (^)(NSString *errMsg, NSError *error))failure;

- (void)saveToDb:(id)data
         success:(void (^)(NSString *result))success
         failure:(void(^)(NSString *errMsg, NSError *error))failure;






//promise模式
- (AYPromise<NSData *> *)GET:(NSString *)url param:(id)param;
- (AYPromise<id> *)serializate:(NSData *)data;
- (AYPromise<NSString *> *)saveToDb:(id)data;
@end
