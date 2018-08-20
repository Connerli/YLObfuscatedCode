//
//  ViewController.m
//  YLObfuscatedCode
//
//  Created by Conner on 2018/8/14.
//  Copyright © 2018年 Conner. All rights reserved.
//

#import "ViewController.h"
#import "NSString+Category.h"
#include <stdlib.h>

// 命令行修改工程目录下所有 png 资源 hash 值
// 使用 ImageMagick 进行图片压缩，所以需要安装 ImageMagick，安装方法 brew install imagemagick
// find . -iname "*.png" -exec echo {} \; -exec convert {} {} \;
// or
// find . -iname "*.png" -exec echo {} \; -exec convert {} -quality 95 {} \;

typedef NS_ENUM(NSInteger, GSCSourceType) {
    GSCSourceTypeClass,
    GSCSourceTypeCategory,
};

@interface ViewController ()
/**
 工程路径
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
//工程路径
@property (nonatomic, copy) NSString *projectPath;
//工程名
@property (nonatomic, copy) NSString *projectName;
//原项目名
@property (nonatomic, copy) NSString *projectOldName;
//新项目名
@property (nonatomic, copy) NSString *projectNewName;
//原前缀
@property (nonatomic, copy) NSString *prefixOld;
//修改后前缀
@property (nonatomic, copy) NSString *prefixNew;
//垃圾代码输出目录
@property (nonatomic, copy) NSString *outgarbageCodePath;
@property (nonatomic, copy) NSArray *ignoreDirNames;
@property (nonatomic, copy) NSString *outDirString;
@end

static NSString *const kHClassFileTemplate = @"\
%@\n\
@interface %@ (%@)\n\
%@\n\
@end\n";
static NSString *const kMClassFileTemplate = @"\
#import \"%@+%@.h\"\n\
@implementation %@ (%@)\n\
%@\n\
@end\n";
static NSString *const kSwiftFileTemplate = @"\
%@\n\
extension %@ {\n%@\
}\n";
static NSString *const kSwiftMethodTemplate = @"\
func %@%@(_ %@: String%@) {\n\
print(%@)\n\
}\n";
static const NSString *kRandomAlphabet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
@implementation ViewController
//开始修改文件
- (IBAction)beganToChange:(NSButton *)sender {
    self.projectPath = self.projectPathTF.stringValue;
    self.projectNewName = self.changeProjectNameTF.stringValue;
    self.prefixOld = self.prefixOldTF.stringValue;
    self.prefixNew = self.prefixNewTF.stringValue;
    BOOL isModifyResource = self.modifyResourceBtn.state;
    BOOL isRemoveComments = self.removeCommentsBtn.state;
    //检测项目目录是否存在
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:self.projectPath isDirectory:&isDirectory]) {
        NSLog(@"%@不存在", self.projectPath);
        return;
    }
    if (!isDirectory) {
        NSLog(@"%@不是目录", self.projectPath);
        return;
    }
    //修改项目名
    if (![NSString checkStringEmpty:self.projectOldName] && ![NSString checkStringEmpty:self.projectNewName]) {
        @autoreleasepool {
            NSString *dir = self.projectPath.stringByDeletingLastPathComponent;
            [self modifyProjectNameWithProjectDir:dir oldName:self.projectOldName newName:self.projectNewName];
        }
        NSLog(@"修改工程名完成");
    }
    //修改类前缀
    if (![NSString checkStringEmpty:self.prefixOld] && ![NSString checkStringEmpty:self.prefixNew]) {
        @autoreleasepool {
            // 打开工程文件
            NSError *error = nil;
            NSString *projectFilePath = [self.projectPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.xcodeproj",self.projectName]];
            NSMutableString *projectContent = [NSMutableString stringWithContentsOfFile:projectFilePath encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"打开工程文件 %@ 失败：%@", self.projectPath, error.localizedDescription);
                return;
            }
            [self modifyClassNamePrefixWithProjectContent:projectContent sourceCodeDir:self.projectPath ignoreDirNames:self.ignoreDirNames oldName:self.prefixOld newName:self.prefixNew];
            [projectContent writeToFile:self.projectPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        NSLog(@"修改类名前缀完成");
    }
    //修改资源文件
    if (isModifyResource) {
        @autoreleasepool {
            [self handleXcassetsFilesWithDirectory:self.projectPath];
        }
        NSLog(@"修改 Xcassets 中的图片名称完成");
    }
    //移除注释和空行
    if (isRemoveComments) {
        @autoreleasepool {
            [self deleteCommentsWithDirectory:self.projectPath];
        }
        NSLog(@"删除注释和空行完成");
    }
    //垃圾代码输出
    if (![NSString checkStringEmpty:self.outDirString]) {
        if ([fm fileExistsAtPath:self.outDirString isDirectory:&isDirectory]) {
            if (!isDirectory) {
                NSLog(@"%@ 已存在但不是文件夹，需要传入一个输出文件夹目录",_outDirString);
            }
        } else {
            NSError *error = nil;
            if (![fm createDirectoryAtPath:self.outDirString withIntermediateDirectories:YES attributes:nil error:&error]) {
                NSLog(@"创建输出目录失败，请确认 -spamCodeOut 之后接的是一个“输出文件夹目录”参数，错误信息如下：\n传入的输出文件夹目录：%@\n%@", _outDirString, error.localizedDescription);
            }
        }
        [self recursiveDirectoryWithDirectory:self.projectPath ignoreDirNames:_ignoreDirNames handleMFile:^(NSString *mFilePath) {
            @autoreleasepool {
                [self generateSpamCodeFileWithOutDirectory:self->_outDirString mFilePath:mFilePath type:GSCSourceTypeClass];
                [self generateSpamCodeFileWithOutDirectory:self->_outDirString mFilePath:mFilePath type:GSCSourceTypeCategory];
            }
        } handleSwiftFile:^(NSString *swiftFilePath) {
            @autoreleasepool {
                [self generateSwiftSpamCodeFileWithOutDirectory:self.outDirString swiftFilePath:swiftFilePath];
            }
        }];
        NSLog(@"生成垃圾代码完成");
    }
}
#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.projectPathTF.stringValue = @"/Users/conner/Work/混淆代码";
    
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

#pragma mark - 生成垃圾代码
- (void)recursiveDirectoryWithDirectory:(NSString *)directory ignoreDirNames:(NSArray *)ignoreDirNames handleMFile:(void(^)(NSString *mFilePath))handleMFile handleSwiftFile:(void(^)(NSString *swiftFilePath))handleSwiftFile {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [directory stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            if (![ignoreDirNames containsObject:filePath]) {
                [self recursiveDirectoryWithDirectory:path ignoreDirNames:nil handleMFile:handleMFile handleSwiftFile:handleSwiftFile];
            }
            continue;
        }
        NSString *fileName = filePath.lastPathComponent;
        if ([fileName hasSuffix:@".h"]) {
            fileName = [fileName stringByDeletingPathExtension];
            
            NSString *mFileName = [fileName stringByAppendingPathExtension:@"m"];
            if ([files containsObject:mFileName]) {
                handleMFile([directory stringByAppendingPathComponent:mFileName]);
            }
        } else if ([fileName hasSuffix:@".swift"]) {
            handleSwiftFile([directory stringByAppendingPathComponent:fileName]);
        }
    }
}
- (NSString *)getImportStringWithHFileContent:(NSString *)hFileContent mFileContent:(NSString *)mFileContent {
    NSMutableString *ret = [NSMutableString string];
    
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^ *[@#]import *.+" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:hFileContent options:0 range:NSMakeRange(0, hFileContent.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *importRow = [hFileContent substringWithRange:[obj rangeAtIndex:0]];
        [ret appendString:importRow];
        [ret appendString:@"\n"];
    }];
    
    matches = [expression matchesInString:mFileContent options:0 range:NSMakeRange(0, mFileContent.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *importRow = [mFileContent substringWithRange:[obj rangeAtIndex:0]];
        [ret appendString:importRow];
        [ret appendString:@"\n"];
    }];
    
    return ret;
}
- (void)generateSpamCodeFileWithOutDirectory:(NSString *)outDirectory mFilePath:(NSString *)mFilePath type:(GSCSourceType)type {
    NSString *mFileContent = [NSString stringWithContentsOfFile:mFilePath encoding:NSUTF8StringEncoding error:nil];
    NSString *regexStr;
    switch (type) {
        case GSCSourceTypeClass:
            regexStr = @" *@implementation +(\\w+)[^(]*\\n(?:.|\\n)+?@end";
            break;
        case GSCSourceTypeCategory:
            regexStr = @" *@implementation *(\\w+) *\\((\\w+)\\)(?:.|\\n)+?@end";
            break;
    }
    
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:mFileContent options:0 range:NSMakeRange(0, mFileContent.length)];
    if (matches.count <= 0) return;
    
    NSString *hFilePath = [mFilePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"h"];
    NSString *hFileContent = [NSString stringWithContentsOfFile:hFilePath encoding:NSUTF8StringEncoding error:nil];
    
    // 准备要引入的文件
    NSString *importString = [self getImportStringWithHFileContent:hFileContent mFileContent:mFileContent];
    
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull impResult, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *className = [mFileContent substringWithRange:[impResult rangeAtIndex:1]];
        NSString *categoryName = nil;
        if (impResult.numberOfRanges >= 3) {
            categoryName = [mFileContent substringWithRange:[impResult rangeAtIndex:2]];
        }
        
        if (type == GSCSourceTypeClass) {
            // 如果该类型没有公开，只在 .m 文件中使用，则不处理
            NSString *regexStr = [NSString stringWithFormat:@"\\b%@\\b", className];
            NSRange range = [hFileContent rangeOfString:regexStr options:NSRegularExpressionSearch];
            if (range.location == NSNotFound) {
                return;
            }
        }
        
        // 查找方法
        NSString *implementation = [mFileContent substringWithRange:impResult.range];
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^ *([-+])[^)]+\\)([^;{]+)" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnicodeWordBoundaries error:nil];
        NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:implementation options:0 range:NSMakeRange(0, implementation.length)];
        if (matches.count <= 0) return;
        
        // 生成 h m 垃圾文件内容
        NSMutableString *hFileMethodsString = [NSMutableString string];
        NSMutableString *mFileMethodsString = [NSMutableString string];
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull matche, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *symbol = [implementation substringWithRange:[matche rangeAtIndex:1]];
            NSString *methodName = [[implementation substringWithRange:[matche rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([methodName containsString:@":"]) {
                methodName = [methodName stringByAppendingFormat:@" %@:(NSString *)%@", self.outgarbageCodePath, self.outgarbageCodePath];
            } else {
                methodName = [methodName stringByAppendingFormat:@"%@:(NSString *)%@", self.outgarbageCodePath.capitalizedString, self.outgarbageCodePath];
            }
            
            [hFileMethodsString appendFormat:@"%@ (void)%@;\n", symbol, methodName];
            
            [mFileMethodsString appendFormat:@"%@ (void)%@ {\n", symbol, methodName];
            [mFileMethodsString appendFormat:@"    NSLog(@\"%%@\", %@);\n", self.outgarbageCodePath];
            [mFileMethodsString appendString:@"}\n"];
        }];
        
        NSString *newCategoryName;
        switch (type) {
            case GSCSourceTypeClass:
                newCategoryName = self.outgarbageCodePath.capitalizedString;
                break;
            case GSCSourceTypeCategory:
                newCategoryName = [NSString stringWithFormat:@"%@%@", categoryName, self.outgarbageCodePath.capitalizedString];
                break;
        }
        
        NSString *fileName = [NSString stringWithFormat:@"%@+%@.h", className, newCategoryName];
        NSString *fileContent = [NSString stringWithFormat:kHClassFileTemplate, importString, className, newCategoryName, hFileMethodsString];
        [fileContent writeToFile:[outDirectory stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        fileName = [NSString stringWithFormat:@"%@+%@.m", className, newCategoryName];
        fileContent = [NSString stringWithFormat:kMClassFileTemplate, className, newCategoryName, className, newCategoryName, mFileMethodsString];
        [fileContent writeToFile:[outDirectory stringByAppendingPathComponent:fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }];
}
- (void)generateSwiftSpamCodeFileWithOutDirectory:(NSString *)outDirectory swiftFilePath:(NSString *)swiftFilePath {
    NSString *swiftFileContent = [NSString stringWithContentsOfFile:swiftFilePath encoding:NSUTF8StringEncoding error:nil];
    
    // 查找 class 声明
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@" *(class|struct) +(\\w+)[^{]+" options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:swiftFileContent options:0 range:NSMakeRange(0, swiftFileContent.length)];
    if (matches.count <= 0) return;
    
    NSString *fileImportStrings = [self getSwiftImportString:swiftFileContent];
    __block NSInteger braceEndIndex = 0;
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull classResult, NSUInteger idx, BOOL * _Nonnull stop) {
        // 已经处理到该 range 后面去了，过掉
        NSInteger matchEndIndex = classResult.range.location + classResult.range.length;
        if (matchEndIndex < braceEndIndex) return;
        // 是 class 方法，过掉
        NSString *fullMatchString = [swiftFileContent substringWithRange:classResult.range];
        if ([fullMatchString containsString:@"("]) return;
        
        NSRange braceRange = [self getOutermostCurlyBraceRangeWithString:swiftFileContent beginChar:'{' endChar:'}' beginIndex:matchEndIndex];
        braceEndIndex = braceRange.location + braceRange.length;
        
        // 查找方法
        NSString *classContent = [swiftFileContent substringWithRange:braceRange];
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"func +([^(]+)\\([^{]+" options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
        NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:classContent options:0 range:NSMakeRange(0, classContent.length)];
        if (matches.count <= 0) return;
        
        NSMutableString *methodsString = [NSMutableString string];
        [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull funcResult, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange funcNameRange = [funcResult rangeAtIndex:1];
            NSString *funcName = [classContent substringWithRange:funcNameRange];
            NSRange oldParameterRange = [self getOutermostCurlyBraceRangeWithString:classContent beginChar:'(' endChar:')' beginIndex:funcNameRange.location + funcNameRange.length];
            NSString *oldParameterName = [classContent substringWithRange:oldParameterRange];
            oldParameterName = [oldParameterName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (oldParameterName.length > 0) {
                oldParameterName = [@", " stringByAppendingString:oldParameterName];
            }
            if (![funcName containsString:@"<"] && ![funcName containsString:@">"]) {
                funcName = [NSString stringWithFormat:@"%@%@", funcName, [self randomStringWithLength:5]];
                [methodsString appendFormat:kSwiftMethodTemplate, funcName, self.outgarbageCodePath.capitalizedString, self.outgarbageCodePath, oldParameterName, self.outgarbageCodePath];
            } else {
                NSLog(@"string contains `[` or `]` bla! funcName: %@", funcName);
            }
        }];
        if (methodsString.length <= 0) return;
        
        NSString *className = [swiftFileContent substringWithRange:[classResult rangeAtIndex:2]];
        
        NSString *fileName = [NSString stringWithFormat:@"%@%@Ext.swift", className,self.outgarbageCodePath.capitalizedString];
        NSString *filePath = [outDirectory stringByAppendingPathComponent:fileName];
        NSString *fileContent = @"";
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            fileContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        }
        fileContent = [fileContent stringByAppendingFormat:kSwiftFileTemplate, fileImportStrings, className, methodsString];
        [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }];
}
#pragma mark - 处理 Xcassets 中的图片文件
- (void)handleXcassetsFilesWithDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:&error];
    if (error) {
        NSLog(@"处理图片读取文件失败");
        return;
    }
    BOOL isDirectory;
    for (NSString *fileName in files) {
        NSString *filePath = [directory stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:filePath isDirectory:&isDirectory] && isDirectory) {
            [self handleXcassetsFilesWithDirectory:filePath];
            continue;
        }
        if (![fileName isEqualToString:@"Contents.json"]) continue;
        NSString *contentsDirectoryName = filePath.stringByDeletingLastPathComponent.lastPathComponent;
        if (![contentsDirectoryName hasSuffix:@".imageset"]) continue;
        
        NSString *fileContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        if (!fileContent) continue;
        
        NSMutableArray<NSString *> *processedImageFileNameArray = @[].mutableCopy;
        static NSString * const regexStr = @"\"filename\" *: *\"(.*)?\"";
        NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
        NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
        while (matches.count > 0) {
            NSInteger i = 0;
            NSString *imageFileName = nil;
            do {
                if (i >= matches.count) {
                    i = -1;
                    break;
                }
                imageFileName = [fileContent substringWithRange:[matches[i] rangeAtIndex:1]];
                i++;
            } while ([processedImageFileNameArray containsObject:imageFileName]);
            if (i < 0) break;
            
            NSString *imageFilePath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:imageFileName];
            if ([fm fileExistsAtPath:imageFilePath]) {
                NSString *newImageFileName = [[self randomStringWithLength:10] stringByAppendingPathExtension:imageFileName.pathExtension];
                NSString *newImageFilePath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newImageFileName];
                while ([fm fileExistsAtPath:newImageFileName]) {
                    newImageFileName = [[self randomStringWithLength:10] stringByAppendingPathExtension:imageFileName.pathExtension];
                    newImageFilePath = [filePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:newImageFileName];
                }
                
                [self renameFileWithOldPath:imageFilePath newPath:newImageFilePath];
                fileContent = [fileContent stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\"%@\"", imageFileName]
                                                                     withString:[NSString stringWithFormat:@"\"%@\"", newImageFileName]];
                [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
                
                [processedImageFileNameArray addObject:newImageFileName];
            } else {
                [processedImageFileNameArray addObject:imageFileName];
            }
            
            matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
        }
    }
}
#pragma mark - 删除注释
- (void)deleteCommentsWithDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:directory error:&error];
    if (error) {
        NSLog(@"删除注释读取文件失败");
        return;
    }
    BOOL isDirectory;
    for (NSString *fileName in files) {
        NSString *filePath = [directory stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:filePath isDirectory:&isDirectory] && isDirectory) {
            [self deleteCommentsWithDirectory:filePath];
            continue;
        }
        if (![fileName hasSuffix:@".h"] && ![fileName hasSuffix:@".m"] && ![fileName hasSuffix:@".swift"]) continue;
        NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        [self regularReplacementWithOriginalString:fileContent regularExpression:@"([^:/])//.*" newString:@"\\1"];
        [self regularReplacementWithOriginalString:fileContent regularExpression:@"^//.*" newString:@""];
        [self regularReplacementWithOriginalString:fileContent regularExpression:@"/\\*{1,2}[\\s\\S]*?\\*/" newString:@""];
        [self regularReplacementWithOriginalString:fileContent regularExpression:@"^\\s*\\n" newString:@""];
        [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
#pragma mark - 修改工程名
- (void)resetEntitlementsFileNameWithProjFilePath:(NSString *)projectFilePath oldName:(NSString *)oldName newName:(NSString *)newName {
    NSString *rootPath = projectFilePath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:projectFilePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = @"CODE_SIGN_ENTITLEMENTS = \"?([^\";]+)";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *entitlementsPath = [fileContent substringWithRange:[obj rangeAtIndex:1]];
        NSString *entitlementsName = entitlementsPath.lastPathComponent.stringByDeletingPathExtension;
        if (![entitlementsName isEqualToString:oldName]) return;
        entitlementsPath = [rootPath stringByAppendingPathComponent:entitlementsPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:entitlementsPath]) return;
        NSString *newPath = [entitlementsPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:[newName stringByAppendingPathExtension:@"entitlements"]];
        [self renameFileWithOldPath:entitlementsPath newPath:newPath];
    }];
}
- (void)resetBridgingHeaderFileName:(NSString *)projectFilePath oldName:(NSString *)oldName newName:(NSString *)newName {
    NSString *rootPath = projectFilePath.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:projectFilePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = @"SWIFT_OBJC_BRIDGING_HEADER = \"?([^\";]+)";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *entitlementsPath = [fileContent substringWithRange:[obj rangeAtIndex:1]];
        NSString *entitlementsName = entitlementsPath.lastPathComponent.stringByDeletingPathExtension;
        if (![entitlementsName isEqualToString:oldName]) return;
        entitlementsPath = [rootPath stringByAppendingPathComponent:entitlementsPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:entitlementsPath]) return;
        NSString *newPath = [entitlementsPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:[newName stringByAppendingPathExtension:@"h"]];
        [self renameFileWithOldPath:entitlementsPath newPath:newPath];
    }];
}
- (void)replacePodfileContentWithFilePath:(NSString *)filePath oldString:(NSString *)oldString newString:(NSString *)newString {
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = [NSString stringWithFormat:@"target +'%@", oldString];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [fileContent replaceCharactersInRange:obj.range withString:[NSString stringWithFormat:@"target '%@", newString]];
    }];
    
    regularExpression = [NSString stringWithFormat:@"project +'%@.", oldString];
    expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [fileContent replaceCharactersInRange:obj.range withString:[NSString stringWithFormat:@"project '%@.", newString]];
    }];
    
    [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
- (void)replaceProjectFileContentWithFilePath:(NSString *)filePath oldString:(NSString *)oldString newString:(NSString *)newString {
    NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularExpression = [NSString stringWithFormat:@"\\b%@\\b", oldString];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:0 error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [fileContent replaceCharactersInRange:obj.range withString:newString];
    }];
    
    [fileContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
- (void)modifyProjectNameWithProjectDir:(NSString *)projectDir oldName:(NSString *)oldName newName:(NSString *)newName {
    NSString *sourceCodeDirPath = [projectDir stringByAppendingPathComponent:oldName];
    NSString *xcodeprojFilePath = [sourceCodeDirPath stringByAppendingPathExtension:@"xcodeproj"];
    NSString *xcworkspaceFilePath = [sourceCodeDirPath stringByAppendingPathExtension:@"xcworkspace"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory;
    
    // old-Swift.h > new-Swift.h
    [self modifyFilesClassNameWithSourceCodeDir:projectDir oldClassName:[oldName stringByAppendingString:@"-Swift.h"] newClassName:[newName stringByAppendingString:@"-Swift.h"]];
    // 改 Podfile 中的工程名
    NSString *podfilePath = [projectDir stringByAppendingPathComponent:@"Podfile"];
    if ([fm fileExistsAtPath:podfilePath isDirectory:&isDirectory] && !isDirectory) {
        [self replacePodfileContentWithFilePath:podfilePath oldString:oldName newString:newName];
    }
    
    // 改工程文件内容
    if ([fm fileExistsAtPath:xcodeprojFilePath isDirectory:&isDirectory] && isDirectory) {
        // 替换 project.pbxproj 文件内容
        NSString *projectPbxprojFilePath = [xcodeprojFilePath stringByAppendingPathComponent:@"project.pbxproj"];
        if ([fm fileExistsAtPath:projectPbxprojFilePath]) {
            [self resetBridgingHeaderFileName:projectPbxprojFilePath oldName:[oldName stringByAppendingString:@"-Bridging-Header"] newName: [newName stringByAppendingString:@"-Bridging-Header"]];
            [self resetEntitlementsFileNameWithProjFilePath:projectPbxprojFilePath oldName:oldName newName:newName];
            [self replaceProjectFileContentWithFilePath:projectPbxprojFilePath oldString:oldName newString:newName];
        }
        // 替换 project.xcworkspace/contents.xcworkspacedata 文件内容
        NSString *contentsXcworkspacedataFilePath = [xcodeprojFilePath stringByAppendingPathComponent:@"project.xcworkspace/contents.xcworkspacedata"];
        if ([fm fileExistsAtPath:contentsXcworkspacedataFilePath]) {
            [self replaceProjectFileContentWithFilePath:contentsXcworkspacedataFilePath oldString:oldName newString:newName];
        }
        // xcuserdata 本地用户文件
        NSString *xcuserdataFilePath = [xcodeprojFilePath stringByAppendingPathComponent:@"xcuserdata"];
        if ([fm fileExistsAtPath:xcuserdataFilePath]) {
            [fm removeItemAtPath:xcuserdataFilePath error:nil];
        }
        // 改名工程文件
        [self renameFileWithOldPath:xcodeprojFilePath newPath:[[projectDir stringByAppendingPathComponent:newName] stringByAppendingPathExtension:@"xcodeproj"]];
    }
    
    // 改工程组文件内容
    if ([fm fileExistsAtPath:xcworkspaceFilePath isDirectory:&isDirectory] && isDirectory) {
        // 替换 contents.xcworkspacedata 文件内容
        NSString *contentsXcworkspacedataFilePath = [xcworkspaceFilePath stringByAppendingPathComponent:@"contents.xcworkspacedata"];
        if ([fm fileExistsAtPath:contentsXcworkspacedataFilePath]) {
            [self replaceProjectFileContentWithFilePath:contentsXcworkspacedataFilePath oldString:oldName newString:newName];
        }
        // xcuserdata 本地用户文件
        NSString *xcuserdataFilePath = [xcworkspaceFilePath stringByAppendingPathComponent:@"xcuserdata"];
        if ([fm fileExistsAtPath:xcuserdataFilePath]) {
            [fm removeItemAtPath:xcuserdataFilePath error:nil];
        }
        // 改名工程文件
        [self renameFileWithOldPath:xcworkspaceFilePath newPath:[[projectDir stringByAppendingPathComponent:newName] stringByAppendingPathExtension:@"xcworkspace"]];
    }
    
    // 改源代码文件夹名称
    if ([fm fileExistsAtPath:sourceCodeDirPath isDirectory:&isDirectory] && isDirectory) {
        [self renameFileWithOldPath:sourceCodeDirPath newPath:[projectDir stringByAppendingPathComponent:newName]];
    }
}

#pragma mark - 修改类名前缀
- (void)modifyFilesClassNameWithSourceCodeDir:(NSString *)sourceCodeDir oldClassName:(NSString *)oldClassName newClassName:(NSString *)newClassName {
    // 文件内容 Const > DDConst (h,m,swift,xib,storyboard)
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:sourceCodeDir error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [sourceCodeDir stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            [self modifyFilesClassNameWithSourceCodeDir:path oldClassName:oldClassName newClassName:newClassName];
            continue;
        }
        
        NSString *fileName = filePath.lastPathComponent;
        if ([fileName hasSuffix:@".h"] || [fileName hasSuffix:@".m"] || [fileName hasSuffix:@".pch"] || [fileName hasSuffix:@".swift"] || [fileName hasSuffix:@".xib"] || [fileName hasSuffix:@".storyboard"]) {
            
            NSError *error = nil;
            NSMutableString *fileContent = [NSMutableString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"打开文件 %@ 失败：%@", path, error.localizedDescription);
                abort();
            }
            
            NSString *regularExpression = [NSString stringWithFormat:@"\\b%@\\b", oldClassName];
            BOOL isChanged = [self regularReplacementWithOriginalString:fileContent regularExpression:regularExpression newString:newClassName];
            if (!isChanged) continue;
            error = nil;
            [fileContent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"保存文件 %@ 失败：%@", path, error.localizedDescription);
                abort();
            }
        }
    }
}
- (void)modifyClassNamePrefixWithProjectContent:(NSMutableString *)projectContent sourceCodeDir:(NSString *)sourceCodeDir ignoreDirNames:(NSArray *)ignoreDirNames oldName:(NSString *)oldName newName:(NSString *)newName {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 遍历源代码文件 h 与 m 配对，swift
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:sourceCodeDir error:nil];
    BOOL isDirectory;
    for (NSString *filePath in files) {
        NSString *path = [sourceCodeDir stringByAppendingPathComponent:filePath];
        if ([fm fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
            if (![ignoreDirNames containsObject:filePath]) {
                [self modifyClassNamePrefixWithProjectContent:projectContent sourceCodeDir:path ignoreDirNames:ignoreDirNames oldName:oldName newName:newName];
            }
            continue;
        }
        
        NSString *fileName = filePath.lastPathComponent.stringByDeletingPathExtension;
        NSString *fileExtension = filePath.pathExtension;
        NSString *newClassName;
        if ([fileName hasPrefix:oldName]) {
            newClassName = [newName stringByAppendingString:[fileName substringFromIndex:oldName.length]];
        } else {
            newClassName = [newName stringByAppendingString:fileName];
        }
        
        // 文件名 Const.ext > DDConst.ext
        if ([fileExtension isEqualToString:@"h"]) {
            NSString *mFileName = [fileName stringByAppendingPathExtension:@"m"];
            if ([files containsObject:mFileName]) {
                NSString *oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"h"];
                NSString *newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"h"];
        
                [self renameFileWithOldPath:oldFilePath newPath:newFilePath];
                oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"m"];
                newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"m"];
                [self renameFileWithOldPath:oldFilePath newPath:newFilePath];
                oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"xib"];
                if ([fm fileExistsAtPath:oldFilePath]) {
                    newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"xib"];
                    [self renameFileWithOldPath:oldFilePath newPath:newFilePath];
                }
                
                @autoreleasepool {
                    [self modifyFilesClassNameWithSourceCodeDir:self.projectPath oldClassName:fileName newClassName:newClassName];
                }
            } else {
                continue;
            }
        } else if ([fileExtension isEqualToString:@"swift"]) {
            NSString *oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"swift"];
            NSString *newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"swift"];
            [self renameFileWithOldPath:oldFilePath newPath:newFilePath];
            oldFilePath = [[sourceCodeDir stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"xib"];
            if ([fm fileExistsAtPath:oldFilePath]) {
                newFilePath = [[sourceCodeDir stringByAppendingPathComponent:newClassName] stringByAppendingPathExtension:@"xib"];
                [self renameFileWithOldPath:oldFilePath newPath:newFilePath];
            }
            
            @autoreleasepool {
                [self modifyFilesClassNameWithSourceCodeDir:self.projectPath oldClassName:fileName.stringByDeletingPathExtension newClassName:newClassName];
            }
        } else {
            continue;
        }
        
        // 修改工程文件中的文件名
        NSString *regularExpression = [NSString stringWithFormat:@"\\b%@\\b", fileName];
        [self regularReplacementWithOriginalString:projectContent regularExpression:regularExpression newString:newClassName];
    }
}

#pragma mark - 公共方法
- (NSString *)randomStringWithLength:(NSInteger )length {
    NSMutableString *ret = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [ret appendFormat:@"%C", [kRandomAlphabet characterAtIndex:arc4random_uniform((uint32_t)[kRandomAlphabet length])]];
    }
    return ret;
}
- (NSRange)getOutermostCurlyBraceRangeWithString:(NSString *)string beginChar:(unichar)beginChar endChar:(unichar)endChar beginIndex:(NSInteger)beginIndex {
    NSInteger braceCount = -1;
    NSInteger endIndex = string.length - 1;
    for (NSInteger i = beginIndex; i <= endIndex; i++) {
        unichar c = [string characterAtIndex:i];
        if (c == beginChar) {
            braceCount = ((braceCount == -1) ? 0 : braceCount) + 1;
        } else if (c == endChar) {
            braceCount--;
        }
        if (braceCount == 0) {
            endIndex = i;
            break;
        }
    }
    return NSMakeRange(beginIndex + 1, endIndex - beginIndex - 1);
}
- (NSString *)getSwiftImportString:(NSString *)string {
    NSMutableString *ret = [NSMutableString string];
    
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^ *import *.+" options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnicodeWordBoundaries error:nil];
    
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:string options:0 range:NSMakeRange(0, string.length)];
    [matches enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *importRow = [string substringWithRange:obj.range];
        [ret appendString:importRow];
        [ret appendString:@"\n"];
    }];
    return ret;
}
- (BOOL)regularReplacementWithOriginalString:(NSMutableString *)originalString regularExpression:(NSString *)regularExpression newString:(NSString *)newString {
    __block BOOL isChanged = NO;
    BOOL isGroupNo1 = [newString isEqualToString:@"\\1"];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:regularExpression options:NSRegularExpressionAnchorsMatchLines|NSRegularExpressionUseUnixLineSeparators error:nil];
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:originalString options:0 range:NSMakeRange(0, originalString.length)];
    [matches enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!isChanged) {
            isChanged = YES;
        }
        if (isGroupNo1) {
            NSString *withString = [originalString substringWithRange:[obj rangeAtIndex:1]];
            [originalString replaceCharactersInRange:obj.range withString:withString];
        } else {
            [originalString replaceCharactersInRange:obj.range withString:newString];
        }
    }];
    return isChanged;
}

- (void)renameFileWithOldPath:(NSString *)oldPath newPath:(NSString *)newPath {
    NSError *error;
    [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error];
    if (error) {
        NSLog(@"修改文件名称失败。\n  oldPath=%@\n  newPath=%@\n  ERROR:%@", oldPath, newPath, error.localizedDescription);
        abort();
    }
}


@end
