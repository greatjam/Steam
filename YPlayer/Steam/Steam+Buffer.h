//
//  Steam+Buffer.h
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

@interface Steam (Buffer)
@property (atomic, readwrite, assign) SteamBufferState bufferState;
@property (atomic, readwrite, assign) SteamBufferError bufferError;
@property (atomic, readwrite, assign) NSUInteger bufferedLength;

- (void)bufferWorker:(id)object;
- (void)handleReadStream:(CFReadStreamRef)readStream eventType:(CFStreamEventType)type;
- (void)failedBufferingReadStream:(CFReadStreamRef)readStreamRef WithError:(SteamBufferError)error;
- (BOOL)shouldStopBuffering;
- (void)stopBuffering;
- (void)startBuffering;
- (BOOL)bufferThreadIsRunning;
- (void)waitForBufferingStopped;
- (CFReadStreamRef)scheduleNewReadStream;
- (void)unscheduleAndCloseReadStream:(CFReadStreamRef)readStreamRef;
- (void)fillBuffersFromReadStream:(CFReadStreamRef)readStreamRef;
- (void)handleHTTPResponseHeaderFromReadStream:(CFReadStreamRef)readStreamRef;
- (NSUInteger)readBuffer:(const void *)buffer bufferSize:(const NSUInteger)bufferSize;
@end
