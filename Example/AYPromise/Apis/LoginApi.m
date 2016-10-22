//
//  LoginApi.m
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "LoginApi.h"
#import "HttpApi.h"

@implementation LoginApi

//传统开发
- (void)loginWithUserName:(NSString *)userName
              andPassword:(NSString *)password
                  success:(void (^)(NSString *))success
                  failure:(void (^)(NSString *))failure{
    
    [[HttpApi api] GET:@"/mobilework/login/login"
                 param:@{@"j_username": userName,
                         @"j_password": password }
               success:^(NSData *data) {
                   //解析JSON
                   [[HttpApi api] serialize:data
                                    success:^(id result) {
                                        if ([result[@"success"] boolValue] == YES) {
                                            success(@"登录成功");
                                        }else{
                                            failure(@"用户名或密码错误");
                                        }
                                    }
                                    failure:^(NSString *errMsg, NSError *error) {
                                        failure(errMsg);
                                    }];
               } failure:^(NSString *errMsg, NSError *error) {
                   failure(errMsg);
               }];
}





//promise模式
- (AYPromise<NSDictionary *> *)loginWithUserName:(NSString *)userName andPassword:(NSString *)password{
    return [[HttpApi api] GET:@"/mobilework/login/login"
                        param:@{@"j_username": userName,
                                @"j_password": password }]
    
    .then(^(NSData *data){
        return [[HttpApi api] serializate:data];
    })
    
    .then(^id(NSDictionary *json){
        if ([json[@"success"] boolValue] == YES) {
            return @"登录成功";
        }else{
            return NSErrorMake(nil, @"用户名或密码错误");
        }
    });
}

@end
