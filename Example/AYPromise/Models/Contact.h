//
//  Contact.h
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Contact : NSObject
+ (instancetype)contactWithJson:(NSDictionary<NSString *, id> *)json;

@property (copy, nonatomic) NSString *userCode;           /**< 用户名（姓名缩写）*/
@property (copy, nonatomic) NSString *name;               /**< 姓名*/
@end
