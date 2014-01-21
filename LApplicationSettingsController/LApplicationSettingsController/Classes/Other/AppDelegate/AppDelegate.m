//
//  AppDelegate.m
//  LApplicationSettingsController
//
//  Created by Luka Gabric on 21/01/14.
//
//


#import "AppDelegate.h"


@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[LApplicationSettingsController sharedApplicationSettingsController] setApplicationSettingsUrl:@"http://vt-mobconn.nth.ch/dns/iphone/morgans-sales/1.0.0/live/application-settings.plist"];
	   
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    [self.window makeKeyAndVisible];
    
    return YES;
}



@end