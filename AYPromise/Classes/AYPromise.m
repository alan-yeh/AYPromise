//
//  AYPromise.m
//  AYPromise
//
//  Created by PoiSon on 16/2/21.
//  Copyright © 2016年 PoiSon. All rights reserved.
//

#import "AYPromise.h"
#import <libkern/OSAtomic.h>

#define isError(obj) [obj isKindOfClass:[NSError class]]
#define isPromise(obj) [obj isKindOfClass:[AYPromise class]]
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

/**
 *  @see CTObjectiveCRuntimeAdditions https://github.com/ebf/CTObjectiveCRuntimeAdditions
 */
struct PSBlockLiteral {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct ps_block_descriptor {
        unsigned long int reserved;	// NULL
        unsigned long int size;         // sizeof(struct Block_literal_1)
        // optional helper functions
        void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
        void (*dispose_helper)(void *src);             // IFF (1<<25)
        // required ABI.2010.3.16
        const char *signature;                         // IFF (1<<30)
    } *descriptor;
    // imported variables
};

typedef NS_ENUM(NSUInteger, PSBlockDescriptionFlags) {
    PSBlockDescriptionFlagsHasCopyDispose = (1 << 25),
    PSBlockDescriptionFlagsHasCtor = (1 << 26), // helpers have C++ code
    PSBlockDescriptionFlagsIsGlobal = (1 << 28),
    PSBlockDescriptionFlagsHasStret = (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    PSBlockDescriptionFlagsHasSignature = (1 << 30)
};

static NSMethodSignature *_signatureForBlock(id block) {
    if (!block)
        return nil;
    
    struct PSBlockLiteral *blockRef = (__bridge struct PSBlockLiteral *)block;
    PSBlockDescriptionFlags flags = (PSBlockDescriptionFlags)blockRef->flags;
    
    if (flags & PSBlockDescriptionFlagsHasSignature) {
        void *signatureLocation = blockRef->descriptor;
        signatureLocation += sizeof(unsigned long int);
        signatureLocation += sizeof(unsigned long int);
        
        if (flags & PSBlockDescriptionFlagsHasCopyDispose) {
            signatureLocation += sizeof(void (*)(void *dst, void *src));
            signatureLocation += sizeof(void (*)(void *src));
        }
        
        const char *signature = (*(const char **)signatureLocation);
        return [NSMethodSignature signatureWithObjCTypes:signature];
    }
    return nil;
}

static id _call_block(id block, id args){
    NSMethodSignature *signature = _signatureForBlock(block);
    
    const char returnType = signature.methodReturnType[0];
    if (returnType != '@' && returnType != 'v') {
        [NSException raise:NSInvalidArgumentException format:@"AYPromise无法处理非对象返回值，block返回值必须是OC对象"];
    }
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:[block copy]];
    if (args && signature.numberOfArguments > 1) {
        [invocation setArgument:&args atIndex:1];
    }
    
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
@property (nonatomic, strong) NSMutableArray<PSResolve> *handlers;
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
- (instancetype)initWithResolver:(void (^)(PSResolve))resolver{
    if (self = [super init]) {
        _state = AYPromiseStatePending;
        
        PSResolve __presolve = ^(id result){
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
            for (PSResolve handler in handlers) {
                handler(result);
            }
        };
        
        PSResolve __resolve = ^(id result){
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
- (void)pipe:(PSResolve)resolve{
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
static inline AYPromise *__pipe(AYPromise *self, void(^then)(id, PSResolve)){
    return [[AYPromise alloc] initWithResolver:^(PSResolve resolver) {
        [self pipe:^(id result) {
            then(result, resolver);//handle resule of previous promise
        }];
    }];
}

/**
 *  将Promise拼接在self之后,仅处理正确的逻辑
 */
static inline AYPromise *__then(AYPromise *self, dispatch_queue_t queue, id block){
    return __pipe(self, ^(id result, PSResolve resolver) {
        if (isError(result)) {
            resolver(result);
        }else{
            dispatch_async(queue, ^{
                resolver(_call_block(block, result));
            });
        }
    });
}
/**
 *  将Promise接接在self之后,仅处理错误的逻辑
 */
static inline AYPromise *__catch(AYPromise *self, dispatch_queue_t queue, id block){
    return __pipe(self, ^(id result, PSResolve resolver) {
        if (isError(result)) {
            dispatch_async(queue, ^{
                resolver(_call_block(block, result));
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
        return [[AYPromise alloc] initWithResolver:^(PSResolve resolve) {
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
        
        return [[AYPromise alloc] initWithResolver:^(PSResolve resolve) {
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
        if (isBlock(value)) {
            return __then(self, dispatch_get_main_queue(), value);
        }else if (isPromise(value)){
            return __then(self, dispatch_get_main_queue(), ^{
                return value;
            });
        }else{
            NSAssert(NO, @"then can only handle block and promise");
            return nil;
        }
    };
}

- (AYPromise *(^)(id))catch{
    return ^(id block){
        NSAssert(isBlock(block), @"catch can only handle block.");
        return __catch(self, dispatch_get_main_queue(), block);
    };
}
@end

@implementation AYPromise (Extension)
- (AYPromise *(^)(id))thenAsync{
    return ^(id block){
        NSAssert(isBlock(block), @"thenAsync can only handle block.");
        return __then(self, dispatch_get_global_queue(0, 0), block);
    };
}

- (AYPromise *(^)(NSTimeInterval, id))thenDelay{
    return ^(NSTimeInterval delaySecond, id block){
        NSAssert(isBlock(block), @"thenDelay can only handle block.");
        return __pipe(self, ^(id result, PSResolve resolver) {
            if (isError(result)) {
                resolver(result);
            }else{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySecond * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        resolver(_call_block(block, result));
                    });
                });
            }
        });
    };
}

- (AYPromise *(^)(dispatch_queue_t, id))thenOn{
    return ^(dispatch_queue_t queue, id block){
        NSAssert(isBlock(block), @"thenOn can only handle block.");
        return __then(self, queue, block);
    };
}

- (AYPromise * (^)(void (^)(id, PSResolve)))thenPromise{
    return ^(void (^resolver)(id, PSResolve)){
        return __pipe(self, ^(id result, PSResolve resolve) {
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
    return ^(id block){
        NSAssert(isBlock(block), @"catchAsync can only handle block.");
        return __catch(self, dispatch_get_global_queue(0, 0), block);
    };
}

- (AYPromise *(^)(dispatch_queue_t, id))catchOn{
    return ^(dispatch_queue_t queue, id block){
        NSAssert(isBlock(block), @"catchOn can only handle block.");
        return __catch(self, queue, block);
    };
}

- (AYPromise *(^)(id))always{
    return ^(id block){
        NSAssert(isBlock(block), @"always can only handle block.");
        return __pipe(self, ^(id result, PSResolve resolver) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {
                    resolver(_call_block(block, result));
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
    if (isBlock(value)) {
        return AYPromise.resolve(nil).then(value);
    }else if (isArray(value)){
        return AYPromise.all(value);
    }else {
        return [[AYPromise alloc] initWithValue:value];
    }
}

AYPromise *AYPromiseAsyncWith(id value){
    if (isBlock(value)) {
        return AYPromise.resolve(nil).thenAsync(value);
    }else{
        return AYPromiseWith(value);
    }
}

AYPromise *AYPromiseWithResolve(void (^resolver)(PSResolve)){
    return [[AYPromise alloc] initWithResolver:resolver];
}

