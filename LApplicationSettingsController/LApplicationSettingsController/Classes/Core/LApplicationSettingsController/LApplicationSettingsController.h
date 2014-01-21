//
//  Created by Luka Gabrić.
//  Copyright (c) 2013 Luka Gabrić. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"


#define kApplicationSettingsPlistDownloaded @"kApplicationSettingsPlistDownloaded"


#define appConfig(key) [[LApplicationSettingsController sharedApplicationSettingsController] objectForKey:key]
#define mDNS(key) [[LApplicationSettingsController sharedApplicationSettingsController] urlForKey:key]
#define UIEnabled(key) [[LApplicationSettingsController sharedApplicationSettingsController] UIEnabledForKey:key]
#define appConfigAddon(parentKey, key) [[LApplicationSettingsController sharedApplicationSettingsController] addonsForParentKey:parentKey andKey:key]
#define appConfigParam(key) [[LApplicationSettingsController sharedApplicationSettingsController] paramForKey:key]
#define appConfigSupportedOrientations() [[LApplicationSettingsController sharedApplicationSettingsController] supportedInterfaceOrientations]


@interface LApplicationSettingsController : NSObject
{
	ASIHTTPRequest *_request;
}


@property (nonatomic, strong) NSString *applicationSettingsUrl;


+ (LApplicationSettingsController *)sharedApplicationSettingsController;


- (id)objectForKey:(NSString *)key;
- (NSString *)urlForKey:(NSString *)key;
- (BOOL)UIEnabledForKey:(NSString *)key;
- (NSString *)paramForKey:(NSString *)key;
- (NSString *)addonsForParentKey:(NSString *)parentKey andKey:(NSString *)key;
- (NSUInteger)supportedInterfaceOrientations;
- (void)saveCurrentDictToDisk;


@end


#pragma mark - Protected


@interface LApplicationSettingsController ()


@property (nonatomic, assign) BOOL downloadFailed;
@property (nonatomic, strong) NSDictionary *applicationSettingsDictionary;


@end