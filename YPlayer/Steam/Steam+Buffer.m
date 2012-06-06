//
//  Steam+Buffer.m
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

#import "Steam+Buffer.h"
#import <CFNetwork/CFNetwork.h>
#import "Steam+Audio.h"
#import "SteamHelper.h"
#import "Steam+Private.h"

static const size_t MAX_BUFFER_SIZE = 64 * 1024;

void ReadStreamClientCallback(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo);

void ReadStreamClientCallback(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo)
{
    Steam * steam = (Steam *)clientCallBackInfo;
    assert(IS_INSTANCE_OF(steam, Steam));
    [steam handleReadStream:stream eventType:type];
}

@implementation Steam (Buffer)
@dynamic bufferState;
@dynamic bufferError;
@dynamic bufferedLength;

#pragma mark buffer state/error
- (void)setBufferState:(SteamBufferState)bufferState
{
    @synchronized(self) {
        _bufferState = bufferState;
        [self postNotificationName:SteamBufferStateChangedNotification];
    }
}

- (SteamBufferState)bufferState
{
    @synchronized(self) {
        return _bufferState;
    }
}

- (void)setBufferError:(SteamBufferError)bufferError
{
    @synchronized(self) {
        _bufferError = bufferError;
        self.bufferState = SteamBufferFailed;
    }
}

- (SteamBufferError)bufferError
{
    @synchronized(self) {
        return _bufferError;
    }
}

- (void)setBufferedLength:(NSUInteger)bufferedLength
{
    @synchronized(self) {
        _bufferedLength = bufferedLength;
        [self postNotificationName:SteamBufferedNotification];
    }
}

- (NSUInteger)bufferedLength
{
    @synchronized(self) {
        return _bufferedLength;
    }
}

- (void)startBuffering
{
    @synchronized(self) {
        [_networkCondition lock];
        if ((SteamStopping != self.state && SteamStopped != self.state)
            && SteamBufferInitialized == self.bufferState && NO == _networkThreadStarted) {
            self.bufferState = SteamBufferThreadStarted;
            _networkThreadStarted = YES;
            _networkThread = [[NSThread alloc] initWithTarget:self selector:@selector(bufferWorker:) object:nil];
            [_networkThread setName:@"networkThread"];
            [_networkThread start];
        }
        [_networkCondition unlock];
    }
}

- (void)stopBuffering
{
    [_bufferCondition lock];
    [_bufferCondition signal]; //防止线程阻塞
    [_bufferCondition unlock];
    
    @synchronized(self) {
        if (_networkRunLoopRef) {
            CFRunLoopStop(_networkRunLoopRef);
        }
        [_networkCondition lock];
        [_networkThread cancel];
        [_networkCondition unlock];
    }
}

- (BOOL)bufferThreadIsRunning
{
    BOOL running = NO;
    [_networkCondition lock];
    running = _networkThreadStarted;
    [_networkCondition unlock];
    return running;
}

- (BOOL)hasBuffers
{
    BOOL hasBuffers = NO;
    [_bufferCondition lock];
    hasBuffers = (0 != [_buffers count]);
    [_bufferCondition unlock];
    return hasBuffers;
}

- (void)waitForBufferingStopped
{
    STEAM_LOG(STEAM_DEBUG_BUFFER, @"waiting for buffering stopped");
    [_networkCondition lock];
    while (_networkThreadStarted) {
        [_networkCondition wait];
    }
    [_networkCondition unlock];
    
    STEAM_LOG(STEAM_DEBUG_BUFFER, @"buffering stopped");
}

- (BOOL)shouldStopBuffering
{
    @synchronized(self) {
        return (SteamStopping == _state
                || SteamBufferFinished == _bufferState
                || SteamBufferFailed == _bufferState);
    }
}

- (void)bufferWorker:(id)object
{
#if NON_OBJC_ARC
    [self retain];//防止被释放
#else
    Steam * SELF = self;
#endif
    @autoreleasepool {
        //如果状态不正确，立即退出线程
        if (SteamBufferThreadStarted == self.bufferState) {
            
            STEAM_LOG(STEAM_DEBUG_BUFFER, @"worker thread started: %@", self.url);
            NSThread * currentThread = [NSThread currentThread];
#if NON_OBJC_ARC
            [[currentThread retain] autorelease];
#endif
            for (int networkRetry = 0; networkRetry < 3 && !self.isFile; networkRetry ++) {
                @autoreleasepool {
                    [_bufferCondition lock];
                    if (0 == _bufferedLength) { //如果需要从头开始缓冲数据，则清除所有buffers
                        [_buffers removeAllObjects];
                    }
                    [_bufferCondition unlock];
                    
                    //如果在其他的线程中@synchronized()中又加了锁，则会被阻塞
                    //                pthread_mutex_lock(&_stream_mutex);
                    
                    CFReadStreamRef readStreamRef = [self scheduleNewReadStream];
                    
                    while (![currentThread isCancelled] 
                           && ![self shouldStopBuffering]) {
                        @autoreleasepool {
                            SInt32 status = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0f, FALSE);
                            switch (status) {
                                case kCFRunLoopRunFinished:
                                    break;
                                case kCFRunLoopRunStopped:
                                    break;
                                case kCFRunLoopRunTimedOut:
                                    break;
                                default:
                                    break;
                            }
                            [NSThread sleepForTimeInterval:0.1];
                        }
                    }
                    [self unscheduleAndCloseReadStream:readStreamRef];
                    readStreamRef = NULL;
                    
                    @synchronized(self) {
                        CFRELEASE_SAFELY(_httpHeaderRef);
                    }
                    
                    if (SteamBufferFinished == self.bufferState
                        || (SteamWorking != self.state && SteamPrebuffering != self.state)) {
#ifdef DEBUG
                        if (SteamBufferFinished == self.bufferState) {
                            LOGSTATUS(@"SteamBufferFinished");
                        }
                        else {
                            LOGSTATUS(@"Steam state:%d", self.bufferState);
                        }
#endif
                        break;
                    }
                    else {
                        STEAM_LOG(STEAM_DEBUG_BUFFER, @"network retry:%d time(s)", networkRetry);
                    }
                }//autoreleasepool
            }// for network retry
            
            [_networkCondition lock];
            _networkThreadStarted = NO;
            RELEASE_SAFELY(_networkThread);
            [_networkCondition signal];
            [_networkCondition unlock];
            STEAM_LOG(STEAM_DEBUG_BUFFER, @"worker thread exited (total size:%u)", _totalLength); 
        }//steam buffer thread started
    }//@autorelease
#if NON_OBJC_ARC
    [self release];
#endif
}

- (void)handleReadStream:(CFReadStreamRef)readStreamRef eventType:(CFStreamEventType)type
{
    static BOOL firstRun = YES;
    switch (type) {
        case kCFStreamEventOpenCompleted:
            self.bufferState = SteamBufferBuffering;
            firstRun = YES;
            break;
        case kCFStreamEventHasBytesAvailable:
        {            
            if (SteamWorking == self.state) {//防止停止之后，仍然在会读取新的数据
                if (firstRun) {
                    @synchronized(self) {
                        if (self.isFile) {
                            AudioFileTypeID typeID = kAudioFileMP3Type;
                            typeID = [Steam fileTypeFromURL:self.url];
                            [_audioFileTypeCondition lock];
                            _audioFileTypeHint = typeID;
                            [_audioFileTypeCondition signal];
                            [_audioFileTypeCondition unlock];
                        }
                        else if (!_httpHeaderRef) {
                            [self handleHTTPResponseHeaderFromReadStream:readStreamRef];
                        }
                    }
                    firstRun = NO;
                }
                
                [self fillBuffersFromReadStream:readStreamRef];
            }
        }
            break;
        case kCFStreamEventEndEncountered:
            self.bufferState = SteamBufferFinished;
            STEAM_LOG(STEAM_DEBUG_BUFFER, @"bufferFinished(%d/%d)", self.bufferedLength, self.totalLength);
            break;
        case kCFStreamEventErrorOccurred:
            @synchronized(self) {
                [self failedBufferingReadStream:readStreamRef WithError:SteamBufferErrorStreamErrorOccurred];
            }
            break;
        default:
            break;
    }
}

- (CFReadStreamRef)scheduleNewReadStream
{
    CFReadStreamRef readStreamRef = NULL; //CFNetwork对象
    @synchronized(self) { //可以防止self.url被修改
        
        if (self.isFile) {
            readStreamRef = CFReadStreamCreateWithFile(NULL, (CFURLRef)self.url);
            if (readStreamRef) {
                NSFileManager * mgr = [[NSFileManager alloc] init];
                NSDictionary * attrs = [mgr attributesOfItemAtPath:self.url.path error:nil];
                _totalLength = [attrs fileSize];
                self.bufferedLength = 0;
                RELEASE_SAFELY(mgr);
            }
        }
        else {
            CFURLRef urlRef = (CFURLRef)self.url;
            CFHTTPMessageRef httpMessageRef = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), urlRef, kCFHTTPVersion1_1);
            if (self.bufferedLength) {
                NSString * s = [NSString stringWithFormat:@"bytes=%u-", self.bufferedLength];
                CFHTTPMessageSetHeaderFieldValue(httpMessageRef, CFSTR("Range"), (CFStringRef)s);
            }
            readStreamRef = CFReadStreamCreateForHTTPRequest(NULL, httpMessageRef);
            CFRelease(httpMessageRef);
        }
    }
    if (readStreamRef) {
        CFOptionFlags flags = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable
        | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
        Boolean ret ;
        CFStreamClientContext context = {0};
        context.info = (void *)self;
        context.version = 0;
        ret = CFReadStreamSetClient(readStreamRef, flags, ReadStreamClientCallback, &context);
        if (TRUE == ret) {
            @synchronized(self) {
                _networkRunLoopRef = CFRunLoopGetCurrent();
                CFRetain(_networkRunLoopRef);
                CFReadStreamScheduleWithRunLoop(readStreamRef, _networkRunLoopRef, kCFRunLoopDefaultMode);
            }
            ret = CFReadStreamOpen(readStreamRef);
            if (TRUE == ret) {
                self.bufferState = SteamBufferOpened;
            }
            else {
                [self failedBufferingReadStream:readStreamRef WithError:SteamBufferErrorNotOpened];
            }
        }
        else {
            [self failedBufferingReadStream:readStreamRef WithError:SteamBufferErrorNotSetupReadStream];
        }
    }
    else {
        [self failedBufferingReadStream:readStreamRef WithError:SteamBufferErrorNotCreated];
    }
    return readStreamRef;
}

- (void)unscheduleAndCloseReadStream:(CFReadStreamRef)readStreamRef
{
    if (readStreamRef) {
        CFReadStreamUnscheduleFromRunLoop(readStreamRef, _networkRunLoopRef, kCFRunLoopDefaultMode);
        CFReadStreamSetClient(readStreamRef, 0, NULL, NULL);
        CFReadStreamClose(readStreamRef);
        CFRELEASE_SAFELY(readStreamRef);
    }
}

- (void)fillBuffersFromReadStream:(CFReadStreamRef)readStreamRef
{
    static UInt8 buffer[MAX_BUFFER_SIZE];
    CFIndex readLen = CFReadStreamRead(readStreamRef, buffer, MAX_BUFFER_SIZE);
    if (readLen) {
        [_bufferCondition lock];
        
        if (self.isFile) {
            //对于文件读取，不希望过多占用内存
            while (SteamWorking == self.state
                   && SteamBufferBuffering == self.bufferState
                   && 2 == [_buffers count]) {
                [_bufferCondition wait];
            }
        }
        NSUInteger bufferedLen = self.bufferedLength;
        bufferedLen += readLen;
        self.bufferedLength = bufferedLen;
        
        NSUInteger bufIndex = [_buffers count];
        NSMutableData * data;
        if (bufIndex > 0) {
            bufIndex --;
            data = [_buffers objectAtIndex:bufIndex];
            size_t len1 = MAX_BUFFER_SIZE - [data length];
            if (len1) {
                [data appendBytes:buffer length:MIN(len1, readLen)];
            }
            if (len1 < readLen) {
                size_t len2 = readLen - len1;
                if (len2) {
                    data = [NSMutableData dataWithBytes:(buffer + len1) length:len2];
                    [_buffers addObject:data];
                }
            }
        }
        else {
            data = [NSMutableData dataWithBytes:buffer length:readLen];
            [_buffers addObject:data];
        }
        
        [_bufferCondition unlock];
    }
}

- (NSUInteger)readBuffer:(const void *)buffer bufferSize:(const NSUInteger)bufferSize
{
    /*UInt8 * readBuffer = (UInt8 *)buffer;
    NSUInteger len = 0;
    NSData * data = nil;
    [_bufferCondition lock];
    if ([_buffers count]) {
        data = [_buffers objectAtIndex:0];
        len = [data length];
        [data getBytes:readBuffer length:len];
        [_buffers removeObjectAtIndex:0];
    }
    [_bufferCondition unlock];
    return len;*/
    
    NSUInteger readSize = 0;
    if (buffer) {
        UInt8 * readBuffer = (UInt8 *)buffer;
        //如果网络缓慢，会导致函数空转，应该想办法阻塞住
        while (readSize < bufferSize) {
            NSUInteger count = 0;
            [_bufferCondition lock]; //将现有的缓存或最大bufferSize的缓存读出
            count = [_buffers count];
            while (readSize < bufferSize && count) {
                NSData * data = [_buffers objectAtIndex:0];
                NSUInteger dataLen = [data length];
                NSUInteger leftSize = bufferSize - readSize;
                if (dataLen <= leftSize) {//将data全部填充到buffer中
                    [data getBytes:readBuffer+readSize length:dataLen];
                    [_buffers removeObjectAtIndex:0];
                    readSize += dataLen;
                }
                else {//将data部分填充到buffer中
                    [data getBytes:readBuffer+readSize length:leftSize];
                    UInt8 * bytes = (UInt8*)data.bytes + leftSize;
                    NSMutableData * newData = [NSMutableData dataWithBytes:bytes length:dataLen - leftSize];
                    [_buffers replaceObjectAtIndex:0 withObject:newData];
                    readSize += leftSize;
                }
                if (self.isFile) { //对于本地文件读取，为了减少对内存的占用，只有得到信号，才会读取下一部分
                    [_bufferCondition signal];
                }
                
                count = [_buffers count];
            }
            [_bufferCondition unlock];
            if (!count) {
                if ([self bufferThreadIsRunning]) {
                    [NSThread sleepForTimeInterval:0.5];
                }
                else {
                    break;
                }
            }
        }
    }
    return readSize;
}

- (void)handleHTTPResponseHeaderFromReadStream:(CFReadStreamRef)readStreamRef
{
    @synchronized(self) {
        if (NULL == _httpHeaderRef) {
            _httpHeaderRef = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStreamRef, kCFStreamPropertyHTTPResponseHeader);
            UInt32 statusCode = CFHTTPMessageGetResponseStatusCode(_httpHeaderRef);
            if (200 == statusCode || 206 == statusCode) {
                CFStringRef string = CFHTTPMessageCopyHeaderFieldValue(_httpHeaderRef, CFSTR("Content-Length"));
                if (string) {
                    SInt32 contentLength = CFStringGetIntValue(string);
                    CFRELEASE_SAFELY(string);
                    _totalLength = contentLength;
                }
                
                string = CFHTTPMessageCopyHeaderFieldValue(_httpHeaderRef, CFSTR("Content-Type"));
                AudioFileTypeID typeID = kAudioFileMP3Type;
                if (string) {
                    NSString * nsString = (NSString *)string;
                    typeID = [Steam fileTypeFromContentType:nsString];
                }
                else {
                    typeID = [Steam fileTypeFromURL:self.url];
                }
                [_audioFileTypeCondition lock];
                _audioFileTypeHint = typeID;
                [_audioFileTypeCondition signal];
                [_audioFileTypeCondition unlock];
                CFRELEASE_SAFELY(string);
            }
            else {
                [self failedBufferingReadStream:readStreamRef WithError:SteamBufferErrorHTTPStatusNotSucceeded];
            }
        }
    }
}

- (void)failedBufferingReadStream:(CFReadStreamRef)readStreamRef WithError:(SteamBufferError)error
{
    @synchronized(self) {
        assert(SteamBufferErrorNone != error);
        self.bufferError = error;
        
        switch (error) {
            case SteamBufferErrorNotOpened:
                LOGSTATUS(@"CFReadStreamOpen failed");
                break;
            case SteamBufferErrorNotCreated:
                LOGSTATUS(@"CFReadStreamCreate failed:%@", self.url);
                break;
            case SteamBufferErrorNotSetupReadStream:
                LOGSTATUS(@"CFReadStreamSetClient failed");
                break;
            case SteamBufferErrorHTTPStatusNotSucceeded:
                @synchronized(self) {
                    if (_httpHeaderRef) {
                        CFStringRef myStatusLine = CFHTTPMessageCopyResponseStatusLine(_httpHeaderRef);
                        UInt32 code = CFHTTPMessageGetResponseStatusCode(_httpHeaderRef);
                        LOGSTATUS(@"HTTPResponse:%lu %@", code, (NSString *)myStatusLine);
                        CFRELEASE_SAFELY(myStatusLine);
                    }
                    else {
                        LOGSTATUS(@"HTTP response is not 200 or 206");
                    }
                }
                break;
            case SteamBufferErrorStreamErrorOccurred:
            {
                CFErrorRef errorRef = NULL;
                if (readStreamRef) {
                    errorRef = CFReadStreamCopyError(readStreamRef);
                }
                NSError * error = (NSError *)errorRef;
                STEAM_LOG(STEAM_DEBUG_BUFFER, @"bufferFailed:%@", [error description]);
                CFRELEASE_SAFELY(errorRef);
            }
            default:
                break;
        }
    }
}

@end
