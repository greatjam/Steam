//
//  Steam+Private.m
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

#import "Steam+Private.h"

@implementation Steam (Private)

- (void)postNotificationName:(NSString *)name
{
    if ([NSThread isMainThread]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:nil];
    }
    else {
        [self performSelectorOnMainThread:@selector(postNotificationName:) withObject:name waitUntilDone:NO];
    }
}

#pragma mark - file type hint
+ (AudioFileTypeID)fileTypeFromContentType:(NSString *)contentType
{
    AudioFileTypeID fileType = kAudioFileMP3Type;
    if ([contentType isEqualToString:@"audio/mp3"]) {
        
    }
    else if([contentType isEqualToString:@"audio/mp4"]) {
        fileType = kAudioFileMPEG4Type;
    }
    else if([contentType isEqualToString:@"audio/aac"]) {
        fileType = kAudioFileAAC_ADTSType;
    }
        return fileType;
}

+ (AudioFileTypeID)fileTypeFromURL:(NSURL *)url
{
    AudioFileTypeID fileType = kAudioFileMP3Type;
    NSString * ext = [url pathExtension];
    if (0 == [ext compare:@"mp3" options:NSCaseInsensitiveSearch]) {
        
    }
    else if(0 == [ext compare:@"mp4" options:NSCaseInsensitiveSearch]){
        fileType = kAudioFileMPEG4Type;
    }
    else if(0 == [ext compare:@"aac" options:NSCaseInsensitiveSearch]){
        fileType = kAudioFileAAC_ADTSType;
    }
    
    return fileType;
}

@end
