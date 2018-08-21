//
//  NSString+Category.h
//  YLObfuscatedCode
//
//  Created by Conner on 2018/8/14.
//  Copyright © 2018年 Conner. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Category)
/**
 *  校验空字符串
 *
 *  @param string 需要校验的字符串
 *
 *  @return YES/NO
 */
+ (BOOL)checkStringEmpty:(NSString *)string;
@end
