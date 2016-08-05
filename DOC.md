# Promise
## 状态
　　每个Promise都只会被执行一次，执行完毕后，Promise就会变成成功或失败状态，并且这个状态不会被改变。

　　一个Promise必须处于以下几个状态之一：

* AYPromiseStatePending(Pending): 操作正在执行中(等待执行)，可以转换到Fulfilled或Rejected状态。
* AYPromiseStateFulfilled(Fulfilled): 操作执行成功，且状态不可改变
* AYPromiseStateRejected(Rejected): 操作执行失败，且状态不可改变

　　有些文章或Promise实现会出现第4种状态Settled，代表操作已结束，可以认为Settled = Fulfilled & Rejected。他本身并不是一种状态，因为非Pending就是Settled，只是为了说的方便而引入Settled这个说法。

　　Promise处于Pending状态时，其value一定为nil；处于Fulfilled状态时，其value为处理结果，可能为nil；处于Rejected状态时，其value一定为NSError对象，用于描述Promise被拒绝原因。

## CommonJS Promise/A
　　AYPromise支持标准的CommonJS Promise/A语法。由于语言的特殊，对其中部份Api进行小量改造。
### 构造函数
　　由于AYPromise使用链式调用语法，抛弃OC的传统构造函数，使用C构造AYPromise对象更有利于书写方便。AYPromise有以下构造函数：

#### `AYPromise *AYPromiseWithResolve(void (^)(AYResolve resolve))`

```objective-c
AYPromise *promise = AYPromiseWithResolve(^(AYResolve resolve){
    resolve(@"aaa");
});
```
　　使用AYPromiseWithResolve创建Promise后，会立刻开始在主线程执行block。AYPromiseWithResolve提供了一个回调AYResolve，使用`resolve(value)`返回结果。结果的类型不一样，会导至Promise的行为不一样，返回值可以为以下类型：

- Promise，当前的Promise对象被抛弃，并将当前Promise链之后的Promise被托管至返回的Promise对象
- NSError，当前Promise的状态变更成Rejected状态
- 其它对象(包括nil)，当前Promise的状态变更成Fulfilled

#### `AYPromise *AYPromiseAsyncWithResolve(void (^)(AYResolve resolve))`

```objective-c
AYPromise *promise = AYPromiseAsyncWithResolve(^(AYResolve resolve){
    resolve(@"aaa");
});
```
　　AYPromiseAysncWithResolve是异步执行的AYPromiseWithResolve。

#### `AYPromise *AYPromiseWith(id value)`

```objective-c
AYPromise *promise = AYPromiseWith(^{
    return @"aaa";
});
```
　　AYPromiseWith创建Promise对象，参数value可以为以下类型：

- block，创建一个Pending状态的Promise并同步执行block
- NSInvocation，创建一个Pending状态的Promise并同步执行invocation
- Promise，直接返回该Promise对象
- 数组，返回Promise.all封装的Promise
- NSError，返回一个Rejected状态的Promise
- 其它对象(包括nil)，返回一个Fulfilled状态的Promise

#### `AYPromise *AYPromiseAsyncWith(id value)`

```objective-c
AYPromise *promise = AYPromiseAsyncWith(^{
    //异步执行
    return [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:@"https://www.baidu.com"] encoding:NSUTF8StringEncoding error:nil];
});
```
　　AYPromiseAsyncWith创建异步执行的Promise
### then
　　then语法用于处理正确(Fulfilled)的Promise结果。在CommonJS Promise/A的语法中，then应该支持2个回调函数，第一个回调函数处理Fulfilled的结果，第二个回调函数处理Rejected的结果。为了减少其书写上的复杂性，AYPromise的then语法仅支持1个block，用于处理正确(Fulfilled)结果。

```objective-c
promise.then(^(NSString *result){
	return [result stringByAppendingString:@"bbb"];
});
```

　　then语法必须接受一个不为空的block类型的参数。then语法中的block支持无参或1个参数。

　　如果block：

* 返回普通OC对象(包括nil)，当前Promise状态变更成Fulfilled，vlaue被赋值为返回值。
* 没有返回值，当前Promise状态变更成Fulfilled，value被赋值为nil。
* 返回NSError对象，当前Promise状态变更成Rejected，value被赋值为NSError对象。
* 返回Promise对象，当前Promise对象抛弃，当前Promise链之后的Promise被托管至返回的Promise对象。
* 抛出错误(仅捕捉NSError错误，不捕捉其它对象)，当前Promise状态变更成Rejected，value被赋值为NSError对象。

### catch
　　catch语法用于处理被拒绝(Rejected)的Promise对象的结果。

```objective-c
AYPromiseWithResolve:(^(AYResolve resolve){
    NSError *error = ...;
    resolve(error);
}).then(^{
	//由于Promise为Rejected，因此then不执行
}).catch(^(NSError *error){
	//处理Promise为Rejected
}).catch(^(NSError *error){
	//由于当前的catch之前，Rejected的Promise已经被处理了，所以这个catch不执行
});
```
　　catch语法必须接受一个不为空的block类型参数。catch语法中的block支持无参或1个NSError参数。catch专门用于处理被拒绝(Rejected)的Promise，then专门处理正确(Fulfilled)的Promise。

```objective-c
AYPromiseWithResolve:(^(AYResolve resolve){
    resolve(@"aaa");
}).then(^{
	NSError *error;//业务产生了一个错误
	@throw error;//直接抛出异常可以被下一个catch捕捉到
	//return error;//直接返回也可以被下一个catch捕捉到
}).catch(^(NSError *error){
	//可以处理catch之前错误
});
```
### all
　　all语法是静态类函数，接受一个Promise数组，并返回一个包装后的Promise对象，称之为A。A的状态改变有两个条件：

1. 当数组中所有的promise对象变成成功状态(Fulfilled)，这个包装后的A才会把自己变成成功状态。A会等待最慢的那个promise对象变成成功态后才把自己变成成功态，并将promise数组的结果封装成它们的结果数据。
2. 只要其中一个promise对象变成失败状态(Rejected)，这个包装后的A就变成失败状态，并且第一个rejected promise传递过来的NSError值会传递给A后面的catch。

　　因此，all语法可以理解为判断语句『且』，当所有条件都成功时它才成功，当有一个条件失败时，它就是失败。

```objective-c
AYPromise *p1 = AYPromiseWith(^{
    return @"aa";
});
AYPromise *p2 = AYPromiseWith(^{
    @throw error;
});
AYPromise *p3 = AYPromiseWith(^{
    return @"cc";
});

AYPromise *pAll = AYPromise.all(@[p1, p2, p3]).then(^(NSArray *result){
    //then语法不会执行，因为p2抛出异常了
}).catch(^(NSError *error){
    //catch会执行，捕捉到p2所抛出来的错误
});
    
/************************************************************/

AYPromise *p1 = AYPromiseWith(^{
    return @"aa";
});
AYPromise *p2 = AYPromiseWith(^{
    return @"bb";
});
AYPromise *p3 = AYPromiseWith(^{
    return @"cc";
});

AYPromise *pAll = AYPromise.all(@[p1, p2, p3]).then(^(NSArray *result){
    //then会执行，result = @[@"aa", @"bb", @"cc"];
}).catch(^(NSError *error){
    //catch不会执行
});
```

### race
　　race语法是静态类函数，接受一个Promise数组，并返回一个包装后的Promise对象，称之为R。R的状态改变有两个条件:

1. 当数组中所有的promise对象变成失败状态(Rejected)，这个包装后的R才会把自己变成失败状态。R会等待最慢的那个promise对象变成失败状态后才把自己变成失败态，并将promise数组所有NSError封装成一个NSError传递给后面的catch。
2. 只要其中一个promise对象变成成功状态(Fulfilled)，这个包装后的R就变成成功状态，并且将第一个fulfilled promise的结果值传给R后面的then。

　　因此，race语法可以理解为判断语句的『或』，当所有条件都失败时它才失败，当其中一个条件成功时，它成功。

```objective-c
AYPromise *p1 = AYPromiseWith(^{
    return @"aa";
});
AYPromise *p2 = AYPromiseWith(^{
    @throw error;
});
AYPromise *p3 = AYPromiseWithResolve:(^(AYResolve resolve){
    resolve(@"cc");
});

AYPromise *pRace = AYPromise.race(@[p1, p2, p3]).then(^(NSString *result){
    //then会执行，result = @"aa"
}).catch(^(NSError *error){
    //catch不会执行，因为p1是成功状态，代表race是成功的
});
    
/************************************************************/

AYPromise *p1 = AYPromiseWith(^{
    @throw error;
});
AYPromise *p2 = AYPromiseWithResolve:(^(AYResolve resolve){
    resolve(error);
});
AYPromise *p3 = AYPromiseWith(^{
    return error;
});

AYPromise *pRace = AYPromise.race(@[p1, p2, p3]).then(^(NSString *result){
    //then不会执行，因为race中所有的promise都失败了
}).catch(^(NSError *error){
    //catch会执行，并且NSArray<NSError *> *errors = error.userInfo[AYPromiseInternalErrorsKey]可以获取所有错误
});
```

### 扩展语法
　　CommonJS Promise/A中的语法较少，考虑到OC实际运用时的便捷性，AYPromise增加了一些实用方法。
### always
　　always语法与then、catch语法类似，与then只处理正确逻辑、catch只处理错误逻辑不同的是，always总是会执行。
### thenAsync
　　thenAsync与then语法使用一致，但是该方法是在`dispatch_get_global_queue(0, 0)`线程中执行，而then方法总是在主线程中执行。
### thenOn
　　thenOn与then语法使用一致，但参数要求用户传递一个指定线程，则block在该线程下执行。
### thenPromise
　　thenPromise是then语法的一个变种，通过回调来返回结果
### catchAsync
　　catchAsync语法与catch语法使用方法一致，但是该方法是在`dispatch_get_global_queue(0, 0)`线程中执行，而catch方法总是在主线程中执行。
### catchOn
　　catchOn与catch语法使用方法一致，但参数要求用户传递一个指定线程，则block在该线程下执行。
## 其它

1. 关于多线程：AYPromise的方法中，如果没有Async、On这类标识，则block会在主线程中执行，否则会在`dispatch_get_global_queue(0, 0)`或用户指定的线程中执行，添加这些方法主要方便用户在各个线程中切换。

2. 关于泛型：AYPromise其实不支持泛型。但是为什么又引用泛型，目的是在于当Promise作为函数结果返回时，标识一下当前Promise将会返回什么样的数据，当继续then的时候，可以知道then所获取的结果是一个怎么样的类型。
