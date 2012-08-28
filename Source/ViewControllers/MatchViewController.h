//
//  MatchViewController.h
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "BaseViewController.h"
#import "MatchLogic.h"
#import "DraggableView.h"
#import "ChatViewController.h"

@interface MatchViewController : BaseViewController <MatchDelegate, DraggableViewDragDelegate, DraggableViewTouchDelegate, UIScrollViewDelegate, ChatViewControllerDelegate>

@property (nonatomic, assign) BOOL hasAcceptedChallenge;
@property (nonatomic, retain, readonly) Match *match;

+ (id)controllerWithMatch:(Match *)aMatch;
- (void)resign;

@end
