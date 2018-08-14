//
//  ViewController.m
//  YLObfuscatedCode
//
//  Created by Conner on 2018/8/14.
//  Copyright © 2018年 Conner. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
/**
 项目路径
 */
@property (weak) IBOutlet NSTextField *projectPathTF;
/**
 修改项目名
 */
@property (weak) IBOutlet NSTextField *changeProjectNameTF;
/**
 原前缀
 */
@property (weak) IBOutlet NSTextField *prefixOldTF;
/**
 新前缀
 */
@property (weak) IBOutlet NSTextField *prefixNewTF;
/**
 修改资源文件
 */
@property (weak) IBOutlet NSButton *modifyResourceBtn;
/**
 删除注释
 */
@property (weak) IBOutlet NSButton *removeCommentsBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
