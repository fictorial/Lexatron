//
//  TileView.h
//  Lexatron
//
//  Created by Brian Hammond on 8/7/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "DraggableView.h"

@class Letter;

@interface TileView : DraggableView

@property (nonatomic, copy) Letter *letter;
@property (nonatomic, assign) BOOL isNew;

+ (id)viewWithFrame:(CGRect)frame letter:(Letter *)letter;

- (void)configureForBoardDisplay;
- (void)configureForRackDisplayWithSize:(CGFloat)size;

@end
