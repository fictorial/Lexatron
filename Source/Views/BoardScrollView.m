//
//  BoardScrollView.m
//  Lexatron
//
//  Created by Brian Hammond on 8/7/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "BoardScrollView.h"
#import "BoardView.h"
#import "TileView.h"
#import "UIView-GeomHelpers.h"

@implementation BoardScrollView

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];

  // Allow us to determine if the user wants to drag a tile around or if they want to scroll.
  self.delaysContentTouches = NO;
  self.canCancelContentTouches = YES;

  self.minimumZoomScale = 1.0;
  self.maximumZoomScale = kBoardMaxZoomScale;

  self.userInteractionEnabled = YES;
  self.scrollEnabled = YES;

  self.bounces = YES;
  self.bouncesZoom = YES;

  self.showsVerticalScrollIndicator = NO;
  self.showsHorizontalScrollIndicator = NO;

  _boardView = [[BoardView alloc] initWithContainerSize:frame.size];
  [self addSubview:_boardView];
  _boardView.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);

  [self setupZooming];

  return self;
}

#pragma mark - dragging

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
  if ([view isKindOfClass:[TileView class]]) {
    TileView *tileView = (TileView *)view;
    return ![tileView.dragDelegate draggableViewCanBeDragged:tileView];
  }

  return YES;  // Go ahead and scroll the view.
}

#pragma mark - zooming

// Double-tap to zoom in/out (pinch is built-in).

- (void)setupZooming {
  UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewDoubleTapped:)];
  doubleTapRecognizer.numberOfTapsRequired = 2;
  doubleTapRecognizer.numberOfTouchesRequired = 1;
  [self addGestureRecognizer:doubleTapRecognizer];
}

- (void)scrollViewDoubleTapped:(UITapGestureRecognizer *)recognizer {
  if (self.zoomScale > self.minimumZoomScale) {
    [self zoomOut];
  } else {
    CGPoint pointInView = [recognizer locationInView:self.boardView];
    [self zoomToFocusOnPoint:pointInView];
  }
}

- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated {
  if (rect.size.width == 0 || rect.size.height == 0) {
    [self zoomOut];
  } else {
    [self onZoomIn];

    if (rect.origin.x < kTileWidth/2 && rect.origin.x > -kTileWidth/2)
      rect.origin.x = 0;

    if (rect.origin.y < kTileHeight/2 && rect.origin.y > -kTileHeight/2)
      rect.origin.y = 0;

    DLog(@"zoom to rect: %@", NSStringFromCGRect(rect));

    [super zoomToRect:rect animated:animated];
  }
}

- (void)zoomToFocusOnPoint:(CGPoint)point {
  [self onZoomIn];

  DLog(@"zoom to point: %@", NSStringFromCGPoint(point));

  CGFloat newZoomScale = self.maximumZoomScale;
  CGSize scrollViewSize = self.bounds.size;

  CGFloat w = scrollViewSize.width / newZoomScale;
  CGFloat h = scrollViewSize.height / newZoomScale;
  CGFloat x = point.x - (w / 2.0f);
  CGFloat y = point.y - (h / 2.0f);

  CGRect zoomRect = CGRectMake(x, y, w, h);
  [self zoomToRect:zoomRect animated:YES];
}

- (void)zoomOut {
  DLog(@"zoom out");

  [UIView animateWithDuration:0.4 animations:^{
    self.zoomScale = self.minimumZoomScale;
    [self zoomToRect:self.bounds animated:NO];
  } completion:^(BOOL finished) {
    [self onZoomOut];
  }];
}

- (void)onZoomIn {
  [_boardView willZoomIn];
}

- (void)onZoomOut {
  [_boardView didZoomOut];
}

@end
