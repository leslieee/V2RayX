//
//  main.m
//  v2rayx_sysconf
//
//  Copyright © 2016年 Cenmrev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#define VERSION @"v2rayx_sysconf 1.0.0"

#define INFO "v2rayx_sysconf\n the helper tool for V2RayX, modified from clowwindy's shadowsocks_sysconf.\nusage: v2rayx_sysconf [options]\noff\t turn off proxy\nauto\t auto proxy change\nglobal port \t global proxy at the specified port number\n"

int main(int argc, const char * argv[])
{
    if (argc < 2 || argc >3) {
        printf(INFO);
        return 1;
    }
    @autoreleasepool {
        NSString *mode = [NSString stringWithUTF8String:argv[1]];
        
        NSSet *support_args = [NSSet setWithObjects:@"off", @"on", @"global", @"-v", nil];
        if (![support_args containsObject:mode]) {
            printf(INFO);
            return 1;
        }
        
        if ([mode isEqualToString:@"-v"]) {
            printf("%s", [VERSION UTF8String]);
            return 0;
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
            
            SCPreferencesRef prefRef = SCPreferencesCreateWithAuthorization(nil, CFSTR("V2RayX"), nil, authRef);
            
            NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
            
            NSMutableDictionary *proxies = [[NSMutableDictionary alloc] init];
            
            // 遍历系统中的网络设备列表，设置 AirPort 和 Ethernet 的代理
            for (NSString *key in [sets allKeys]) {
                NSMutableDictionary *dict = [sets objectForKey:key];
                NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
                //        NSLog(@"%@", hardware);
                if ([hardware isEqualToString:@"AirPort"] || [hardware isEqualToString:@"Wi-Fi"] || [hardware isEqualToString:@"Ethernet"]) {
                    
                    if ([mode isEqualToString:@"on"]) {
                        [proxies setObject:@[@"8.8.8.8"] forKey:(NSString*) kSCPropNetDNSServerAddresses];
                    } else if ([mode isEqualToString:@"off"]) {
                        [proxies setObject:@[] forKey:(NSString*) kSCPropNetDNSServerAddresses];

                    }
                    SCPreferencesPathSetValue(prefRef, (__bridge CFStringRef)[NSString stringWithFormat:@"/%@/%@/%@", kSCPrefNetworkServices, key, kSCEntNetDNS], (__bridge CFDictionaryRef)proxies);
                }
            }
            
            SCPreferencesCommitChanges(prefRef);
            SCPreferencesApplyChanges(prefRef);
            SCPreferencesSynchronize(prefRef);
            
        }
        
        printf("dns set to %s\n", [mode UTF8String]);
    }
    
    return 0;
}
