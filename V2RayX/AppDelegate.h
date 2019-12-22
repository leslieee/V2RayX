//
//  AppDelegate.h
//  V2RayX
//
//  Copyright © 2016年 Cenmrev. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kV2RayXHelper @"/Library/Application Support/V2RayX/v2rayx_sysconf"
#define kV2RayXTun2socks @"/Library/Application Support/V2RayX/tun2socks"
#define kV2RayXRoute @"/Library/Application Support/V2RayX/route"
#define kV2RayXChangedns @"/Library/Application Support/V2RayX/changedns"
#define kSysconfVersion @"v2rayx_sysconf 1.0.0"
#define kV2RayXSettingVersion 4
#define nilCoalescing(a,b) ( (a != nil) ? (a) : (b) ) // equivalent to ?? operator in Swift
#define NOTNULL(x) ((![x isKindOfClass:[NSNull class]])&&x)
#define SWNOTEmptyArr(X) (NOTNULL(X)&&[X isKindOfClass:[NSArray class]]&&[X count])
#define SWNOTEmptyDictionary(X) (NOTNULL(X)&&[X isKindOfClass:[NSDictionary class]]&&[[X allKeys]count])
#define SWNOTEmptyStr(X) (NOTNULL(X)&&[X isKindOfClass:[NSString class]]&&((NSString *)X).length)

typedef enum ProxyMode : NSInteger{
    rules,
    pac,
    global,
    manual,
    trans
} ProxyMode;


@interface AppDelegate : NSObject <NSApplicationDelegate> {
    BOOL proxyState;
    ProxyMode proxyMode;
    NSInteger localPort;
    NSInteger httpPort;
    BOOL udpSupport;
    BOOL shareOverLan;
    NSInteger selectedServerIndex;
    NSString* dnsString;
    NSMutableArray *profiles;
    NSString* logLevel;
    
    
    NSString* plistPath;
    NSString* plistTun2socksPath;
    NSString* pacPath;
    NSString* logDirPath;
}

@property NSString* logDirPath;

@property BOOL proxyState;
@property ProxyMode proxyMode;
@property NSInteger localPort;
@property NSInteger httpPort;
@property BOOL udpSupport;
@property BOOL shareOverLan;
@property NSInteger selectedServerIndex;
@property NSString* dnsString;
@property NSMutableArray *profiles;
@property NSString* logLevel;
@property NSString *serverIPStr;
@property NSString *gatewayIP;


- (IBAction)showHelp:(id)sender;
- (IBAction)enableProxy:(id)sender;
- (IBAction)chooseV2rayRules:(id)sender;
- (IBAction)chooseManualMode:(id)sender;
- (IBAction)chooseTransMode:(id)sender;
- (IBAction)showConfigWindow:(id)sender;
- (IBAction)viewLog:(id)sender;
- (IBAction)loginToSpeedss:(id)sender;
- (IBAction)blockAds:(id)sender;


- (void)configurationDidChange;
- (NSString*)logDirPath;

@property (strong, nonatomic)  NSStatusItem *statusBarItem;
@property (strong, nonatomic) IBOutlet NSMenu *statusBarMenu;
@property (weak, nonatomic) IBOutlet NSMenuItem *v2rayStatusItem;
@property (weak, nonatomic) IBOutlet NSMenuItem *enabelV2rayItem;
@property (weak, nonatomic) IBOutlet NSMenuItem *v2rayRulesItem;
@property (weak) IBOutlet NSMenuItem *manualModeItem;
@property (weak) IBOutlet NSMenuItem *transModeItem;
@property (weak, nonatomic) IBOutlet NSMenuItem *serversItem;
@property (weak, nonatomic) IBOutlet NSMenu *serverListMenu;
@property (weak) IBOutlet NSMenuItem *blockAdsItem;

@end

