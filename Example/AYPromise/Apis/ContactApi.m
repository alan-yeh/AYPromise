//
//  ContactApi.m
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "ContactApi.h"
#import "HttpApi.h"

@implementation ContactApi

- (NSArray<Contact *> *)parseContact:(id)data{
    NSMutableArray *array = [NSMutableArray new];
    [array addObject:[Contact contactWithJson:@{@"userCode": @"zhangsan", @"name": @"张三"}]];
    [array addObject:[Contact contactWithJson:@{@"userCode": @"lisi", @"name": @"李四"}]];
    return array;
}

//传统开发
- (void)loadContactSuccess:(void (^)(NSArray<Contact *> *))success failure:(void (^)(NSString *))failure{
    [[HttpApi api] GET:@"/mobilework/s"
                 param:@{@"service":@"contactList"}
               success:^(NSData *data) {
                   //JSON解析
                   [[HttpApi api] serialize:data
                                      success:^(id result) {
                                          //生成实体
                                          NSArray<Contact *> *contacts = [self parseContact:result];
                                          //将实体保存到数据库
                                          [[HttpApi api] saveToDb:contacts
                                                          success:^(NSString *result) {
                                                              //保存成功了
                                                              success(contacts);
                                                          }
                                                          failure:^(NSString *errMsg, NSError *error) {
                                                              //保存失败了
                                                              failure(errMsg);
                                                          }];
                                      }
                                      failure:^(NSString *errMsg, NSError *error) {
                                          //JSON解析失败
                                          failure(errMsg);
                                      }];
               }
               failure:^(NSString *errMsg, NSError *error) {
                   //网络访问失败
                   failure(errMsg);
               }];
    

}


//promise模式
- (AYPromise<NSArray<Contact *> *> *)loadContact{
    return [[HttpApi api] GET:@"/mobilework/s" param:@{@"service":@"contactList"}]
    
    .then(^id(NSData *data){
        //JSON解析
        return [[HttpApi api] serializate:data];
    })
    
    .then(NSInvocationMake(self, @selector(parseContact:)))//生成实体
    
    .then(^(NSArray<Contact *> *contacts){
        //保存到数据库
        return [[HttpApi api] saveToDb:contacts].then(^{
            return contacts;
        });
    });
}

@end
