//
//  AYViewController.m
//  AYPromise
//
//  Created by Alan Yeh on 07/22/2016.
//  Copyright (c) 2016 Alan Yeh. All rights reserved.
//

#import "AYViewController.h"
#import "LoginApi.h"
#import "ContactApi.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface AYViewController ()
@property (weak, nonatomic) IBOutlet UITextField *username;

@property (weak, nonatomic) IBOutlet UITextField *password;
@end

@implementation AYViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)normal:(id)sender {
    [SVProgressHUD showWithStatus:@"正在登录..."];
    //登录
    [[LoginApi api] loginWithUserName:self.username.text
                          andPassword:self.password.text
                              success:^(NSString *msg) {
                                  
                                  //获取联系人
                                  [SVProgressHUD showWithStatus:@"获取联系人..."];
                                  [[ContactApi api] loadContactSuccess:^(NSArray<Contact *> *contact) {
                                      //显示联系人
                                      [SVProgressHUD showSuccessWithStatus:@"获取成功"];
                                      NSLog(@"成功，数据为%@", contact);
                                  }
                                                               failure:^(NSString *error) {
                                                                   //获取联系人失败
                                                                   [SVProgressHUD showErrorWithStatus:error];
                                                               }];
                              }
                              failure:^(NSString *error) {
                                  //登录失败
                                  [SVProgressHUD showErrorWithStatus:error];
                              }];
}









- (IBAction)promise:(id)sender {
    [SVProgressHUD showWithStatus:@"正在登录..."];
    
    //登录
    [[LoginApi api] loginWithUserName:self.username.text andPassword:self.password.text]
    
    //获取联系人
    .then(^{
        [SVProgressHUD showWithStatus:@"获取联系人..."];
        return [ContactApi api].loadContact;
    })
    
    //显示联系人
    .then(^(NSMutableArray<Contact *> *contact){
        [SVProgressHUD showSuccessWithStatus:@"获取成功"];
        //处理
        NSLog(@"成功，数据为%@", contact);
    })
    
    //显示错误信息
    .catch(^(NSError *error){
        [SVProgressHUD showErrorWithStatus:error.localizedDescription];
    });
}
@end
