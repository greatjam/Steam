//
//  MainViewController.m
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
//License along with Steam.  If not, see <http://www.gnu.org/licenses/>.
//

#import "MainViewController.h"

#import <asihttprequest/ASIHTTPRequest.h>
#import "JSONKit.h"
#import "Steam.h"
#import "SteamHelper.h"

@interface MainViewController ()

@end

@implementation MainViewController
@synthesize playtime;
@synthesize playProgress;
@synthesize bufferProgress;
@synthesize playButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self.playButton addTarget:self action:@selector(startPlay:) forControlEvents:UIControlEventTouchUpInside];
    self.playButton.titleLabel.text = @"Play";
}

- (void)viewDidUnload
{
    [self setPlaytime:nil];
    [self setPlayProgress:nil];
    [self setBufferProgress:nil];
    [self setPlayButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamStateChanged:) name:SteamStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamBufferStateChanged:) name:SteamBufferStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamAudioStateChanged:) name:SteamAudioStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(steamBuffered:) name:SteamBufferedNotification object:nil];
    
    
}

- (IBAction)startPlay:(id)sender
{
    [self playNext];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void) steamBuffered:(NSNotification *)notification
{
    self.bufferProgress.progress = ((float)_steam.bufferedLength) / (float)_steam.totalLength;
}

-(void) steamStateChanged:(NSNotification *)notification
{
    LOGSTATUS(@"%d", _steam.state);
    if (SteamWorking == _steam.state) {
        self.playButton.titleLabel.text = @"Pause";
    }
    else if(SteamPrebuffering == _steam.state) {
        self.playButton.titleLabel.text = @"Prebuffering";
    }
    else {
        self.playButton.titleLabel.text = @"Play";
        if (SteamStopped == _steam.state) {
            RELEASE_SAFELY(_steam);
            [self playNext];
        }
    }
}

-(void) steamBufferStateChanged:(NSNotification *)notification
{
    LOGSTATUS(@"%d", _steam.bufferState);
}

-(void) steamAudioStateChanged:(NSNotification *)notification
{
    LOGSTATUS(@"%d", _steam.audioState);
}

- (void)playNext
{
    if ([_songs count]) {
        NSDictionary * song = [_songs objectAtIndex:0];
        [[song retain] autorelease];
        [_songs removeObjectAtIndex:0];
        
        if (_steam) {
            RELEASE_SAFELY(_steam);
        }
        NSURL * url = [NSURL URLWithString:[song objectForKey:@"url"]];
        _steam = [[Steam alloc] initWithURL:url];
        [_steam play];
    }
    else {
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
        self.playButton.titleLabel.text = @"Sending request";
        [request startAsynchronous];
    }
}

- (void)dealloc {
    RELEASE_SAFELY(_steam);
    [playtime release];
    [playProgress release];
    [bufferProgress release];
    [playButton release];
    [super dealloc];
}
@end
