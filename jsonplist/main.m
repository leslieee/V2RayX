//
//  main.m
//  jsonplist
//
//  Copyright © 2017 Project V2Ray. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *script = [NSString stringWithFormat:@"do shell script \"spctl --master-disable\" with administrator privileges"];
        NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
        NSDictionary *error;
        printf("\n\n正在尝试关闭系统安全策略..\n");
        printf("请输入用户密码\n");
        if ([appleScript executeAndReturnError:&error]) {
            printf("关闭成功!\n请重新打开V2Ray.app\n\n");
            return YES;
        } else {
            printf("关闭失败!\n请按用户中心-客户端下载-苹果电脑 教程提示手动操作关闭系统安全策略\n\n");
            return NO;
        }
        
    }
    return 0;
}
