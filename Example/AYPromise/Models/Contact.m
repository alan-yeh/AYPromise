//
//  Contact.m
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "Contact.h"

@implementation Contact
+ (instancetype)contactWithJson:(NSDictionary<NSString *,id> *)json{
    Contact *contact = [Contact new];
    contact.name = json[@"name"];
    contact.userCode = json[@"userCode"];
    return contact;
}
@end
