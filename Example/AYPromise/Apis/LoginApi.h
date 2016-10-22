//
//  LoginApi.h
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Api.h"
#import <AYPromise/AYPromise.h>

@interface LoginApi : Api

- (void)loginWithUserName:(NSString *)userName
              andPassword:(NSString *)password
                  success:(void (^)(NSString *msg))success
                  failure:(void(^)(NSString *error))failure;


- (AYPromise<NSDictionary *> *)loginWithUserName:(NSString *)userName
                                     andPassword:(NSString *)password;
@end
