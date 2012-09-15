//
//  RackView.h
//  WordGame
//
//  Created by Brian Hammond on 6/26/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TileView.h"

@interface RackView : UIView <DraggableViewTouchDelegate>

- (id)initWithFrame:(CGRect)frame
            letters:(NSArray *)letters
       dragDelegate:(id<DraggableViewDragDelegate>)dragDelegate;

- (void)beginSelectionMode;
- (NSSet *)endSelectionMode;

- (void)popTilesIn;
- (void)popTilesOut;
- (void)hideTiles;

// indexBefore => indexAfter
- (void)slideTiles:(NSDictionary *)movements;

@end
