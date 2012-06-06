//
//  AppDelegate.m
//  YPlayer
//
//Copytright(c) 2011 Hongbo Yang (hongbo@yang.me). All rights reserved
//This file is part of Steam.
//
//Steam is free software: you can redistribute it and/or modify
//it under the terms of the GNU Lesser General Public License as 
//published by the Free Software Foundation, either version 3 of 
//the License, or (at your option) any later version.
//
//Steam is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU Lesser General Public License for more details.
//
//You should have received a copy of the GNU Lesser General Public 
//License along with YToolkit.  If not, see <http://www.gnu.org/licenses/>.
//

#import "AppDelegate.h"
#import <asihttprequest/ASIHTTPRequest.h>
#import "JSONKit.h"
#import "Steam.h"
#import "SteamHelper.h"
#import "MainViewController.h"

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamStateChanged:) name:SteamStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamBufferStateChanged:) name:SteamBufferStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamAudioStateChanged:) name:SteamAudioStateChangedNotification object:nil];
    
    ASIHTTPRequest * request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://www.douban.com/j/app/radio/people?type=n&channel=1&app_name=radio_iphone&version=83"]];
    [request setCompletionBlock:^{
        NSString * json = request.responseString;
        RELEASE_SAFELY(_songs);
        id object = [json objectFromJSONString];
        if ([object isKindOfClass:[NSDictionary class]]) {
            if(0 == [[object objectForKey:@"r"] intValue]) {
                _songs = [[object objectForKey:@"song"] mutableCopy];
                [self playNext];
            }
        }
    }];
    [request startAsynchronous];

    /*NSURL * u = [[NSBundle mainBundle] URLForResource:@"06" withExtension:@"mp3"];
    Steam * st = [[Steam alloc] initWithURL:u];
    [st play];
     */
    return YES;
}

-(void) steamStateChanged:(NSNotification *)notification
{
    LOGSTATUS(@"");
}

-(void) steamBufferStateChanged:(NSNotification *)notification
{
    LOGSTATUS(@"");
}

-(void) steamAudioStateChanged:(NSNotification *)notification
{
    LOGSTATUS(@"");
}
            
- (void)playNext
{
    if ([_songs count]) {
        NSDictionary * song = [_songs objectAtIndex:0];
        [[song retain] autorelease];
        [_songs removeObject:0];
        
        if (_steam) {
            RELEASE_SAFELY(_steam);
        }
        NSURL * url = [NSURL URLWithString:[song objectForKey:@"url"]];
        _steam = [[Steam alloc] initWithURL:url];
        [_steam play];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
