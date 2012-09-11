//
//  BoardView.h
//  Lexatron
//
//  Created by Brian Hammond on 8/7/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import <UIKit/UIKit.h>

// Exists separate from BoardScrollView to handle touches.
// It is recommended by Apple to put touch handling not in a UIScrollView subclass but in a
// subview parented by the UIScrollView.

@interface BoardView : UIView

@property (nonatomic, strong) UIImageView *imageView;

+ (void)convertPDFs;
- (id)initWithContainerSize:(CGSize)size;
- (CGRect)boardFromCellX:(CGFloat)x y:(CGFloat)y;  // frame for board cell (x,y)
- (CGPoint)boardToCell:(CGPoint)point;             // (x,y) of board cell at point
- (void)willZoomIn;
- (void)didZoomOut;

- (void)updateTilesRemainingLabelFromMatch:(Match *)match;

@end

