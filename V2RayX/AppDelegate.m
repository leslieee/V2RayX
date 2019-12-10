//
//  AppDelegate.m
//  V2RayX
//
//  Copyright © 2016年 Cenmrev. All rights reserved.
//

#import "AppDelegate.h"
#import "ConfigWindowController.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "ServerProfile.h"
#import "LoginWindowController.h"
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <arpa/inet.h>
#import "Reachability.h"

@interface AppDelegate () {
    ConfigWindowController *configWindowController;
	LoginWindowController *loginWindowController;

    dispatch_queue_t taskQueue;
    FSEventStreamRef fsEventStream;
}

@end

@implementation AppDelegate

static AppDelegate *appDelegate;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // create a serial queue used for NSTask operations
	
	NSArray *path = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *folder = [path objectAtIndex:0];
	NSLog(@"Your NSUserDefaults are stored in this folder: %@/Preferences", folder);
	
    taskQueue = dispatch_queue_create("cenmrev.v2rayx.nstask", DISPATCH_QUEUE_SERIAL);
    
    if (![self installHelper]) {
        [[NSApplication sharedApplication] terminate:nil];// installation failed or stopped by user,
    };
    
    _statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusBarItem setMenu:_statusBarMenu];
    [_statusBarItem setHighlightMode:YES];
    
    plistPath = [NSString stringWithFormat:@"%@/Library/Application Support/V2RayX/cenmrev.v2rayx.v2ray-core.plist",NSHomeDirectory()];
    plistTun2socksPath = [NSString stringWithFormat:@"%@/Library/Application Support/V2RayX/cenmrev.v2rayx.tun2socks.plist",NSHomeDirectory()];
    pacPath = [NSString stringWithFormat:@"%@/Library/Application Support/V2RayX/pac/pac.js",NSHomeDirectory()];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString *pacDir = [NSString stringWithFormat:@"%@/Library/Application Support/V2RayX/pac", NSHomeDirectory()];
    //create application support directory and pac directory
    if (![fileManager fileExistsAtPath:pacDir]) {
        [fileManager createDirectoryAtPath:pacDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // Create Log Dir
    do {
        NSString* logDirName = [NSString stringWithFormat:@"cenmrev.v2rayx.log.%@",
                                [[NSUUID UUID] UUIDString]];
        logDirPath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), logDirName];
    } while ([fileManager fileExistsAtPath:logDirPath]);
    [fileManager createDirectoryAtPath:logDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    [fileManager createFileAtPath:[NSString stringWithFormat:@"%@/access.log", logDirPath] contents:nil attributes:nil];
    [fileManager createFileAtPath:[NSString stringWithFormat:@"%@/error.log", logDirPath] contents:nil attributes:nil];
    
    NSNumber* setingVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"setingVersion"];
    if(setingVersion == nil || [setingVersion integerValue] != kV2RayXSettingVersion) {
        // NSAlert *noServerAlert = [[NSAlert alloc] init];
        // [noServerAlert setMessageText:@"If you are running V2RayX for the first time, ignore this message. \nSorry, unknown settings!\nAll V2RayX settings will be reset."];
        // [noServerAlert runModal];
		// 先把旧版配置清理一遍
		runCommandLine(@"/usr/bin/defaults", @[@"delete", @"cenmrev.V2RayX"]);
        [self writeDefaultSettings]; //explicitly write default settings to user defaults file
    }
    profiles = [[NSMutableArray alloc] init];
    [self readDefaults];
    if (proxyMode == trans) {
        [self configurationDidChangeTransMode];
    } else {
        [self configurationDidChange];
    }
    
	// 弹出登录框
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"is_login"]) {
		loginWindowController =[[LoginWindowController alloc] initWithWindowNibName:@"LoginWindowController"];
		loginWindowController.appDelegate = self;
		[loginWindowController showWindow:self];
		[NSApp activateIgnoringOtherApps:YES];
		[loginWindowController.window makeKeyAndOrderFront:nil];
	}
    
    appDelegate = self;
    
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:reachability];
    [reachability startNotifier];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *reach = [notification object];
    NetworkStatus ns = [reach currentReachabilityStatus];
        if (ns==NotReachable) {
            NSLog(@"此时网络不可达");
        } else {
            NSLog(@"此时网络是联通的");
            // 检测网关变了没有
            if (proxyState && proxyMode == trans && SWNOTEmptyStr(_gatewayIP) && SWNOTEmptyStr(_serverIPStr)) {
                NSString *output = [self runCommandLineWithReturn:kV2RayXRoute with:@[@"-n",@"get",@"default"]];
                NSArray *array = [output componentsSeparatedByString:@"\n"];
                NSString *errorStr;
                if (![output containsString:@"route: writing to routing socket: not in table"]) {
                    if (SWNOTEmptyArr(array)) {
                        for (NSString *str in array) {
                            if ([str containsString:@"gateway"]) {
                                NSString *tmpstr = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
                                NSArray *tmpArray = [tmpstr componentsSeparatedByString:@":"];
                                if (SWNOTEmptyArr(tmpArray) && tmpArray.count == 2) {
                                    if ([self isIPAddress:tmpArray[1]]) {
                                        if ([tmpArray[1] isEqualToString:@"240.0.0.1"]) {
                                            // 有可能触发两次通知 然后走到这里
                                            // errorStr = @"当前已设置过网关(说明已在此模式), 如果网络不正常 请在菜单中选择重置网络设置后再试";
                                            break;
                                        } else {
                                            _gatewayIP = tmpArray[1];
                                            break;
                                        }
                                    } else {
                                        errorStr = @"网关地址获取失败, 请在菜单中选择重置网络设置后再试";
                                        break;
                                    }
                                } else {
                                    errorStr = @"网关地址获取失败, 请在菜单中选择重置网络设置后再试";
                                    break;
                                }
                            }
                        }
                    } else {
                        errorStr = @"route命令没有返回信息, 请在菜单中选择重置网络设置后再试";
                    }
                } else {
                    errorStr = @"默认网关丢了.. 请把wifi关掉然后再开启后再试(有线的话拔掉网线在插入), 或者在菜单-重置网络中手动输入(如果你知道的话, 一般为路由器的管理页面地址), 如果不这样做你会一直在断网中..";
                }
                if (SWNOTEmptyStr(errorStr) || !SWNOTEmptyStr(_gatewayIP)) {
                    NSAlert *installAlert = [[NSAlert alloc] init];
                    [installAlert addButtonWithTitle:@"知道了"];
                    [installAlert setMessageText:errorStr];
                    [installAlert runModal];
                }
                [self unsetSystemRoute];
                [self setSystemRoute];
            }
        }
    }

- (void) writeDefaultSettings {
	ServerProfile *defaultProfile = [[ServerProfile alloc] init];
	defaultProfile.network = 2;
    NSDictionary *defaultSettings =
    @{
      @"setingVersion": [NSNumber numberWithInteger:kV2RayXSettingVersion],
      @"logLevel": @"none",
      @"proxyState": [NSNumber numberWithBool:NO],
      @"proxyMode": @(manual),
      @"selectedServerIndex": [NSNumber numberWithInteger:0],
      @"localPort": [NSNumber numberWithInteger:1081],
      @"httpPort": [NSNumber numberWithInteger:8001],
      @"udpSupport": [NSNumber numberWithBool:YES],
      @"shareOverLan": [NSNumber numberWithBool:NO],
      @"dnsString": @"localhost",
      @"profiles":@[
              [defaultProfile outboundProfile]
              ],
      };
    for (NSString* key in [defaultSettings allKeys]) {
        [[NSUserDefaults standardUserDefaults] setObject:defaultSettings[key] forKey:key];
    }
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    //unload v2ray
    runCommandLine(@"/bin/launchctl", @[@"unload", plistPath]);
    if (proxyMode == trans) {
        runCommandLine(@"/bin/launchctl", @[@"unload", plistTun2socksPath]);
        [self unsetSystemRoute];
    }
    NSLog(@"V2RayX quiting, V2Ray core unloaded.");
    //remove log file
    [[NSFileManager defaultManager] removeItemAtPath:logDirPath error:nil];
    //save settings
    //[[NSUserDefaults standardUserDefaults] setObject:dnsString forKey:@"dnsString"];
    NSMutableArray* profilesArray = [[NSMutableArray alloc] init];
    for (ServerProfile* p in profiles) {
        [profilesArray addObject:[p outboundProfile]];
    }
    NSDictionary *settings =
    @{
      @"logLevel": logLevel,
      @"proxyState": @(proxyState),
      @"proxyMode": @(proxyMode),
      @"selectedServerIndex": @(selectedServerIndex),
      @"localPort": @(localPort),
      @"httpPort": @(httpPort),
      @"udpSupport": @(udpSupport),
      @"shareOverLan": @(shareOverLan),
      @"dnsString": dnsString,
      @"profiles":profilesArray,
      };
    for (NSString* key in [settings allKeys]) {
        [[NSUserDefaults standardUserDefaults] setObject:settings[key] forKey:key];
    }
	[[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"Settings saved.");
    //turn off proxy
    if (proxyState && proxyMode != 3) {
        proxyState = NO;
        [self updateSystemProxy];//close system proxy
    }
}

- (IBAction)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.v2ray.com"]];
}

- (IBAction)enableProxy:(id)sender {
    proxyState = !proxyState;
    if (proxyMode == trans) {
        [self configurationDidChangeTransMode];
    } else {
        [self configurationDidChange];
    }
}

- (IBAction)chooseV2rayRules:(id)sender {
    if (proxyMode == trans) {
        runCommandLine(@"/bin/launchctl", @[@"unload", plistTun2socksPath]);
        [self unsetSystemRoute];
    }
    proxyMode = rules;
    [self configurationDidChange];
}

- (IBAction)chooseManualMode:(id)sender {
    if (proxyMode == trans) {
        runCommandLine(@"/bin/launchctl", @[@"unload", plistTun2socksPath]);
        [self unsetSystemRoute];
    }
    proxyMode = manual;
    [self configurationDidChange];
}

- (IBAction)chooseTransMode:(id)sender {
    [self configurationDidChangeTransMode];
}

- (IBAction)showConfigWindow:(id)sender {
    if (configWindowController) {
        [configWindowController close];
    }
    configWindowController =[[ConfigWindowController alloc] initWithWindowNibName:@"ConfigWindow"];
    configWindowController.appDelegate = self;
    [configWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
    [configWindowController.window makeKeyAndOrderFront:nil];
}

- (IBAction)viewLog:(id)sender {
    [[NSWorkspace sharedWorkspace] openFile:logDirPath];
}

- (IBAction)loginToSpeedss:(id)sender{
	loginWindowController =[[LoginWindowController alloc] initWithWindowNibName:@"LoginWindowController"];
	loginWindowController.appDelegate = self;
	[loginWindowController showWindow:self];
	[NSApp activateIgnoringOtherApps:YES];
	[loginWindowController.window makeKeyAndOrderFront:nil];
}

- (void)updateMenus {
    if (proxyState) {
        [_v2rayStatusItem setTitle:@"V2Ray: On"];
        [_enabelV2rayItem setTitle:@"停止服务"];
        NSImage *icon = [NSImage imageNamed:@"statusBarIcon"];
        [icon setTemplate:YES];
        [_statusBarItem setImage:icon];
    } else {
        [_v2rayStatusItem setTitle:@"V2Ray: Off"];
        [_enabelV2rayItem setTitle:@"开启服务"];
        [_statusBarItem setImage:[NSImage imageNamed:@"statusBarIcon_disabled"]];
        NSLog(@"icon updated");
    }
    [_v2rayRulesItem setState:proxyMode == rules];
    [_manualModeItem setState:proxyMode == manual];
    [_transModeItem setState:proxyMode == trans];
    
}

- (void)updateServerMenuList {
    [_serverListMenu removeAllItems];
    if ([profiles count] == 0) {
        [_serverListMenu addItem:[[NSMenuItem alloc] initWithTitle:@"no available servers, please add server profiles through config window." action:nil keyEquivalent:@""]];
    } else {
        int i = 0;
        for (ServerProfile *p in profiles) {
            NSString *itemTitle;
            if (![[p remark]isEqualToString:@""]) {
                itemTitle = [p remark];
            } else {
                itemTitle = [NSString stringWithFormat:@"%@:%lu",[p address], (unsigned long)[p port]];
            }
            NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:itemTitle action:@selector(switchServer:) keyEquivalent:@""];
            [newItem setTag:i];
            newItem.state = i == selectedServerIndex? 1 : 0;
            [_serverListMenu addItem:newItem];
            i++;
        }
    }
    [_serversItem setSubmenu:_serverListMenu];
}

- (void)switchServer:(id)sender {
    if (proxyMode == trans) {
        ServerProfile *profile = profiles[[sender tag]];
//        if (profile.port == 443) {
//            NSAlert *installAlert = [[NSAlert alloc] init];
//            [installAlert addButtonWithTitle:@"知道了"];
//            [installAlert setMessageText:@"透明模式目前仅支持带80端口或跳板机字样的服务器, 请在菜单-切换服务器中重新选择"];
//            [installAlert runModal];
//            return;
//        }
        selectedServerIndex = [sender tag];
        // 如果不unload以及unset 切换到不可用的服务器 再切回来会导致断网解析不到域名
        runCommandLine(@"/bin/launchctl", @[@"unload", plistTun2socksPath]);
        [self unsetSystemRoute];
        [self configurationDidChangeTransMode];
    } else {
        selectedServerIndex = [sender tag];
        [self configurationDidChange];
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInteger:selectedServerIndex] forKey:@"selectedServerIndex"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)readDefaults {
    NSDictionary *defaultsDic = [self readDefaultsAsDictionary];
    NSLog(@"read def array");
    proxyState = [defaultsDic[@"proxyState"] boolValue];
    proxyMode = [defaultsDic[@"proxyMode"] integerValue];
    localPort = [defaultsDic[@"localPort"] integerValue];
    httpPort = [defaultsDic[@"httpPort"] integerValue];
    udpSupport = [defaultsDic[@"udpSupport"] integerValue];
    shareOverLan = [defaultsDic[@"shareOverLan"] boolValue];
    [profiles removeAllObjects];
    profiles = defaultsDic[@"profiles"];
    dnsString = defaultsDic[@"dnsString"];
    logLevel = defaultsDic[@"logLevel"];
    selectedServerIndex = [defaultsDic[@"selectedServerIndex"] integerValue];
    NSLog(@"read %ld profiles, selected No.%ld", [profiles count] , selectedServerIndex);
}

- (NSDictionary*)readDefaultsAsDictionary {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *dLogLevel = nilCoalescing([defaults objectForKey:@"logLevel"], @"none");
    NSNumber *dProxyState = nilCoalescing([defaults objectForKey:@"proxyState"], [NSNumber numberWithBool:NO]); //turn off proxy as default
    NSNumber *dMode = nilCoalescing([defaults objectForKey:@"proxyMode"], [NSNumber numberWithInteger:rules]); // use v2ray rules as defualt mode
    NSNumber* dLocalPort = nilCoalescing([defaults objectForKey:@"localPort"], @1081);//use 1081 as default local port
    
    NSNumber* dHttpPort = nilCoalescing([defaults objectForKey:@"httpPort"], @8001); //use 8001 as default local http port
    NSNumber* dUdpSupport = nilCoalescing([defaults objectForKey:@"udpSupport"], [NSNumber numberWithBool:NO]);// do not support udp as default
    NSNumber* dShareOverLan = nilCoalescing([defaults objectForKey:@"shareOverLan"], [NSNumber numberWithBool:NO]); //do not share over lan as default
    NSString *dDnsString = nilCoalescing([defaults objectForKey:@"dnsString"], @"localhost");
    NSMutableArray *dProfilesInPlist = [defaults objectForKey:@"profiles"];
    NSMutableArray *dProfiles = [[NSMutableArray alloc] init];
    NSNumber *dServerIndex;
    if ([dProfilesInPlist isKindOfClass:[NSArray class]] && [dProfilesInPlist count] > 0) {
        for (NSDictionary *aProfile in dProfilesInPlist) {
            ServerProfile *newProfile =  [ServerProfile readFromAnOutboundDic:aProfile];
            [dProfiles addObject:newProfile];
        }
        dServerIndex = [defaults objectForKey:@"selectedServerIndex"];
        if ([dServerIndex integerValue] <= 0 || [dServerIndex integerValue] >= [dProfiles count]) {
            // "<= 0" also includes the case where dServerIndex is nil
            dServerIndex = [NSNumber numberWithInteger:0]; // treate illeagle selectedServerIndex value
        }
    } else {
        dServerIndex = [NSNumber numberWithInteger:-1];
    }
    return @{@"proxyState": dProxyState,
             @"logLevel": dLogLevel,
             @"proxyMode": dMode,
             @"localPort": dLocalPort,
             @"httpPort": dHttpPort,
             @"udpSupport": dUdpSupport,
             @"shareOverLan": dShareOverLan,
             @"profiles": dProfiles,
             @"selectedServerIndex": dServerIndex,
             @"dnsString":dDnsString};
}


-(void)unloadV2ray {
    dispatch_async(taskQueue, ^{
        runCommandLine(@"/bin/launchctl", @[@"unload", plistPath]);
        NSLog(@"V2Ray core unloaded.");
    });
}

-(void)unloadTun2socks {
    dispatch_async(taskQueue, ^{
        runCommandLine(@"/bin/launchctl", @[@"unload", plistTun2socksPath]);
        NSLog(@"Tun2socks unloaded.");
    });
}

- (NSDictionary*)generateFullConfigFrom:(ServerProfile*)selectedProfile {
    NSMutableDictionary* fullConfig = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"config-sample" ofType:@"plist"]];
    fullConfig[@"log"] = @{
                           @"access": [NSString stringWithFormat:@"%@/access.log", logDirPath],
                           @"error": [NSString stringWithFormat:@"%@/error.log", logDirPath],
                           @"loglevel": logLevel
                           };
    fullConfig[@"inbound"][@"port"] = @(localPort);
    fullConfig[@"inbound"][@"listen"] = shareOverLan ? @"0.0.0.0" : @"127.0.0.1";
    fullConfig[@"inboundDetour"][0][@"listen"] = shareOverLan ? @"0.0.0.0" : @"127.0.0.1";
    fullConfig[@"inboundDetour"][0][@"port"] = @(httpPort);
    fullConfig[@"inbound"][@"settings"][@"udp"] = [NSNumber numberWithBool:udpSupport];
    if (SWNOTEmptyStr(_serverIPStr) && proxyMode == trans) {
        fullConfig[@"outbound"] = [selectedProfile outboundProfileTransMode:_serverIPStr];
    } else {
        fullConfig[@"outbound"] = [selectedProfile outboundProfile];
    }
    if ([selectedProfile.proxySettings[@"address"] isKindOfClass:[NSString class]] && [selectedProfile.proxySettings[@"address"] length] > 0) {
        [fullConfig[@"outboundDetour"] addObject:fullConfig[@"outbound"][@"proxySettings"][@"outbound-proxy-config"]];
        [fullConfig[@"outbound"][@"proxySettings"] removeObjectForKey:@"outbound-proxy-config"];
    } else {
        [fullConfig[@"outbound"] removeObjectForKey:@"proxySettings"];
    }
    NSArray* dnsArray = [dnsString componentsSeparatedByString:@","];
    if ([dnsArray count] > 0) {
        fullConfig[@"dns"][@"servers"] = dnsArray;
    } else {
        fullConfig[@"dns"][@"servers"] = @[@"localhost"];
    }
    if (proxyMode == rules) {
        [fullConfig[@"routing"][@"settings"][@"rules"][0][@"ip"] addObject:@"geoip:cn"];
        [fullConfig[@"routing"][@"settings"][@"rules"]
         addObject:@{ @"domain": @[@"geosite:cn"],
                      @"outboundTag": @"direct",
                      @"type": @"field",
                     }];
    } else if (proxyMode == manual) {
        fullConfig[@"routing"][@"settings"][@"rules"] = @[];
    }
    
    return fullConfig;
}

-(BOOL)loadV2ray {
    NSString *configPath = [NSString stringWithFormat:@"%@/Library/Application Support/V2RayX/config.json",NSHomeDirectory()];
    printf("proxy mode is %ld\n", (long)proxyMode);
    NSDictionary *fullConfig = [self generateFullConfigFrom:profiles[selectedServerIndex]];
    NSData* v2rayJSONconfig = [NSJSONSerialization dataWithJSONObject:fullConfig options:NSJSONWritingPrettyPrinted error:nil];
    [v2rayJSONconfig writeToFile:configPath atomically:NO];
    [self generateLaunchdPlist:plistPath];
    dispatch_async(taskQueue, ^{
        runCommandLine(@"/bin/launchctl",  @[@"load", plistPath]);
        NSLog(@"V2Ray core loaded at port: %ld.", localPort);
    });
    return YES;
}

-(BOOL)loadTun2socks {
    [self generateLaunchdTun2socksPlist:plistTun2socksPath];
    // dispatch_async(taskQueue, ^{
        runCommandLine(@"/bin/launchctl",  @[@"load", plistTun2socksPath]);
    // });
    [self checkTun2socksRunStatus];
    return YES;
}

-(void)checkTun2socksRunStatus {
    NSLog(@"checkTun2socksRunStatus");
    NSString *output = [self runCommandLineWithReturn:@"/sbin/ifconfig" with:@[]];
    if (SWNOTEmptyStr(output) && [output containsString:@"240.0.0.1"]) {
        NSLog(@"checkTun2socksRunStatus_ok");
        return;
    } else {
        [NSThread sleepForTimeInterval:0.5];
        [self checkTun2socksRunStatus];
    }
}

-(void)generateLaunchdPlist:(NSString*)path {
    NSString* v2rayPath = [NSString stringWithFormat:@"%@/v2ray", [[NSBundle mainBundle] resourcePath]];
    NSString *configPath = [NSString stringWithFormat:@"%@/Library/Application Support/V2RayX/config.json",NSHomeDirectory()];
    NSDictionary *runPlistDic = [[NSDictionary alloc] initWithObjects:@[@"v2rayproject.v2rayx.v2ray-core", @[v2rayPath, @"-config", configPath], [NSNumber numberWithBool:YES]] forKeys:@[@"Label", @"ProgramArguments", @"RunAtLoad"]];
    [runPlistDic writeToFile:path atomically:NO];
}

-(void)generateLaunchdTun2socksPlist:(NSString*)path {
    NSDictionary *runPlistDic = [[NSDictionary alloc] initWithObjects:@[@"v2rayproject.v2rayx.tun2socks", @[kV2RayXTun2socks, @"-proxyServer", @"127.0.0.1:1081"], [NSNumber numberWithBool:YES]] forKeys:@[@"Label", @"ProgramArguments", @"RunAtLoad"]];
    [runPlistDic writeToFile:path atomically:NO];
}

void runCommandLine(NSString* launchPath, NSArray* arguments) {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:launchPath];
    [task setArguments:arguments];
    NSPipe *stdoutpipe = [NSPipe pipe];
    [task setStandardOutput:stdoutpipe];
    NSPipe *stderrpipe = [NSPipe pipe];
    [task setStandardError:stderrpipe];
    NSFileHandle *file;
    file = [stdoutpipe fileHandleForReading];
    [task launch];
    NSData *data;
    data = [file readDataToEndOfFile];
    NSString *string;
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0) {
        NSLog(@"%@", string);
    }
    file = [stderrpipe fileHandleForReading];
    data = [file readDataToEndOfFile];
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0) {
        NSLog(@"%@", string);
    }
}

- (NSString *)runCommandLineWithReturn:(NSString *)launchPath with:(NSArray *)arguments {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:launchPath];
    [task setArguments:arguments];
    NSPipe *stdoutpipe = [NSPipe pipe];
    [task setStandardOutput:stdoutpipe];
    NSPipe *stderrpipe = [NSPipe pipe];
    [task setStandardError:stderrpipe];
    NSFileHandle *file;
    file = [stdoutpipe fileHandleForReading];
    [task launch];
    NSData *data;
    data = [file readDataToEndOfFile];
    NSString *string;
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0) {
        NSLog(@"%@", string);
        return string;
    }
    file = [stderrpipe fileHandleForReading];
    data = [file readDataToEndOfFile];
    string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0) {
        NSLog(@"%@", string);
        return string;
    }
    return @"";
}

-(void)updateSystemProxy {
    NSArray *arguments;
    if (proxyState) {
        if (proxyMode == 1) { // pac mode
            runCommandLine(kV2RayXHelper, @[@"off"]);
            arguments = @[@"auto"];
        } else {
            if (proxyMode == 3) { // manual mode
                arguments = [self currentProxySetByMe] ? @[@"off"] : @[@"-v"];
            } else if (proxyMode == 4) { // trans mode
                arguments = @[@"off"];
            } else { // global mode and rule mode
                arguments = @[@"global", [NSString stringWithFormat:@"%ld", localPort]];
            }
        }
    } else {
        arguments = [NSArray arrayWithObjects:@"off", nil];
    }
    runCommandLine(kV2RayXHelper,arguments);
    NSLog(@"system proxy state:%@,%ld",proxyState?@"on":@"off", (long)proxyMode);
}

-(BOOL)currentProxySetByMe {
    SCPreferencesRef prefRef = SCPreferencesCreate(nil, CFSTR("V2RayX"), nil);
    NSDictionary* sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
    //NSLog(@"%@", sets);
    for (NSString *key in [sets allKeys]) {
        NSMutableDictionary *dict = [sets objectForKey:key];
        NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
        if ([hardware isEqualToString:@"AirPort"] || [hardware isEqualToString:@"Wi-Fi"] || [hardware isEqualToString:@"Ethernet"]) {
            NSDictionary* proxy = dict[(NSString*)kSCEntNetProxies];
            BOOL autoProxy = [proxy[(NSString*) kCFNetworkProxiesProxyAutoConfigURLString] isEqualToString:@"http://127.0.0.1:8070/proxy.pac"];
            BOOL autoProxyEnabled = [proxy[(NSString*) kCFNetworkProxiesProxyAutoConfigEnable] boolValue];
            BOOL socksProxy = [proxy[(NSString*) kCFNetworkProxiesSOCKSProxy] isEqualToString:@"127.0.0.1"];
            BOOL socksPort = [proxy[(NSString*) kCFNetworkProxiesSOCKSPort] integerValue] == localPort;
            BOOL socksProxyEnabled = [proxy[(NSString*) kCFNetworkProxiesSOCKSEnable] boolValue];
            if ((autoProxyEnabled && autoProxy) || (socksProxyEnabled && socksPort && socksProxy) ) {
                continue;
            } else {
                NSLog(@"Device %@ is not set by me", key);
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)installHelper {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:kV2RayXHelper] ||
        ![fileManager fileExistsAtPath:kV2RayXTun2socks] ||
        ![fileManager fileExistsAtPath:kV2RayXRoute] ||
        ![fileManager fileExistsAtPath:kV2RayXChangedns] ||
        ![self isSysconfVersionOK]) {
        // 判断路径有没空格 否则退出
        if ([[[NSBundle mainBundle] resourcePath] containsString:@" "]) {
            NSAlert *installAlert = [[NSAlert alloc] init];
            [installAlert addButtonWithTitle:@"退出"];
            [installAlert setMessageText:@"检测到当前app名称或者路径包含空格, 请删除空格后再打开"];
            if ([installAlert runModal] == NSAlertFirstButtonReturn) {
                [[NSApplication sharedApplication] terminate:nil];
            }
        }
        NSAlert *installAlert = [[NSAlert alloc] init];
        [installAlert addButtonWithTitle:@"Install"];
        [installAlert addButtonWithTitle:@"Quit"];
        [installAlert setMessageText:@"V2RayX needs to install a small tool to /Library/Application Support/V2RayX/ with administrator privileges to set system proxy quickly.\nOtherwise you need to type in the administrator password every time you change system proxy through V2RayX."];
        if ([installAlert runModal] == NSAlertFirstButtonReturn) {
            NSLog(@"start install");
            NSString *helperPath = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], @"install_helper.sh"];
            NSLog(@"run install script: %@", helperPath);
            NSDictionary *error;
            NSString *script = [NSString stringWithFormat:@"do shell script \"bash %@\" with administrator privileges", helperPath];
            NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
            if ([appleScript executeAndReturnError:&error]) {
                NSLog(@"installation success");
                return YES;
            } else {
                NSLog(@"installation failure");
                //unknown failure
                return NO;
            }
        } else {
            // stopped by user
            return NO;
        }
    } else {
        // helper already installed
        return YES;
    }
}

- (BOOL)setSystemTransMode {
    ServerProfile *profile = profiles[selectedServerIndex];
    if (SWNOTEmptyStr(profile.address)) {
        _serverIPStr = [self getIPWithHostName:profile.address];
        if (!SWNOTEmptyStr(_serverIPStr) || ![self isIPAddress:_serverIPStr]) {
            NSAlert *installAlert = [[NSAlert alloc] init];
            [installAlert addButtonWithTitle:@"知道了"];
            [installAlert setMessageText:@"解析服务器ip地址失败, 请在菜单中选择重置网络设置后再试"];
            [installAlert runModal];
            return NO;
        }
    }
    
    NSString *output = [self runCommandLineWithReturn:kV2RayXRoute with:@[@"-n",@"get",@"default"]];
    NSArray *array = [output componentsSeparatedByString:@"\n"];
    NSString *errorStr;
    if (![output containsString:@"route: writing to routing socket: not in table"]) {
        if (SWNOTEmptyArr(array)) {
            for (NSString *str in array) {
                if ([str containsString:@"gateway"]) {
                    NSString *tmpstr = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
                    NSArray *tmpArray = [tmpstr componentsSeparatedByString:@":"];
                    if (SWNOTEmptyArr(tmpArray) && tmpArray.count == 2) {
                        if ([self isIPAddress:tmpArray[1]]) {
                            if ([tmpArray[1] isEqualToString:@"240.0.0.1"]) {
                                errorStr = @"当前已设置过网关(说明已在此模式), 如果网络不正常 请在菜单中选择重置网络设置后再试";
                                break;
                            } else {
                                _gatewayIP = tmpArray[1];
                                break;
                            }
                        } else {
                            errorStr = @"网关地址获取失败, 请在菜单中选择重置网络设置后再试";
                            break;
                        }
                    } else {
                        errorStr = @"网关地址获取失败, 请在菜单中选择重置网络设置后再试";
                        break;
                    }
                }
            }
        } else {
            errorStr = @"route命令没有返回信息, 请在菜单中选择重置网络设置后再试";
        }
    } else {
        errorStr = @"默认网关丢了.. 请把wifi关掉然后再开启后再试(有线的话拔掉网线在插入), 或者在菜单-重置网络中手动输入(如果你知道的话, 一般为路由器的管理页面地址), 如果不这样做你会一直在断网中..";
    }
    if (SWNOTEmptyStr(errorStr) || !SWNOTEmptyStr(_gatewayIP)) {
        NSAlert *installAlert = [[NSAlert alloc] init];
        [installAlert addButtonWithTitle:@"知道了"];
        [installAlert setMessageText:errorStr];
        [installAlert runModal];
        return NO;
    }
    
    [self setSystemRoute];
    return YES;
}

- (void)setSystemRoute {
    runCommandLine(kV2RayXChangedns, @[@"on", @"8.8.8.8"]);
    runCommandLine(kV2RayXRoute, @[@"delete", @"default"]);
    runCommandLine(kV2RayXRoute, @[@"add", @"default", @"240.0.0.1"]);
    runCommandLine(kV2RayXRoute, @[@"add", _serverIPStr, _gatewayIP]);
    runCommandLine(kV2RayXRoute, @[@"add", @"192.168.0.0/16", _gatewayIP]);
}

- (void)unsetSystemRoute {
    runCommandLine(kV2RayXChangedns, @[@"off"]);
    runCommandLine(kV2RayXRoute, @[@"delete", @"default"]);
    runCommandLine(kV2RayXRoute, @[@"add", @"default", _gatewayIP]);
    runCommandLine(kV2RayXRoute, @[@"delete", _serverIPStr]);
    runCommandLine(kV2RayXRoute, @[@"delete", @"192.168.0.0/16"]);
}

- (BOOL)isIPAddress:(NSString *)ip {
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$" options:0 error:nil];
    NSArray *results = [regex matchesInString:ip options:0 range:NSMakeRange(0, ip.length)];
    return results.count > 0;
}

- (NSString*)getIPWithHostName:(const NSString*)hostName {
    const char *hostN= [hostName UTF8String];
    struct hostent* phot;
    @try {
        phot = gethostbyname(hostN);
    } @catch (NSException *exception) {
        return nil;
    }
    struct in_addr ip_addr;
    if (phot == NULL) {
        NSLog(@"获取失败");
        return nil;
    }
    memcpy(&ip_addr, phot->h_addr_list[0], 4);
    char ip[20] = {0}; inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));
    NSString* strIPAddress = [NSString stringWithUTF8String:ip];
    NSLog(@"ip=====%@",strIPAddress);
    return strIPAddress;
}

- (BOOL)isSysconfVersionOK {
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath:kV2RayXHelper];
    
    NSArray *args;
    args = [NSArray arrayWithObjects:@"-v", nil];
    [task setArguments: args];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *fd;
    fd = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [fd readDataToEndOfFile];
    
    NSString *str;
    str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (![str isEqualToString:kSysconfVersion]) {
        return NO;
    }
    return YES;
}

-(void)configurationDidChange {
    [self unloadV2ray];
    // [self readDefaults];
    if (proxyState) {
        if (selectedServerIndex >= 0 && selectedServerIndex < [profiles count]) {
            [self loadV2ray];
        } else {
            proxyState = NO;
            //[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"proxyState"];
            NSAlert *noServerAlert = [[NSAlert alloc] init];
            [noServerAlert setMessageText:@"No available Server Profiles!"];
            [noServerAlert runModal];
            NSLog(@"V2Ray core loaded failed: no avalibale servers.");
        }
    }
    [self updateSystemProxy];
    [self updateMenus];
    [self updateServerMenuList];
}

-(void)configurationDidChangeTransMode {
    if (proxyState) {
        if (selectedServerIndex >= 0 && selectedServerIndex < [profiles count]) {
            [self loadTun2socks];
            if (![self setSystemTransMode]) {
                return;
            }
            // 如果提前设置了 但是检测失败了 会影响切换其他模式
            proxyMode = trans;
            [self unloadV2ray];
            [self loadV2ray];
        } else {
            proxyState = NO;
            //[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"proxyState"];
            NSAlert *noServerAlert = [[NSAlert alloc] init];
            [noServerAlert setMessageText:@"No available Server Profiles!"];
            [noServerAlert runModal];
            NSLog(@"V2Ray core loaded failed: no avalibale servers.");
        }
    } else {
        [self unloadV2ray];
        [self unloadTun2socks];
        [self unsetSystemRoute];
    }
    [self updateSystemProxy];
    [self updateMenus];
    [self updateServerMenuList];
}

- (IBAction)copyExportCmd:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    NSString* command = [NSString stringWithFormat:@"export http_proxy=\"http://127.0.0.1:%ld\"; export HTTP_PROXY=\"http://127.0.0.1:%ld\"; export https_proxy=\"http://127.0.0.1:%ld\"; export HTTPS_PROXY=\"http://127.0.0.1:%ld\"", httpPort, httpPort, httpPort, httpPort];
    [[NSPasteboard generalPasteboard] setString:command forType:NSStringPboardType];
}


@synthesize logDirPath;

@synthesize proxyState;
@synthesize proxyMode;
@synthesize localPort;
@synthesize httpPort;
@synthesize udpSupport;
@synthesize shareOverLan;
@synthesize selectedServerIndex;
@synthesize dnsString;
@synthesize profiles;
@synthesize logLevel;
@end
