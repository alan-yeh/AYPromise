# AYPromise

[![CI Status](http://img.shields.io/travis/alan-yeh/AYPromise.svg?style=flat)](https://travis-ci.org/alan-yeh/AYPromise)
[![Version](https://img.shields.io/cocoapods/v/AYPromise.svg?style=flat)](http://cocoapods.org/pods/AYPromise)
[![License](https://img.shields.io/cocoapods/l/AYPromise.svg?style=flat)](http://cocoapods.org/pods/AYPromise)
[![Platform](https://img.shields.io/cocoapods/p/AYPromise.svg?style=flat)](http://cocoapods.org/pods/AYPromise)

## 获取Promise
　　使用[CocoaPods](http://cocoapods.org)可以很方便地引入Promise。Podfile添加AYPromise的依赖。

```ruby
pod "AYPromise"
```

## 文档
　　[具体文档](DOC.md)。

## 简介
### 什么是Promise
　　Promise，承诺，在开发中的意思是，我承诺我去做一些事情，但不一定现在就去做，而是在将来满足一些条件之后才执行。Promise刚开始出现在前端开发领域中，主要用来解决JS开发中的异步问题。在使用Promise之前，异步的处理使用最多的就是用回调这种形式，比如：

```javascript
doSomethingAsync(function(result, error){
    if (error){
        ...//处理error
    } else {
        ...//处理result
    }
})
```
　　在Objective-C中，这类代码也是非常常见的。例如著名的AFNetworking中，访问网络就是使用block回调。

```objective-c
    [client getPath:@"xxx"
         parameters:params
            success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //处理success
            }
            failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                //处理failure
            }]
```

　　这种书写方式，可以很容易解决对异步操作的处理。但是这样的写法，很容易引起回调金字塔的情况。Promise则对异步处理和处理方法都做了规范和抽象，还给了开发者在异步代码中使用return和throw的能力。这也是Promise存在的真正意义。
### 使用Promise
　　来看一个常见的业务场景，获取联系人需要先访问一次服务器(登录或一些必要的操作)，然后再访问一次服务器才能真正获取到有效数据，然后再进行一系列的错误处理，代码冗余复杂。

```objective-c
- (void)getContactSuccess:(void(^)(NSArray *))success failure:(void(^)(NSError *))failure{
    [client getPath:@"xxx"
         parameters:params
            success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //处理Json序列化
                NSError *error;
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:&error];
                if (error) {
                    failure(error);
                    return;
                }
                if ([dic[@"status"] intValue] == 200) {
                    //需要依赖上一次网络访问的结果，进行下一步访问
                    [client getPath:@"yyy"
                         parameters:params
                            success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                //处理Json
                                //处理业务
                                //组装实体
                                //....
                                success(result);
                            }
                            failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                //处理网络错误
                                failure(error);
                            }];
                }else{
                    //处理错误
                    failure(/*返回错误*/);
                }
            }
            failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                //处理网络错误
                failure(error);
            }];
}
```

　　使用Promise改造一下

```objective-c
//网络访问与业务分离
- (AYPromise *)get:(NSString *)getPath withParam:(id)param{
    return AYPromiseWithResolve(^(AYResolve resolve){
        [client getPath:@"xxx"
             parameters:param
                success:^(AFHTTPRequestOperation *operation, id responseObject) {
                    resolve(responseObject);
              } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    resolve(error);
         }];
    });
}
//Json序列化与业务分离
- (AYPromise *)parseJson:(id)responseObject{
    return AYPromiseWith(^id{
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:&error];
        if (error) {
            return error;
        }else{
            return json;
        }
    });
}

- (AYPromise *)getContacts{
    return AYPromiseWith(^{
        //第一次访问网络
        return [self get:@"xxx" withParam:params];
    }).then(^(id responseObject){
        //处理Json序列化
        return [self parseJson:responseObject];
    }).then(^(NSDictionary *json){
        //第二次访问网络
        return [self get:@"yyy" withParam:params];
    }).then(^(id responseObject){
        //再次处理Json序列化
        return [self parseJson:responseObject];
    }).then(^(NSDictionary* result){
        //处理业务正确性
        if ([result[@"status"] intValue] == 200){
            return result;
        }else{
            return error;/*构建一个NSError对象返回*/
        }
    }).then(^(NSDictionary* result){
        //组装实体
    });
}
```

　　可以看到，通过Promise的改造，原本层层嵌套代码，变得有序、清晰起来。什么？你问哪里处理错误？放心，通过Promise，可以进行统一的错误处理。

## License

AYPromise is available under the MIT license. See the LICENSE file for more info.
