//
//  AYPromise.h
//  AYPromise
//
//  Created by Alan Yeh on 16/2/15.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const AYPromiseInternalErrorsKey;
/**
 *  快速构建NSError对象
 *
 *  @param localizedDescription 错误描述
 *  @param internalErrors       内部错误，通过error.userInfo[AYPromiseInternalErrorsKey]可以获得
 */
NSError *NSErrorMake(id _Nullable internalErrors, NSString *localizedDescription, ...) NS_FORMAT_FUNCTION(2,3);
NSError *NSErrorWithUserInfo(NSDictionary *userInfo, NSString *localizedDescription, ...) NS_FORMAT_FUNCTION(2,3);

NSInvocation *NSInvocationMake(id target, SEL action);

typedef void (^AYResolve)(id __nullable result);

typedef NS_ENUM(NSUInteger, AYPromiseState) {
    AYPromiseStatePending = 1 << 0, /**< 待执行状态 */
    AYPromiseStateFulfilled = 1 << 1, /**< 成功状态 */
    AYPromiseStateRejected = 1 << 2 /**< 失败状态 */
};

@interface AYPromise<ValueType> : NSObject
- (instancetype)init __attribute__((unavailable("不允许直接实例化")));
+ (instancetype)new __attribute__((unavailable("不允许直接实例化")));

@property (nonatomic, readonly, assign) AYPromiseState state; /**< Promise当前状态 */
@property (nonatomic, readonly) id value; /**< Promise的执行结果，失败时，执行结果为NSError对象 */
@end

/**
 *  CommonJS Promise/A 标准接口
 */
@interface AYPromise (CommonJS)
/**
 *  接受的参数如果是Promise对象就直接返回
 *  如果参数是NSError对象，就会生成一个失败态(rejected)的promise，并传递给之后的catch
 *  参数为其它的值则生成一个成功态(fulfilled)的promise，并传递给之后的then
 */
+ (AYPromise *(^)(id _Nullable value))resolve;

/**
 *  AYPromise.all用来包装一系列的promise对象，返回一个包装后的promise对象，我们称之为A
 *  1. 当所有的promise对象都变成成功态(fulfilled)后，这个包装后的A才会把自己变成成功状态。
 *    A会等最慢的那个promise对象变成成功态(fulfilled)后才把自己变成成功态。
 *  2. 只要其中一个promise对象变成失败态(rejected)，包装后的A就变成rejected，
 *    并且第一个rejected传递的值，会传递给A后面的catch。
 */
+ (AYPromise *(^)(NSArray<AYPromise *> *promises))all;

/**
 *  AYPromise.race用来包装一系列的promise对象，返回一个包装后的promise对象，我们称之为R
 *  1. 只要其中的一个promise对象变成成功态(fulfilled)后，这个包装后的R就会变成成功态(fulfilled)，
 *    并且其它的promise不再执行。
 *  2. 当所有的promise对象都变成失败态(rejected)后，这个包装后的R才会把自己变成失败状态。
 */
+ (AYPromise *(^)(NSArray<AYPromise *> *promises))race;

/**
 *  then接受成功回调
 *  如果Promise对象处于预备状态就等待，直到状态改变才开始执行
 *  如果Promise对象处于成功态，再用then添加回调就直接调用对应的回调
 *  如果then的返回值不是Promise，会作为下一个then的参数
 *  如果then的返回值是Promise对象，那么之后的then添加的操作函数会被托管给返回的Promise对象
 *  如果value是一个Promise,则认为then的返回值是Promise对象
 *  如果value是一个NSInvocation对象,则将上一个Promise的结果作为参数调用NSInvocation
 */
- (AYPromise *(^)(id value))then;

/**
 *  catch接受失败回调
 *  如果promise对象处于预备状态就等待，直到状态改变才开始执行
 *  如果promise对象处于失败态，再用catch添加回调就直接调用对应的回调
 *  如果catch的返回值不是promise，会作为下一个then的参数
 *  如果catch的返回值是一个新的promise对象，那么之后的then添加的操作函数会被托管给新的promise对象
 */
- (AYPromise *(^)(id value))catch;
@end

/**
 *  标准接口之外添加的便利方法
 */
@interface AYPromise (Extension)
- (AYPromise *(^)(id value))thenAsync;/**< 异步执行 */
- (AYPromise *(^)(NSTimeInterval delaySecond, id value))thenDelay;/**< 延迟执行 */
- (AYPromise *(^)(dispatch_queue_t queue, id value))thenOn;/**< 在指定线程执行 */
- (AYPromise *(^)(void (^resolver)(id result, AYResolve resolve)))thenPromise;/**< 需要回调的任务 */
- (AYPromise *(^)(void (^resolver)(id result, AYResolve resolve)))thenAsyncPromise;/**< 异步执行需要回调的任务 */
- (AYPromise *(^)(id value))catchAsync;/**< 异步处理错误 */
- (AYPromise *(^)(dispatch_queue_t queue, id value))catchOn;/**< 在指定线程处理错误 */
- (AYPromise *(^)(id value))always;/**< 无论错误还是正确都执行 */
@end
/**
 *  创建Promise对象
 *
 *  如果value是block，则创建一个Pending状态的Promise并同步执行block
 *  如果value是NSInvocation对象，则创建一个Pending状态的Promise并同步执行NSInvocation
 *  如果value是Promise, 则直接返回Promise
 *  如果vlaue是数组，则返回Promise.all封装的Promise
 *  如果vlaue是NSError对象，则返回一个Rejected状态的Promise
 *  如果vlaue是其它的对象，则返回一个Fulfilled状态的Promise
 */
FOUNDATION_EXPORT AYPromise *AYPromiseWith(_Nullable id value);
/**
 *  创建Promise对象
 *
 *  如果value是block，则创建一个Pending状态的Promise并异步执行block
 *  其它同上
 */
FOUNDATION_EXPORT AYPromise *AYPromiseAsyncWith(_Nullable id value);
/**
 *  创建一个需要回调的Promise
 */
FOUNDATION_EXPORT AYPromise *AYPromiseWithResolve(void (^)(AYResolve resolve));
/**
 *  创建一个异步执行，需要回调的Promise
 */
FOUNDATION_EXPORT AYPromise *AYPromiseAsyncWithResolve(void (^)(AYResolve resolve));
NS_ASSUME_NONNULL_END


