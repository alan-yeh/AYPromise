//
//  ContactApi.h
//  AYPromise
//
//  Created by PoiSon on 16/8/10.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Api.h"
#import <AYPromise/AYPromise.h>
#import "Contact.h"

@interface ContactApi : Api


- (void)loadContactSuccess:(void (^)(NSArray<Contact *> *contact))success
                   failure:(void (^)(NSString *error))failure;



- (AYPromise<NSArray<Contact *> *> *)loadContact;
@end
