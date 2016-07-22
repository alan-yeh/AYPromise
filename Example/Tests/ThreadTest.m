//
//  ThreadTest.m
//  AYPromise
//
//  Created by PoiSon on 16/7/22.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AYPromise/AYPromise.h>

#define TIME_OUT 1
@interface ThreadTest : XCTestCase

@end

@implementation ThreadTest


- (void)test1{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)test2{
    id ex1 = [self expectationWithDescription:@""];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
            XCTAssertEqual([NSThread currentThread].isMainThread, YES);
            [ex1 fulfill];
        });
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}
- (void)test3{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        resolve(@"abc");
    }).then(^(NSString *result){
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}
- (void)test4{
    id ex1 = [self expectationWithDescription:@""];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
            resolve(@"abc");
        }).then(^(NSString *result){
            XCTAssertEqual([NSThread currentThread].isMainThread, YES);
            [ex1 fulfill];
        });
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}
- (void)test5{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"success");
        });
    }).then(^(NSString *result){
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)test6{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(NSErrorMake(nil, @"发生错误了"));
        });
    }).catch(^(NSError *error){
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}
- (void)test7{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(NSErrorMake(nil, @"发生错误了"));
        });
    }).always(^{
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}
- (void)test8{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"success");
        });
    }).always(^{
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)test9{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"success");
        });
    }).thenAsync(^{
        XCTAssertEqual([NSThread currentThread].isMainThread, NO);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)test10{
    id ex1 = [self expectationWithDescription:@""];
    
    dispatch_queue_t queue = dispatch_queue_create("dispatch_test", DISPATCH_QUEUE_PRIORITY_DEFAULT);
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"success");
        });
    }).thenOn(queue, ^{
        dispatch_queue_t current_queuet = dispatch_get_current_queue();
        XCTAssert(strcmp(dispatch_queue_get_label(current_queuet), "dispatch_test") == 0);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)test11{
    id ex1 = [self expectationWithDescription:@""];
    
    dispatch_queue_t queue = dispatch_queue_create("dispatch_test", DISPATCH_QUEUE_PRIORITY_DEFAULT);
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        @throw NSErrorMake(nil, @"Error");
    }).catchOn(queue, ^{
        dispatch_queue_t current_queuet = dispatch_get_current_queue();
        XCTAssert(strcmp(dispatch_queue_get_label(current_queuet), "dispatch_test") == 0);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)test12{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(PSResolve  _Nonnull resolve) {
        @throw NSErrorMake(nil, @"Error");
    }).catchAsync(^{
        XCTAssertEqual([NSThread currentThread].isMainThread, NO);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}
@end
