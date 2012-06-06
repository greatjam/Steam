//
//  SteamHelper.h
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

#ifndef YPlayer_SteamHelper_h
#define YPlayer_SteamHelper_h

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#if __has_feature(objc_arc)
#define HAS_OBJC_ARC 1
#else
#define HAS_OBJC_ARC 0
#endif

#define NON_OBJC_ARC !HAS_OBJC_ARC

#define IS_INSTANCE_OF(_x, _class) ([_x isKindOfClass:[_class class]])
#define LOGSTATUS(xxx, ...) NSLog(@"%s(%d):"xxx, __PRETTY_FUNCTION__, __LINE__,##__VA_ARGS__)

#define DECLARE_NOTIFICATION(NOTE) extern NSString * const NOTE
#define IMPLEMENT_NOTIFICATION(NOTE) NSString * const NOTE = @#NOTE

#define INVALIDATE_TIMER(_x) if(_x){[(_x) invalidate];_x=nil;}

#define CFRELEASE_SAFELY(_x) if(_x){CFRelease(_x); _x=NULL;}

#if HAS_OBJC_ARC
#define RETAIN_STRONG strong
#define ASSIGN_WEAK weak
#define RELEASE_SAFELY(_x) if(_x){_x=nil;}
#else
#define RETAIN_STRONG retain
#define ASSIGN_WEAK assign
#define INVALIDATE_RELEASE_TIMER(_x) if(_x){[(_x) invalidate];[(_x) release];_x=nil;}
#define RELEASE_SAFELY(_x) if(_x){[(_x) release];_x=nil;}
#endif

#define STEAM_DEBUG 1
#define STEAM_DEBUG_AUDIO 1
#define STEAM_DEBUG_BUFFER 1

#if STEAM_DEBUG
#define STEAM_LOG(_type, __x, ...) if(_type){LOGSTATUS(__x, ##__VA_ARGS__);}
#else
#define STEAM_LOG(_type, __x, ...) ((void)0)
#endif

#endif
