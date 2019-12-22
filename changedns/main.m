//
//  main.m
//  changedns
//
//  Created by leslie on 12/10/19.
//  Copyright © 2019 Project V2Ray. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <SystemConfiguration/SCPreferences.h>
#include <SystemConfiguration/SCDynamicStore.h>

#define NOTNULL(x) ((![x isKindOfClass:[NSNull class]])&&x)
#define SWNOTEmptyArr(X) (NOTNULL(X)&&[X isKindOfClass:[NSArray class]]&&[X count])
#define SWNOTEmptyDictionary(X) (NOTNULL(X)&&[X isKindOfClass:[NSDictionary class]]&&[[X allKeys]count])
#define SWNOTEmptyStr(X) (NOTNULL(X)&&[X isKindOfClass:[NSString class]]&&((NSString *)X).length)

int main (int argc, const char * argv[])
{
    @autoreleasepool {
        if (argc < 2 || argc >3) {
            printf("off | on [dns ip]\n");
            return 1;
        }
        static AuthorizationRef authRef;
        static AuthorizationFlags authFlags;
        authFlags = kAuthorizationFlagDefaults
        | kAuthorizationFlagExtendRights
        | kAuthorizationFlagInteractionAllowed
        | kAuthorizationFlagPreAuthorize;
        OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
        if (authErr != noErr) {
            authRef = nil;
        } else {
            if (authRef == NULL) {
                NSLog(@"No authorization has been granted to modify network configuration");
                return 1;
            }
            NSString *mode = [NSString stringWithUTF8String:argv[1]];
            NSString *ip;
            if ([mode isEqualToString:@"on"]) {
                if (argc == 2) {
                    ip = @"8.8.8.8";
                } else if (argc == 3) {
                    ip = [NSString stringWithUTF8String:argv[2]];
                }
            }
            //get current values
            SCDynamicStoreRef dynRef=SCDynamicStoreCreate(kCFAllocatorSystemDefault, CFSTR("iked"), NULL, NULL);
            CFDictionaryRef ipv4key = SCDynamicStoreCopyValue(dynRef,CFSTR("State:/Network/Global/IPv4"));
            CFStringRef primaryserviceid = CFDictionaryGetValue(ipv4key,CFSTR("PrimaryService"));
            CFStringRef primaryservicepath = CFStringCreateWithFormat(NULL,NULL,CFSTR("State:/Network/Service/%@/DNS"),primaryserviceid);
            CFDictionaryRef dnskey = SCDynamicStoreCopyValue(dynRef,primaryservicepath);
            
            if ([mode isEqualToString:@"on"]) {
                
                // 先保存当前的dns
                CFPropertyListRef ref = SCDynamicStoreCopyValue(dynRef, primaryservicepath);
                NSDictionary *dict = (__bridge NSDictionary *)ref;
                // 判断系统dns是否已经是ip的值
                if (SWNOTEmptyDictionary(dict)) {
                    NSArray *servers = dict[@"ServerAddresses"];
                    if (SWNOTEmptyArr(servers)) {
                        if ([servers[0] isEqualToString:ip]) {
                            printf("已经设置过该dns了\n");
                            return 1;
                        }
                    }
                }
                
                NSString *currentpath = [[[NSFileManager alloc] init] currentDirectoryPath];
                currentpath = [NSString stringWithFormat:@"/Library/Application Support/V2RayX/dnsbackfile"];
                if ([dict writeToFile:currentpath atomically:YES]) {
                    printf("原dns配置备份成功\n");
                } else {
                    printf("原dns配置备份失败\n");
                }
                //create new values
                CFMutableDictionaryRef newdnskey = CFDictionaryCreateMutableCopy(NULL,0,dnskey);
                if (SWNOTEmptyStr(dict[@"DomainName"])) {
                    CFStringRef domain = (__bridge CFStringRef)dict[@"DomainName"];
                    CFDictionarySetValue(newdnskey,CFSTR("DomainName"),domain);
                }
                
                CFMutableArrayRef dnsserveraddresses = CFArrayCreateMutable(NULL,0,NULL);
                CFStringRef str = (__bridge CFStringRef)ip;
                CFArrayAppendValue(dnsserveraddresses, str);
                CFDictionarySetValue(newdnskey, CFSTR("ServerAddresses"), dnsserveraddresses);
                
                //set values
                bool success = SCDynamicStoreSetValue(dynRef, primaryservicepath, newdnskey);
                if (success) {
                    printf("新dns写入成功\n");
                } else {
                    printf("新dns写入失败\n");
                }
            } else if ([mode isEqualToString:@"off"]) {
                NSString *currentpath = [[[NSFileManager alloc] init] currentDirectoryPath];
                currentpath = [NSString stringWithFormat:@"/Library/Application Support/V2RayX/dnsbackfile"];
                NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:currentpath];
                if (SWNOTEmptyDictionary(dict)) {
                    //create new values
                    CFMutableDictionaryRef newdnskey = CFDictionaryCreateMutableCopy(NULL,0,dnskey);
                    if (SWNOTEmptyStr(dict[@"DomainName"])) {
                        CFStringRef domain = (__bridge CFStringRef)dict[@"DomainName"];
                        CFDictionarySetValue(newdnskey,CFSTR("DomainName"),domain);
                    }
                    
                    CFMutableArrayRef dnsserveraddresses = CFArrayCreateMutable(NULL,0,NULL);
                    for (NSString *str in dict[@"ServerAddresses"]) {
                        CFStringRef cfstr = (__bridge CFStringRef)str;
                        CFArrayAppendValue(dnsserveraddresses, cfstr);
                    }
                    
                    CFDictionarySetValue(newdnskey, CFSTR("ServerAddresses"), dnsserveraddresses);
                    
                    //set values
                    bool success = SCDynamicStoreSetValue(dynRef, primaryservicepath, newdnskey);
                    if (success) {
                        printf("原dns恢复成功\n");
                    } else {
                        printf("原dns恢复失败\n");
                    }
                } else {
                    printf("原dns配置丢了..请重启网络\n");
                }
            }
        }
    }
}
