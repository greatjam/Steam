//
//  Steam.m
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

#import "Steam.h"
#import "SteamHelper.h"
#import "Steam+Buffer.h"
#import "Steam+Audio.h"
#import "Steam+Private.h"

IMPLEMENT_NOTIFICATION(SteamStateChangedNotification);
IMPLEMENT_NOTIFICATION(SteamBufferStateChangedNotification);
IMPLEMENT_NOTIFICATION(SteamAudioStateChangedNotification);
IMPLEMENT_NOTIFICATION(SteamBufferedNotification);

@interface Steam ()
@property (atomic, readwrite, assign) SteamState state;
@property (atomic, readwrite, RETAIN_STRONG) NSURL * url;
@property (atomic, readwrite, assign) NSUInteger bufferedLength;
@property (atomic, readwrite, assign) NSUInteger totalLength;
@property (atomic, readwrite, assign) BOOL isFile;

@end


@implementation Steam
@synthesize state = _state;
@synthesize url = _url;
@synthesize totalLength = _totalLength;
@synthesize isFile = _isFile;
@synthesize audioQueueIsRunning = _audioQueueIsRunning;
@dynamic bufferState;
@dynamic bufferError;
@dynamic audioState;
@dynamic audioError;
@dynamic bufferedLength;

- (id)init
{
    self = [super init];
    if (self) {
        self.state = SteamInitialized;
        self.bufferState = SteamBufferInitialized;
        _bufferError = SteamBufferErrorNone;
        self.audioState = SteamAudioInitialized;
        _audioError = SteamAudioErrorNone;
        
        self.bufferedLength = 0;
        self.totalLength = 0;
        self.isFile = NO;

        _bufferCondition = [[NSCondition alloc] init];
        [_bufferCondition setName:@"buffer condition"];
        _buffers = [[NSMutableArray alloc] initWithCapacity:64];
        
        _networkCondition = [[NSCondition alloc] init];
        [_networkCondition setName:@"network condition"];
        _networkThreadStarted = NO;
        
        _audioThreadCondition = [[NSCondition alloc] init];
        [_audioThreadCondition setName:@"audio thread condition"];
        _audioThreadStarted = NO;
        
        _audioQueueLock = [[NSLock alloc] init];
        [_audioQueueLock setName:@"audio queue lock"];
        
        _audioQueueBufferConditionLock = [[NSConditionLock alloc] initWithCondition:AUDIOQUEUE_BUFFER_CONDITION_HASSLOT];
        [_audioQueueBufferConditionLock setName:@"audioqueue buffer condition lock"];
        
        _currentPacket = 0;
        _audioQueueBufferUsedStartIndex = 0;
        _audioQueueBufferUsedNumber = 0;
    }
    return self;
}

- (id)initWithURL:(NSURL *)url
{
    self = [self init];
    if (self) {
        self.url = url;
        if ([self.url isFileURL]) {
            self.isFile = YES;
        }
    }
    return self;
}


- (void)dealloc
{
    [self stop];
    [self waitForStopping];
    [self freeAudioQueue];
    [_bufferCondition lock];
    RELEASE_SAFELY(_buffers);
    [_bufferCondition unlock];

#ifdef DEBUG
     //必须在此时已经结束
    [_networkCondition lock];
    assert(nil == _networkThread);
    [_networkCondition unlock];
    
#endif
    self.url = nil;
    RELEASE_SAFELY(_networkCondition);
    RELEASE_SAFELY(_bufferCondition);
    RELEASE_SAFELY(_audioQueueBufferConditionLock);
    RELEASE_SAFELY(_audioThreadCondition);
    
    @synchronized(self) {
        CFRELEASE_SAFELY(_networkRunLoopRef);
    }
    
#if NON_OBJC_ARC
    [super dealloc];
#endif
    STEAM_LOG(STEAM_DEBUG, @"dealloced");
}

- (void)setState:(SteamState)state
{
    @synchronized(self) {
        _state = state;
        [self postNotificationName:SteamStateChangedNotification];
    }
}

- (SteamState)state
{
    @synchronized(self) {
        return _state;
    }
}

- (void)prebuffer
{
    [self startBuffering];
}

- (void)play
{
    @synchronized(self) 
    {
        if (SteamInitialized == self.state
            || SteamPrebuffering == self.state) {
            [self prebuffer];
            self.state = SteamWorking;
            [self startAudio];
            
        }
        else if (SteamPaused == self.state) {
            self.state = SteamWorking;
            [self startAudio];
        }
    }
}

- (void)pause
{
    if (SteamWorking == self.state) {
        self.state = SteamPaused;
    }
}

- (void)stop
{
    @synchronized(self) {
        if (SteamStopped != self.state) {
            self.state = SteamStopping;
            STEAM_LOG(STEAM_DEBUG, @"stopping");
            [self stopBuffering];
            [self stopAudio];
        }
    }
}

- (void)stopAndWait
{
    @synchronized(self) {
        [self stop];
        [self waitForStopping];
    }
}

- (void)waitForStopping
{
    [self waitForBufferingStopped];
    [self waitForAudioStopped];
    
    self.state = SteamStopped;
    STEAM_LOG(STEAM_DEBUG, @"stopped");
}

- (NSTimeInterval)elapsedTime
{
    return [self audioElapsedTime];
}

- (NSTimeInterval)duration
{
    return [self audioDuration];
}

@end
