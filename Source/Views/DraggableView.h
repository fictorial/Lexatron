//
//  DraggableView.h
//  WordGame
//
//  Created by Brian Hammond on 7/17/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DraggableView;

@protocol DraggableViewDragDelegate <NSObject>

// Return NO if the view should not begin dragging.
- (BOOL)draggableViewCanBeDragged:(DraggableView *)draggableView;

- (void)draggableViewDidStartDragging:(DraggableView *)draggableView;
- (void)draggableViewIsBeingDragged:(DraggableView *)draggableView currentPoint:(CGPoint)point;

// Return NO if not allowed to be dropped there; reverts to start frame.
- (BOOL)draggableView:(DraggableView *)draggableView wasDroppedAtPoint:(CGPoint)point;

- (void)draggableViewTouchesWereCanceled:(DraggableView *)draggableView;
@end

@protocol DraggableViewTouchDelegate <NSObject>
- (void)draggableViewWasTouched:(DraggableView *)draggableView;
@end

@interface DraggableView : UIView

// View is draggable when draggable==YES and -draggableViewCanBeDragged: returns YES.
// Default: YES

@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, strong, readonly) DraggableView *dragProxy;

@property (nonatomic, weak) id<DraggableViewDragDelegate> dragDelegate;
@property (nonatomic, weak) id<DraggableViewTouchDelegate> touchDelegate;

+ (id)viewWithFrame:(CGRect)frame;

// Some views clip to their bounds. If a DraggableView that is a 
// subview of such a view is dragged, it will effectively be disabled from dragging outside 
// the (clipped) bounds.  In this case, you should you ask for a drag proxy in 
// -draggableViewDidStartDragging:. The proxy is added to the given target view so that
// it can be dragged outside of the clipped bounds of the original draggable view's superview.
// That is, after creating a proxy view, any touch events on the proxy are funneled back
// through the original DraggableView and onto its dragDelegate.

- (void)makeProxyForDraggingInView:(UIView *)targetView;

// For subclasses to override.

- (DraggableView *)makeDragProxyWithFrame:(CGRect)frame;

@end
