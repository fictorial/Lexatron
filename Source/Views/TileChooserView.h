//
//  TileChooserView.h
//  WordGame
//
//  Created by Brian Hammond on 7/8/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^TileChooserCallback)(int letter);

@interface TileChooserView : UIImageView

+ (id)view;

@property (nonatomic, copy) TileChooserCallback callback;

@end
