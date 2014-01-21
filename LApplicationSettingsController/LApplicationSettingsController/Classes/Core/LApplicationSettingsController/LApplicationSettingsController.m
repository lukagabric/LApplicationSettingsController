//
//  Created by Luka Gabrić.
//  Copyright (c) 2013 Luka Gabrić. All rights reserved.
//


#import "LApplicationSettingsController.h"
#import "Reachability.h"
#import "ASIHTTPRequest.h"
#import "ASIDownloadCache.h"
#include <sys/xattr.h>


@implementation LApplicationSettingsController


#pragma mark - Singleton


+ (LApplicationSettingsController *)sharedApplicationSettingsController
{
	__strong static LApplicationSettingsController *sharedApplicationSettingsController = nil;
    
	static dispatch_once_t onceToken;
    
	dispatch_once(&onceToken, ^{
        sharedApplicationSettingsController = [LApplicationSettingsController new];
    });
    
	return sharedApplicationSettingsController;
}


#pragma mark - init & dealloc


- (id)init
{
	self = [super init];
	if (self)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
	}
	return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Setters


- (void)setApplicationSettingsUrl:(NSString *)applicationSettingsUrl
{
	_applicationSettingsDictionary = self.applicationSettingsDictionary;
	_applicationSettingsUrl = applicationSettingsUrl;
    
	[self refresh];
}


#pragma mark - Getters


- (NSDictionary *)applicationSettingsDictionary
{
	NSDictionary *dictionary = nil;
    
	NSString *downloadedFilePath = [self plistPath];
	NSString *bundleFilePath = [[NSBundle mainBundle] pathForResource:@"application-settings" ofType:@"plist"];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:downloadedFilePath])
	{
		dictionary = [NSDictionary dictionaryWithContentsOfFile:downloadedFilePath];
	}
    
	if (dictionary)
	{
#if DEBUG
		NSLog(@"Using cached application-settings.plist");
#endif
		return dictionary;
	}
	else
	{
#if DEBUG
		NSLog(@"Using bundled application-settings.plist");
#endif
		return [NSDictionary dictionaryWithContentsOfFile:bundleFilePath];
	}
}


#pragma mark - Notification center


- (void)appWillEnterForeground
{
	[self refresh];
}


- (void)appDidEnterBackground
{
	[self cancelDownloading];
}


#pragma mark - Refresh


- (void)refresh
{
    NSURL *applicationSettingsURL = [NSURL URLWithString:_applicationSettingsUrl];
    
	if ([_request isExecuting] || !applicationSettingsURL)	return;
    
	_downloadFailed = NO;
    
	_request = [ASIHTTPRequest requestWithURL:applicationSettingsURL usingCache:[ASIDownloadCache sharedCache] andCachePolicy:ASIAskServerIfModifiedCachePolicy];
    _request.cacheStoragePolicy = ASICachePermanentlyCacheStoragePolicy;
    
	__weak ASIHTTPRequest *weakReq = _request;
	__weak LApplicationSettingsController *weakSelf = self;
	__weak NSDictionary *appSettingsDict = _applicationSettingsDictionary;
    
	[_request setCompletionBlock:^{
        NSString *tmpPlistPath = [weakSelf tmpPlistPath];
        
        [weakReq.responseData writeToFile:tmpPlistPath atomically:YES];
        
        NSDictionary *tmpAppSettingsDictionary = [NSDictionary dictionaryWithContentsOfFile:tmpPlistPath];
        
        if (tmpAppSettingsDictionary)
        {
            @synchronized(appSettingsDict)
            {
                weakSelf.applicationSettingsDictionary = tmpAppSettingsDictionary;
                [weakSelf moveTmpToRealPlistLocation];
                [weakSelf addSkipBackupAttributeToItemAtPath:[weakSelf plistPath]];
#if DEBUG
                NSLog(@"application-settings.plist refreshed.");
#endif
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kApplicationSettingsPlistDownloaded object:nil];
            }
        }
        else
        {
            [weakSelf removeTmpPlist];
        }
    }];
    
	[_request setFailedBlock:^{
        weakSelf.downloadFailed = YES;
    }];
    
	[_request startAsynchronous];
}


- (void)cancelDownloading
{
	_downloadFailed = NO;
    
	if (_request)
	{
		[_request clearDelegatesAndCancel];
		_request = nil;
	}
}


#pragma mark - Reachability


- (void)reachabilityChanged:(NSNotification *)note
{
	if (_downloadFailed)
	{
		Reachability *reachability = [note object];
        
		if ([reachability isReachable])
		{
			[self refresh];
		}
	}
}


#pragma mark - Key/Value


- (id)objectForKey:(NSString *)key
{
    return [_applicationSettingsDictionary objectForKey:key];
}


- (NSString *)valueForKey:(NSString *)key parentKey:(NSString *)parentKey
{
	if (parentKey && key)
		return [[self objectForKey:parentKey] objectForKey:key];
    
	return nil;
}


- (NSString *)urlForKey:(NSString *)key
{
    return [self valueForKey:key parentKey:@"mDNS"];
}


- (BOOL)UIEnabledForKey:(NSString *)key
{
    return [[self valueForKey:key parentKey:@"UI"] boolValue];
}


- (NSString *)paramForKey:(NSString *)key
{
    return [self valueForKey:key parentKey:@"params"];
}


- (NSString *)addonsForParentKey:(NSString *)parentKey andKey:(NSString *)key
{
    return [[[self objectForKey:@"addons"] objectForKey:parentKey] objectForKey:key];
}


- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger supportedInterfaceOrientations = 0;
    
    NSDictionary *orientationDict = [self objectForKey:@"orientation"];
    
    if ([[orientationDict objectForKey:@"portrait"] boolValue]) supportedInterfaceOrientations |= UIInterfaceOrientationMaskPortrait;
    if ([[orientationDict objectForKey:@"portrait_upside_down"] boolValue]) supportedInterfaceOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;
    if ([[orientationDict objectForKey:@"landscape_right"] boolValue]) supportedInterfaceOrientations |= UIInterfaceOrientationMaskLandscapeRight;
    if ([[orientationDict objectForKey:@"landscape_left"] boolValue]) supportedInterfaceOrientations |= UIInterfaceOrientationMaskLandscapeLeft;
    
    return supportedInterfaceOrientations;
}


#pragma mark - Paths


- (NSString *)plistPath
{
	return [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"application-settings.plist"];
}


- (NSString *)tmpPlistPath
{
	return [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"tmp-application-settings.plist"];
}


#pragma mark - File management


- (BOOL)moveTmpToRealPlistLocation
{
	BOOL deleteFlag = NO;
	BOOL moveFlag = NO;
    
	NSError *error = nil;
	NSFileManager *fm = [[NSFileManager alloc] init];
    
	deleteFlag = [fm removeItemAtPath:[self plistPath] error:&error];
    
#if DEBUG
	if (error)
	{
		NSLog(@"LApplicationSettingsController: delete plist error: %@", error);
	}
#endif
    
	error = nil;
    
	moveFlag = [fm moveItemAtPath:[self tmpPlistPath]
						   toPath:[self plistPath]
							error:&error];
#if DEBUG
	if (error)
	{
		NSLog(@"LApplicationSettingsController: move plist error: %@", error);
	}
#endif
    
	return deleteFlag && moveFlag;
}


- (BOOL)removeTmpPlist
{
	BOOL retFlag;
    
	NSError *error = nil;
	NSFileManager *fm = [[NSFileManager alloc] init];
    
	retFlag = [fm removeItemAtPath:[self tmpPlistPath] error:&error];
    
#if DEBUG
	if (error)
	{
		NSLog(@"LApplicationSettingsController: remove tmp plist error: %@", error);
	}
#endif
    
	return retFlag;
}


- (void)saveCurrentDictToDisk
{
    [self.applicationSettingsDictionary writeToFile:[self plistPath] atomically:NO];
}


#pragma mark - Flag


- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *)path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    
    const char* filePath = [path fileSystemRepresentation];
    
    const char* attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    
    int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
    return result == 0;
}


#pragma mark -


@end