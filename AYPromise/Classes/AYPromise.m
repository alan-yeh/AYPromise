//
//  AYPromise.m
//  AYPromise
//
//  Created by Alan Yeh on 16/2/21.
//  Copyright © 2016年 Alan Yeh. All rights reserved.
//

#import "AYPromise.h"
#import <libkern/OSAtomic.h>
#import <AYRuntime/AYBlockInvocation.h>

#define isError(obj) [obj isKindOfClass:[NSError class]]
#define isPromise(obj) [obj isKindOfClass:[AYPromise class]]
#define isInvocation(obj) [obj isKindOfClass:[NSInvocation class]]
#define isBlock(obj) [obj isKindOfClass:NSClassFromString(@"NSBlock")]
#define isArray(obj) [obj isKindOfClass:[NSArray class]]

NSString * const AYPromiseInternalErrorsKey = @"AYPromiseInternalErrorsKey";

NSError *NSErrorMake(id _Nullable internalErrors, NSString *localizedDescription, ...){
    static NSString *domain = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        domain = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
        domain = domain ?: @"none domain";
    });
    
    va_list desc_args;
    va_start(desc_args, localizedDescription);
    NSString *desc = [[NSString alloc] initWithFormat:localizedDescription arguments:desc_args];
    va_end(desc_args);
    
    return [NSError errorWithDomain:domain code:-1000 userInfo:@{
                                                                 NSLocalizedDescriptionKey: desc,
                                                                 AYPromiseInternalErrorsKey: internalErrors ?: [NSNull null]
                                                                 }];
}

NSInvocation *NSInvocationMake(id target, SEL action){
    NSCParameterAssert([target respondsToSelector:action]);
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:action]];
    invocation.target = target;
    invocation.selector = action;
    return invocation;
}

static id __execute__(id target, id args){
    NSCParameterAssert(isBlock(target) || isInvocation(target));
    
    NSMethodSignature *signature;
    id invocation;
    
    if (isBlock(target)) {
        invocation = [AYBlockInvocation invocationWithBlock:target];
        signature = [invocation blockSignature].signature;
        if (args && signature.numberOfArguments > 1) {
            [invocation setArgument:&args atIndex:1];
        }
    }else{
        //target is NSInvocation object
        invocation = target;
        signature = [target methodSignature];
        if (args && signature.numberOfArguments > 2) {
            [invocation setArgument:&args atIndex:2];
        }
    }
    
    const char returnType = signature.methodReturnType[0];
    NSCAssert(returnType == '@' || returnType == 'v', @"AYPromise无法处理非对象返回值，返回值必须是OC对象");
    
    @try {
        [invocation invoke];
        
        if (returnType == 'v') { return nil; }
        __unsafe_unretained id result;
        [invocation getReturnValue:&result];
        return result;
    }
    @catch (NSError *error) {// just catch NSError
        return error;
    }
}

@interface AYPromise()
@property (nonatomic) dispatch_queue_t barrier;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) NSMutableArray<AYResolve> *handlers;
@end

@implementation AYPromise
- (dispatch_queue_t)barrier{
    return _barrier ?: (_barrier = dispatch_queue_create("cn.yerl.promise.barrier", DISPATCH_QUEUE_CONCURRENT));
}

- (NSMutableArray *)handlers{
    return _handlers ?: (_handlers = [NSMutableArray new]);
}

/**
 *  创建一个未执行的Promise
 */
- (instancetype)initWithResolver:(void (^)(AYResolve))resolver{
    if (self = [super init]) {
        _state = AYPromiseStatePending;
        
        AYResolve __presolve = ^(id result){
            __block NSMutableArray *handlers;
            //保证执行链的顺序执行
            dispatch_barrier_sync(self.barrier, ^{
                //race
                if (self.state == AYPromiseStatePending) {
                    handlers = self.handlers;
                    
                    if (isError(result)) {
                        _state = AYPromiseStateRejected;
                    }else{
                        _state = AYPromiseStateFulfilled;
                    }
                    self.value = result;
                }
            });
            for (AYResolve handler in handlers) {
                handler(result);
            }
        };
        
        AYResolve __resolve = ^(id result){
            if (self.state & AYPromiseStatePending) {
                if (isPromise(result)) {
                    [result pipe:__presolve];
                }else{
                    __presolve(result);
                }
            }
        };
        //创建好之后，直接开始执行任务
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                resolver(__resolve);
            }
            @catch (NSError *error) {
                __resolve(error);
            }
        });
    }
    return self;
}

/**
 *  创建一个已完成的Promise
 *  如果Value是Promise对象，则直接返回
 *  如果Value是NSError对象，则返回一个Rejected状态的Promise
 *  如果Vlaue是其它对象，则返回一个Fulfilled状态的Promise
 */
- (instancetype)initWithValue:(id)value{
    if (isPromise(value)) {
        return value;
    }
    if (self = [super init]) {
        if (isError(value)) {
            _state = AYPromiseStateRejected;
            self.value = value;
        }else{
            _state = AYPromiseStateFulfilled;
            self.value = value;
        }
    }
    return self;
}
/**
 *  拼接Promise
 *  如果当前Promise还没有被执行，则接接在当前Promise的执行栈中
 *  如果当前Promise已经执行了，则直接将当前Promise的值传给下一个执行者
 */
- (void)pipe:(AYResolve)resolve{
    if (self.state == AYPromiseStatePending) {
        [self.handlers addObject:resolve];
    }else{
        resolve(self.value);
    }
}

/**
 *  创建一个Promise,并拼接在Promise(self)的执行链中
 *
 */
static inline AYPromise *__pipe(AYPromise *self, void(^then)(id, AYResolve)){
    return [[AYPromise alloc] initWithResolver:^(AYResolve resolver) {
        [self pipe:^(id result) {
            then(result, resolver);//handle resule of previous promise
        }];
    }];
}

/**
 *  将Promise拼接在self之后,仅处理正确的逻辑
 */
static inline AYPromise *__then(AYPromise *self, dispatch_queue_t queue, id block){
    return __pipe(self, ^(id result, AYResolve resolver) {
        if (isError(result)) {
            resolver(result);
        }else{
            dispatch_async(queue, ^{
                resolver(__execute__(block, result));
            });
        }
    });
}
/**
 *  将Promise接接在self之后,仅处理错误的逻辑
 */
static inline AYPromise *__catch(AYPromise *self, dispatch_queue_t queue, id block){
    return __pipe(self, ^(id result, AYResolve resolver) {
        if (isError(result)) {
            dispatch_async(queue, ^{
                resolver(__execute__(block, result));
            });
        }else{
            resolver(result);
        }
    });
}

@end

@implementation AYPromise (CommonJS)
+ (AYPromise *(^)(id))resolve{
    return ^(id value){
        return [[self alloc] initWithValue:value];
    };
}

+ (AYPromise *(^)(NSArray<AYPromise *> *))all{
    return ^(NSArray<AYPromise *> *promises){
        return [[AYPromise alloc] initWithResolver:^(AYResolve resolve) {
            NSAssert(isArray(promises), @"all can only hand array");
            
            __block int64_t totalCount = [promises count];
            for (__strong id promise in promises) {
                if (!isPromise(promise)) {
                    promise = AYPromise.resolve(promise);
                }
                [promise pipe:^(id result) {
                    if (isError(result)) {
                        resolve([NSError errorWithDomain:@"cn.yerl.promise"
                                                    code:-1000
                                                userInfo:@{NSLocalizedDescriptionKey: [result localizedDescription],
                                                           AYPromiseInternalErrorsKey: result}]);
                    }else if (OSAtomicDecrement64(&totalCount) == 0){
                        id results = [NSMutableArray new];
                        for (AYPromise *promise in promises) {
                            id value = isPromise(promise) ? [promise value] : promise;
                            [results addObject:value ?: [NSNull null]];
                        }
                        resolve(results);
                    }
                }];
            }
        }];
    };
}

+ (AYPromise *(^)(NSArray<AYPromise *> *))race{
    return ^(NSArray<AYPromise *> *promises){
        NSAssert(isArray(promises), @"race can only hand array");
        
        return [[AYPromise alloc] initWithResolver:^(AYResolve resolve) {
            __block int64_t totalCount = [promises count];
            for (__strong id promise in promises) {
                if (!isPromise(promise)) {
                    promise = [[AYPromise alloc] initWithValue:promise];
                }
                [promise pipe:^(id result) {
                    if (!isError(result)) {
                        resolve(result);
                    }else if (OSAtomicDecrement64(&totalCount) == 0){
                        id errors = [NSMutableArray new];
                        for (AYPromise *promise in promises) {
                            [errors addObject:isPromise(promise) ? [promise value] : promise];
                        }
                        resolve([NSError errorWithDomain:@"cn.yerl.promise"
                                                    code:-1000
                                                userInfo:@{NSLocalizedDescriptionKey: @"all promise were rejected",
                                                           AYPromiseInternalErrorsKey: errors}]);
                    }
                }];
            }
        }];
    };
}

- (AYPromise *(^)(id))then{
    return ^id(id value){
        if (isBlock(value) || isInvocation(value)) {
            return __then(self, dispatch_get_main_queue(), value);
        }else if (isPromise(value)){
            return __then(self, dispatch_get_main_queue(), ^{
                return value;
            });
        }else{
            NSAssert(NO, @"[then] can only handle block/invocation/promise");
            return nil;
        }
    };
}

- (AYPromise *(^)(id))catch{
    return ^(id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[catch] can only handle block/invocation.");
        return __catch(self, dispatch_get_main_queue(), value);
    };
}
@end

@implementation AYPromise (Extension)
- (AYPromise *(^)(id))thenAsync{
    return ^(id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[thenAsync] can only handle block/invocation.");
        return __then(self, dispatch_get_global_queue(0, 0), value);
    };
}

- (AYPromise *(^)(NSTimeInterval, id))thenDelay{
    return ^(NSTimeInterval delaySecond, id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[thenDelay] can only handle block/invocation.");
        return __pipe(self, ^(id result, AYResolve resolver) {
            if (isError(result)) {
                resolver(result);
            }else{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySecond * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        resolver(__execute__(value, result));
                    });
                });
            }
        });
    };
}

- (AYPromise *(^)(dispatch_queue_t, id))thenOn{
    return ^(dispatch_queue_t queue, id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[thenOn] can only handle block/invocation.");
        return __then(self, queue, value);
    };
}

- (AYPromise * (^)(void (^)(id, AYResolve)))thenPromise{
    return ^(void (^resolver)(id, AYResolve)){
        return __pipe(self, ^(id result, AYResolve resolve) {
            if (!isError(result)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    @try {
                        resolver(result, resolve);
                    }
                    @catch (NSError *error) {
                        resolve(error);
                    }
                });
            }else{
                resolve(result);
            }
        });
    };
}

- (AYPromise *(^)(id))catchAsync{
    return ^(id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[catchAsync] can only handle block/invocation.");
        return __catch(self, dispatch_get_global_queue(0, 0), value);
    };
}

- (AYPromise *(^)(dispatch_queue_t, id))catchOn{
    return ^(dispatch_queue_t queue, id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[catchOn] can only handle block/invocation.");
        return __catch(self, queue, value);
    };
}

- (AYPromise *(^)(id))always{
    return ^(id value){
        NSAssert(isBlock(value) || isInvocation(value), @"[always] can only handle block/invocation.");
        return __pipe(self, ^(id result, AYResolve resolver) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    resolver(__execute__(value, result));
                }
                @catch (NSError *error) {
                    resolver(error);
                }
            });
        });
    };
}
@end

AYPromise *AYPromiseWith(id value){
    if (isBlock(value) || isInvocation(value)) {
        return AYPromise.resolve(nil).then(value);
    }else if (isArray(value)){
        return AYPromise.all(value);
    }else {
        return [[AYPromise alloc] initWithValue:value];
    }
}

AYPromise *AYPromiseAsyncWith(id value){
    if (isBlock(value) || isInvocation(value)) {
        return AYPromise.resolve(nil).thenAsync(value);
    }else{
        return AYPromiseWith(value);
    }
}

AYPromise *AYPromiseWithResolve(void (^resolver)(AYResolve)){
    return [[AYPromise alloc] initWithResolver:resolver];
}

