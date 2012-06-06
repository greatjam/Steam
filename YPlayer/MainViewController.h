//
//  MainViewController.h
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

#import <UIKit/UIKit.h>
#import "Steam.h"

@interface MainViewController : UIViewController
{
    NSMutableArray * _songs;
    Steam * _steam;
}
@property (retain, nonatomic) IBOutlet UILabel *playtime;
@property (retain, nonatomic) IBOutlet UIProgressView *playProgress;
@property (retain, nonatomic) IBOutlet UIProgressView *bufferProgress;
@property (retain, nonatomic) IBOutlet UIButton *playButton;

@end
