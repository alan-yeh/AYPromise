//
//  ErrorTest.m
//  AYPromise
//
//  Created by PoiSon on 16/7/22.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AYPromise/AYPromise.h>

#define TIME_OUT 1

@interface ErrorTest : XCTestCase

@end

@implementation ErrorTest

- (void)testThen1 {
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行:%@", @"123");
    }).catch(^(NSError *error){
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^{
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testThen2{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        return @"aaa";
    }).thenAsync(^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testThen3{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        return @"aaa";
    }).thenPromise(^(id result, PSResolve resolve){
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testThen4{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        return @"aaa";
    }).thenOn(dispatch_get_global_queue(0, 0), ^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testCatch1{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        @throw NSErrorMake(nil, @"abc");
    }).catch(^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testCatch2{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        @throw NSErrorMake(nil, @"abc");
    }).catchAsync(^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testCatch3{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        @throw NSErrorMake(nil, @"abc");
    }).catchOn(dispatch_get_global_queue(0, 0), ^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

- (void)testAlways{
    id ex = [self expectationWithDescription:@""];
    
    AYPromiseWith(^{
        @throw NSErrorMake(nil, @"abc");
    }).always(^{
        @throw NSErrorMake(nil, @"Error");
    }).then(^{
        XCTAssert(NO, @"这里不应该执行");
        return nil;
    }).catch(^(NSError *error) {
        XCTAssert([error.localizedDescription isEqualToString:@"Error"]);
    }).catch(^(NSError *error){
        XCTAssert(NO, @"这里不应该执行");
    }).always(^{
        [ex fulfill];
    });
    [self waitForExpectationsWithTimeout:TIME_OUT handler:nil];
}

@end
