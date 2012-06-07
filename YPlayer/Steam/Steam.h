//
//  Steam.h
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

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef enum SteamState {
    SteamInitialized = 0,
    SteamPrebuffering, //开始预缓冲，但未开始播放
    SteamWorking, //正在工作，播放，或者在准备播放但在缓冲
    SteamPaused,
    SteamStopping,     //正在停止，等待所有状态、线程结束
    SteamStopped,
}SteamState;

typedef enum SteamBufferState {
    SteamBufferInitialized = 0,
    SteamBufferThreadStarted,
    SteamBufferOpened,
    SteamBufferBuffering,       //开始缓冲
    SteamBufferFinished,        //缓冲下载完成
    SteamBufferFailed,
}SteamBufferState;

typedef enum SteamBufferError {
    SteamBufferErrorNone = 0,
    SteamBufferErrorNotCreated,
    SteamBufferErrorNotSetupReadStream,
    SteamBufferErrorNotOpened,
    SteamBufferErrorNotOpenCompleted,
    SteamBufferErrorHTTPStatusNotSucceeded,
    SteamBufferErrorStreamErrorOccurred,
    SteamBufferErrorHttpRangeRequestNotSupported,
    SteamBufferErrorUnknown,
}SteamBufferError;

typedef enum SteamAudioState {
    SteamAudioInitialized = 0,
    SteamAudioThreadStarted,
    SteamAudioRunning,
    SteamAudioPaused,
    SteamAudioInterrupted,
    SteamAudioStopped,
    SteamAudioFailed,
}SteamAudioState;

typedef enum SteamAudioError {
    SteamAudioErrorNone,
    SteamAudioErrorInsufficientMemory,
}SteamAudioError;

extern NSString * const SteamStateChangedNotification;
extern NSString * const SteamBufferStateChangedNotification;
extern NSString * const SteamBufferedNotification;
extern NSString * const SteamAudioStateChangedNotification;


static const int kAudioQueueBuffersNum = 3;

@interface Steam : NSObject
{
    SteamState _state;
    NSURL * _url;
    BOOL _isFile;
    //播放线程
    
    //音频缓冲数据
    NSCondition * _bufferCondition;
    SteamBufferState _bufferState;
    SteamBufferError _bufferError;
    NSMutableArray * _buffers; //用于在内存中保存缓存的音频数据
    NSUInteger _bufferedLength;
    NSUInteger _totalLength;
    
    //网络数据
    NSCondition * _networkCondition;//用于等待线程退出
    CFRunLoopRef _networkRunLoopRef;
    NSThread * _networkThread;
    BOOL _networkThreadStarted; //不使用_networkThread，是因为在ARC下，不应判断_networkThread值
    
    CFHTTPMessageRef _httpHeaderRef;
    
    
    //AudioFileStream
    AudioFileTypeID _audioFileTypeHint; //未能解析使用0, 解析但失败使用1
    NSCondition * _audioFileTypeCondition;
    
    //音频播放
    NSThread * _audioThread;
    NSCondition * _audioThreadCondition; //用于等待线程退出
    BOOL _audioThreadStarted;
    SteamAudioState _audioState;
    SteamAudioError _audioError;
    
    //AudioQueue结构
    NSLock * _audioQueueLock;
    AudioQueueRef _audioQueueRef;
    BOOL _audioQueueIsRunning;
    
    AudioStreamBasicDescription _audioFormat;
    
    NSConditionLock * _audioQueueBufferConditionLock;
    AudioQueueBufferRef *_audioQueueBuffers;
    UInt32 _audioQueueBuffersNum;
    UInt32 _audioQueueBufferUsedStartIndex;
    UInt32 _audioQueueBufferUsedNumber;
}

@property (atomic, readonly, assign) SteamState state;
@property (atomic, readonly, assign) SteamBufferState bufferState;
@property (atomic, readonly, assign) SteamBufferError bufferError;
@property (atomic, readonly, assign) SteamAudioState audioState;
@property (atomic, readonly, assign) SteamAudioError audioError;
@property (atomic, readonly, retain) NSURL * url;
@property (atomic, readonly, assign) NSUInteger bufferedLength;
@property (atomic, readonly, assign) NSUInteger totalLength;
@property (atomic, readonly, assign) BOOL isFile;
@property (atomic, readonly, assign) BOOL audioQueueIsRunning;
- (id)initWithURL:(NSURL *)url;
- (void)stop;
- (void)pause;
- (void)play;
- (void)prebuffer; //在开始电台之前，预先加载缓冲音频数据
- (void)waitForStopping;
- (NSTimeInterval)elapsedTime;
- (NSTimeInterval)duration;
@end
