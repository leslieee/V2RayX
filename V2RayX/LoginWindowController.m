//
//  LoginWindowController.m
//  V2RayX
//
//  Created by leslie on 1/14/18.
//  Copyright © 2018 Project V2Ray. All rights reserved.
//

#import "LoginWindowController.h"
#import "AppDelegate.h"
#import "NSDictionary+Json.h"

@interface LoginWindowController () {
	NSAlert *noServerAlert;
	NSMutableArray *profiles;
}
@property (weak) IBOutlet NSTextField *emailTF;
@property (weak) IBOutlet NSTextField *passwdTF;
@property (weak) IBOutlet NSButton *loginButton;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@end

@implementation LoginWindowController

-(void)awakeFromNib {
	[super awakeFromNib];
	[self.window setBackgroundColor:[NSColor whiteColor]];
}

- (void)windowDidLoad {
    [super windowDidLoad];
	noServerAlert = [[NSAlert alloc] init];
	_loginButton.target = self;
	_loginButton.action = @selector(loginButtonClick);
	profiles = [_appDelegate profiles];
}

- (void)loginButtonClick {
	NSString *email = [_emailTF stringValue];
	NSString *passwd = [_passwdTF stringValue];
	if ([email isEqualToString:@""] || [passwd isEqualToString:@""]) {
		[self showAlert:@"邮箱密码不能为空额"];
		return;
	}
	// 发送请求
	NSString *urlStr = [NSString stringWithFormat:
						@"https://speedss.top/getandroidserverconfig?email=%@&passwd=%@", email, passwd];
	NSString *encodeUrlStr = [urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url=[NSURL URLWithString:encodeUrlStr];
	NSURLSession *session=[NSURLSession sharedSession];
	__weak typeof(self) weakSelf = self;
	[_progressIndicator startAnimation:self];
	NSURLSessionDataTask * task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, 
		NSURLResponse * _Nullable response, NSError * _Nullable error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf.progressIndicator stopAnimation:weakSelf];
		});
		if (error != nil) {
			[weakSelf showAlert:error.localizedDescription];
			return;
		}
		id jsonDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
		if ([jsonDic isKindOfClass:[NSDictionary class]]) {
			[weakSelf showAlert:[jsonDic objectForKey:@"msg"]];
			return;
		} else if ([jsonDic isKindOfClass:[NSArray class]]) {
			[profiles removeAllObjects];
			for (NSString *item in jsonDic) {
				NSString *base64Str = [item stringByReplacingOccurrencesOfString:@"vmess://" withString:@""];
				// base64转string
				NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64Str options:0];
				NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
				// json转dic
				NSData *objectData = [decodedString dataUsingEncoding:NSUTF8StringEncoding];
				NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:objectData options:NSJSONReadingMutableContainers error:nil];
				NSLog(@"%@", jsonDic.description);
				// 新增配置
				ServerProfile* newProfile;
				if ([[jsonDic stringValueForKey:@"tls"] isEqualToString:@"tls"]) {
					newProfile = [[ServerProfile alloc] initWithTls:YES];
				} else {
					newProfile = [[ServerProfile alloc] initWithTls:NO];
				}
				newProfile.address = [jsonDic objectForKey:@"add"];
				newProfile.port = [jsonDic intValueForKey:@"port" defaultValue:0];
				newProfile.userId = [jsonDic objectForKey:@"id"];
				newProfile.alterId = [jsonDic intValueForKey:@"aid" defaultValue:0];
				newProfile.remark = [jsonDic objectForKey:@"ps"];
				if ([[jsonDic stringValueForKey:@"net"] isEqualToString:@"ws"]) {
					newProfile.network = 2;
				}
				[profiles addObject:newProfile];
			}
			// 保存配置到userdefaults
			NSMutableArray* profilesArray = [[NSMutableArray alloc] init];
			for (ServerProfile* p in profiles) {
				[profilesArray addObject:[p outboundProfile]];
			}
			[[NSUserDefaults standardUserDefaults] setObject:profilesArray forKey:@"profiles"];
			// 开启服务
			[[NSUserDefaults standardUserDefaults] setObject:@(1) forKey:@"proxyState"];
			// 默认v2ray模式
			[[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:@"proxyMode"];
			// 登录标志位
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"is_login"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			NSLog(@"Settings saved.");
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf.appDelegate setProxyState:YES];
				[weakSelf.appDelegate setProxyMode:0];
				[weakSelf.appDelegate configurationDidChange];
				[weakSelf showAlert:@"自动获取配置并连接成功! "];
				
			});
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[weakSelf.window close];
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.google.com"]];
			});
		}
	}];
	[task resume];
}

- (void)showAlert:(NSString *)info {
	dispatch_async(dispatch_get_main_queue(), ^{
		[noServerAlert setMessageText:info];
		[noServerAlert runModal];
	});
	
}

@end
