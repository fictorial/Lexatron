//
//  DraggableView.m
//  WordGame
//
//  Created by Brian Hammond on 7/17/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "DraggableView.h"

@interface DraggableView ()
@property (nonatomic, assign) CGRect startFrame;
@property (nonatomic, strong, readwrite) DraggableView *dragProxy;
@end

@implementation DraggableView

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  
  if (self) {
    self.userInteractionEnabled = YES;
    self.multipleTouchEnabled = NO;
    self.exclusiveTouch = YES;

    self.startFrame = self.frame;
    self.draggable = YES;
  }

  return self;
}

+ (id)viewWithFrame:(CGRect)frame {
  return [[DraggableView alloc] initWithFrame:frame];
}

- (BOOL)canBeDragged {
  return _draggable && [_dragDelegate draggableViewCanBeDragged:self]; 
}

- (DraggableView *)viewForDragging {
  return _dragProxy ? _dragProxy : self;
}

- (void)makeProxyForDraggingInView:(UIView *)targetView {

  // Dragging means moving a view around in its superview's coordinate space.

  CGRect frame = [self.superview convertRect:self.frame toView:targetView.superview];

  self.dragProxy = [self makeDragProxyWithFrame:frame];

  _dragProxy.dragDelegate = _dragDelegate;
  _dragProxy.startFrame = _startFrame;

  _dragProxy.layer.shadowColor = [UIColor blackColor].CGColor;
  _dragProxy.layer.shadowOffset = CGSizeZero;
  _dragProxy.layer.shadowOpacity = 0.2;
  _dragProxy.layer.shadowRadius = 2;

  // Let user see through it to route to a drop area.

  _dragProxy.alpha = 0.7;

  // We don't want to remove this view from its parent since we'd no longer get touch events
  // and would thus be unable to move our proxy around.

  self.alpha = 0.01;

  [targetView addSubview:_dragProxy];

  // Scale it up a bit so it can be seen under the user's fat finger.
  
  [UIView animateWithDuration:0.2 delay:0 options:0 animations:^{
    CGRect frame = _dragProxy.frame;

    float scale = 1.6;

    frame.size.width *= scale;
    frame.size.height *= scale;

    frame.origin.x -= frame.size.width/scale;
    frame.origin.y -= frame.size.height/scale;
    
    _dragProxy.frame = frame;
  } completion:^(BOOL finished) {
  }];
}

- (DraggableView *)makeDragProxyWithFrame:(CGRect)frame {
  DLog(@"override me!");
  return nil;
}

- (void)moveToTouch:(UITouch *)touch {
  UIView *dragView = [self viewForDragging];

  dragView.center = [touch locationInView:[self viewForDragging].superview];
  dragView.center = CGPointMake(dragView.center.x, dragView.center.y - kDragProxyFingerOffset);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {  
  if ([self canBeDragged]) {
    DLog(@"draggable view can be dragged");
    [_dragDelegate draggableViewDidStartDragging:self];
    [self moveToTouch:[touches anyObject]];
  } else {
    DLog(@"draggable view cannot be dragged");
    [_touchDelegate draggableViewWasTouched:self];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  if (![self canBeDragged])
    return;
  
  [self moveToTouch:[touches anyObject]];
  [_dragDelegate draggableViewIsBeingDragged:self currentPoint:[self viewForDragging].center];
}

- (void)clearDragProxy {
  if (_dragProxy) {
    [_dragProxy removeFromSuperview];
    _dragProxy = nil;
  }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  if (![self canBeDragged])
    return;

  [_dragDelegate draggableViewTouchesWereCanceled:self];

  [self clearDragProxy];
  self.hidden = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  if (![self canBeDragged])
    return;
  
  [self moveToTouch:[touches anyObject]];

  BOOL allowDrop = [_dragDelegate draggableView:self wasDroppedAtPoint:[self viewForDragging].center];
  if (!allowDrop) {
    DLog(@"drop not allowed at current point; reverting back to start frame.");
    [self viewForDragging].frame = [self viewForDragging].startFrame;
  }
  
  self.hidden = NO;
  [self clearDragProxy];
}

@end
