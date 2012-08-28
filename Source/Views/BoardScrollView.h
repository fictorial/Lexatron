//
//  BoardScrollView.h
//  Lexatron
//
//  Created by Brian Hammond on 8/7/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BoardView;

// Why do we have a subclass of UIScrollView?
//
// A scrollview determines if the user would like to scroll the scrollview or
// interact with content therein by intercepting touches and waiting ~150ms to
// see if the finger moved far enough away to indicate a scroll intention. If
// scrolling is determined to be the intent, the original content touch is
// canceled. This is the behavior if delaysContentTouches=YES and
// canCancelContentTouches=YES and touchesShouldCancelInContentView returns YES
// which it does by default.
//
// We'd like to add a check that disables the cancelling of a touch and
// enforcing that scrolling of the scrollview was _not_ the intent when the user
// touches a board item that is draggable (e.g. a letter placed in the current
// turn). Otherwise, scroll away! Thus, we want delaysContentTouches=NO and
// canCancelContentTouches=YES and perform this check in
// touchesShouldCancelInContentView returning NO if the item is to be dragged or
// YES if the scrollview is to be scrolled.

@interface BoardScrollView : UIScrollView

@property (nonatomic, strong) BoardView *boardView;

- (void)zoomToFocusOnPoint:(CGPoint)point;
- (void)zoomOut;

- (void)onZoomIn;
- (void)onZoomOut;

@end
