//
//  Steam+Audio.h
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

#import "Steam.h"

#define AUDIOQUEUE_BUFFER_CONDITION_HASSLOT 1
#define AUDIOQUEUE_BUFFER_CONDITION_FULL  -1

@interface Steam (Audio)
@property (atomic, readwrite, assign) SteamAudioState audioState;
@property (atomic, readwrite, assign) SteamAudioError audioError;
@property (atomic, readwrite, assign) BOOL audioQueueIsRunning;

- (void)startAudio;
- (void)stopAudio;
- (void)resetAudio;
- (void)signalAudioFileType;
- (void)freeAudioQueue;
- (void)waitForAudioStopped;
- (NSTimeInterval)audioElapsedTime;
- (NSTimeInterval)audioDuration;
- (void)audioWorkerThread:(id)object;

- (void)handleAudioFileStreamPacketsNumberBytes:(UInt32) inNumberBytes 
                                  numberPackets:(UInt32)inNumberPackets
                                      inputData:(const void *)inputData
                              packetDescription:(AudioStreamPacketDescription *)packetDescripton;
- (void)handleAudioFileStream:(AudioFileStreamID)audioFileStream 
                     property:(AudioFileStreamPropertyID)propertyID 
                        flags:(UInt32 *)ioFlags;
- (void)handleAudioQueue:(AudioQueueRef)inAQ completedBuffer:(AudioQueueBufferRef)aqBuffer;
- (void)handleAudioQueue:(AudioQueueRef)inAQ property:(AudioQueuePropertyID)property;

- (void)audioQueue:(AudioQueueRef)audioQueue failedWithOSStatus:(OSStatus)status as:(NSString *)as;
- (void)audioFileStream:(AudioFileStreamID)audioFileStream failedWithOSStatus:(OSStatus)err as:(NSString *)as;
- (void)failedWithSteamAudioError:(SteamAudioError)error;
@end
