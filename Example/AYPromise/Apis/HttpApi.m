//
//  HttpApi.m
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "HttpApi.h"
#import <AFNetworking/AFNetworking.h>

@implementation HttpApi
static BOOL saveToDbSuccess = YES;


- (AFHTTPSessionManager *)manager{
    static AFHTTPSessionManager *manager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://192.168.0.185:9081"]];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        manager.securityPolicy.allowInvalidCertificates = YES;
        manager.securityPolicy.validatesDomainName = NO;
    });
    
    return manager;
}

//传统开发
- (void)GET:(NSString *)url param:(id)param success:(void (^)(NSData *))success failure:(void (^)(NSString *, NSError *))failure{
    [[self manager] GET:url
             parameters:param
               progress:nil
                success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                    success(responseObject);
                }
                failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                    failure(@"网络访问错误", error);
                }];
}

- (void)serialize:(NSData *)data success:(void (^)(id))success failure:(void (^)(NSString *, NSError *))failure{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *error;
        id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"数据序列化出错", error);
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            success(json);
        });
    });
}

- (void)saveToDb:(id)data success:(void (^)(NSString *))success failure:(void (^)(NSString *, NSError *))failure{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"执行保存到数据库操作");
        if (saveToDbSuccess) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(@"保存到数据库成功");
            });
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(@"保存到数据库失败", nil);
            });
        }
    });
}


//promise模式
- (AYPromise<NSData *> *)GET:(NSString *)url param:(id)param{
    return AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        [[self manager] GET:url
                 parameters:param
                   progress:nil
                    success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                        resolve(responseObject);
                    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                        resolve(NSErrorMake(error, @"网络访问错误"));
                    }];
    });
}

- (AYPromise<id> *)serializate:(NSData *)data{
    return AYPromiseWith(^id{
        NSError *error;
        id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) {
            return NSErrorMake(error, @"数据序列化出错");
        }
        return json;
    });
}

- (AYPromise<NSString *> *)saveToDb:(id)data{
    return AYPromiseAsyncWith(^id{
        NSLog(@"执行保存到数据库操作");
        if (saveToDbSuccess) {
            return @"保存到数据库成功";
        }else{
            return NSErrorMake(nil, @"保存到数据库失败");
        }
    });
}
@end
