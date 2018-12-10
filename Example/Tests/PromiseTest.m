//
//  PromiseTest.m
//  AYPromise
//
//  Created by Alan Yeh on 16/7/22.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AYPromise/AYPromise.h>

#define TIME_OUT 1

@interface PromiseTest : XCTestCase

@end

@implementation PromiseTest

- (void)testPromiseBlock{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"AsyncTask completed");
        });
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"AsyncTask completed"]);
        [ex1 fulfill];
    }).catch(^{
        XCTAssert(NO, @"这里不该执行");
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testPromiseError{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(NSErrorMake(nil, @"发生错误了"));
        });
    }).then(^{
        XCTAssert(NO, @"这里不该执行");
    }).catch(^(NSError *error){
        XCTAssert(error!= nil);
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testThen{
    id ex1 = [self expectationWithDescription:@""];
    AYPromise.resolve(@"123").then(^(NSString *result){
        XCTAssert([result isEqualToString:@"123"]);
    }).then(^(NSString *result){
        XCTAssert(result == nil);
        return @"123";
    }).then(^(NSString *result){
        return [result stringByAppendingString:@"123"];
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"123123"]);
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testThen2{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"AsyncTask completed");
        });
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"AsyncTask completed"]);
        return AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
            resolve([result stringByAppendingString:@"123"]);
        }).then(^{
            return @"123";
        });
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"123"]);
    }).catch(^{
        XCTAssert(NO, @"这里不该执行");
    }).always(^{
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testFinally1{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"AsyncTask completed");
        });
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"AsyncTask completed"]);
    }).catch(^{
        XCTAssert(NO, @"这里不该执行");
    }).always(^{
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testFinally2{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(NSErrorMake(nil, @"发生错误了"));
        });
    }).then(^{
        XCTAssert(NO, @"这里不该执行");
    }).catch(^(NSError *error){
        XCTAssert(error!= nil);
    }).always(^{
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testFinally3{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@"AsyncTask completed");
        });
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"AsyncTask completed"]);
        return AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
            resolve([result stringByAppendingString:@"123"]);
        }).then(^{
            return @"123";
        });
    }).catch(^{
        XCTAssert(NO, @"这里不该执行");
    }).always(^{
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testPipe{
    id ex1 = [self expectationWithDescription:@"expectation"];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        resolve(@"123");
    }).then(^(NSString *result){
        return AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
            resolve([result stringByAppendingString:@"123"]);
        });
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"123123"]);
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testPromiseAll{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromise *p1 = AYPromiseAsyncWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, NO);
        resolve(@"thread1");
    });
    
    AYPromise *p2 = AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        resolve(@"thread2");
    });
    
    AYPromise *p3 = AYPromiseAsyncWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, NO);
        resolve(@"thread3");
    });
    
    AYPromise *p4 = AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        resolve(@"thread4");
    });
    
    AYPromise *p5 = AYPromiseAsyncWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, NO);
        resolve(@"thread5");
    });
    
    AYPromise *p6 = AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        resolve(@"thread6");
    });
    
    AYPromise.all(@[p1, p2, p3, p4, p5, p6]).then(^(NSArray<NSString *> *result){
        NSLog(@"%@", result);
        BOOL isEqual = [result isEqualToArray:@[@"thread1", @"thread2", @"thread3", @"thread4", @"thread5", @"thread6"]];
        XCTAssert(isEqual);
        [ex1 fulfill];
    }).catch(^(NSError *error){
        NSLog(@"error");
    }).always(^{
        NSLog(@"always");
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testPromiseRace{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromise *p1 = AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        resolve(@"thread1");
    });
    
    AYPromise *p2 = AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        XCTAssertEqual([NSThread currentThread].isMainThread, YES);
        resolve(@"thread2");
    });
    
    AYPromise.race(@[@"1", p1, p2]).then(^(NSString *result){
        XCTAssert([result isKindOfClass:[NSString class]]);
        XCTAssert([result isEqualToString:@"1"]);
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testThenPromise{
    id ex1 = [self expectationWithDescription:@""];
    
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        resolve(@"1");
    }).thenPromise(^(NSString *result, AYResolve resolve){
        XCTAssert([result isEqualToString:@"1"]);
        resolve(@"2");
    }).then(^(NSString *result){
        XCTAssert([result isEqualToString:@"2"]);
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testDelayThen{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        NSLog(@"reutrn: 123");
        resolve(@"123");
    }).thenDelay(0.2, ^(NSString *result){
        NSLog(@"result: %@", result);
    }).always(^{
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testDelay{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWithResolve(^(AYResolve  _Nonnull resolve) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            resolve(NSErrorMake(nil, @"发生错误了"));
        });
        resolve(@YES);
    }).then(^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [ex1 fulfill];
        });
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (NSString *)testFirst{
    return @"World";
}

- (NSString *)testInvocation:(NSString *)arg{
    return [@"Hello, " stringByAppendingString:arg];
}

- (NSString *)testCatch:(NSError *)error{
    return error.localizedDescription;
}

- (void)testThenInvocation{
    id ex1 = [self expectationWithDescription:@""];
    AYPromiseWith(NSInvocationMake(self, @selector(testFirst)))
    .then(NSInvocationMake(self, @selector(testInvocation:)))
    .then(^(NSString *str){
        XCTAssert([str isEqualToString:@"Hello, World"]);
        @throw NSErrorMake(nil, @"Test Error");
    }).catch(NSInvocationMake(self, @selector(testCatch:)))
    .then(^(NSString *arg){
        XCTAssert(@"Test Error");
    }).always(^{
        [ex1 fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

@end
