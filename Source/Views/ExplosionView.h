//
//  ExplosionView.h
//  Word War III
//
//  Created by Brian Hammond on 7/20/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ExplosionView : UIView

- (void)useBombEmitter;
- (void)useStarEmitter;

- (void)explodeFromPoint:(CGPoint)point completion:(void(^)())completion;

@end
