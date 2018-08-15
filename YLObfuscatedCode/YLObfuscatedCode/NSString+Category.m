//
//  NSString+Category.m
//  YLObfuscatedCode
//
//  Created by Conner on 2018/8/14.
//  Copyright © 2018年 Conner. All rights reserved.
//

#import "NSString+Category.h"

@implementation NSString (Category)
//校验空字符串
+ (BOOL)checkStringEmpty:(NSString *)string {
    if ((NSNull *)string == [NSNull null]) {
        return YES;
    }
    if (string == nil || [string length] == 0) {
        return YES;
    } else if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
        return YES;
    }
    return NO;
}
@end
