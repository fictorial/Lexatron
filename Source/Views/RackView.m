//
//  RackView.m
//  WordGame
//
//  Created by Brian Hammond on 6/26/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "RackView.h"
#import "MatchLogic.h"
#import "TileView.h"

enum {
  kModeNormal,
  kModeSelection
};

@interface RackView ()
@property (nonatomic, assign) int mode;
@property (nonatomic, strong) NSMutableSet *selectedLetters;  // of NSNumber(index)
@end

@implementation RackView {
  int _cellSize;
}

- (CGRect)frameForCellAtIndex:(int)index {
  return CGRectMake(0.5 + index * _cellSize + index * SCALED(1), 0, _cellSize, _cellSize);
}

- (id)initWithFrame:(CGRect)frame
            letters:(NSArray *)letters
       dragDelegate:(id<DraggableViewDragDelegate>)dragDelegate {
  
  NSParameterAssert(letters.count == kRackTileCount);

  self = [super initWithFrame:frame];

  if (self) {
    _cellSize = (CGRectGetWidth(self.bounds) - (kRackTileCount - 1) * SCALED(1)) / kRackTileCount;

    for (int i=0; i < kRackTileCount; ++i) {
      id letter = [letters objectAtIndex:i];

      if (letter == [NSNull null])
        continue;

      TileView *tileView = [[TileView alloc] initWithFrame:[self frameForCellAtIndex:i]];
      tileView.letter = letter;
      tileView.letter.rackIndex = i;
      tileView.userInteractionEnabled = YES;
      tileView.draggable = YES;
      tileView.dragDelegate = dragDelegate;
      tileView.touchDelegate = self;
      [tileView configureForRackDisplayWithSize:_cellSize];
      [self addSubview:tileView];
    }

    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1];
    self.layer.cornerRadius = SCALED(5);
  }

  return self;
}

- (TileView *)viewForSlot:(int)index {
  NSAssert1(index >= 0 && index < kRackTileCount, @"invalid rack index; %d", index);
  
  // Yes, we could use .tag but this is less error prone.
  
  for (UIView *subview in self.subviews) {
    if ([subview isKindOfClass:[TileView class]]) {
      TileView *tileView = (TileView *)subview;
      if (tileView.letter.rackIndex == index)
        return tileView;
    }
  }
  
  return nil;
}

- (void)beginSelectionMode {
  _mode = kModeSelection;
  _selectedLetters = [NSMutableSet setWithCapacity:kRackTileCount];

  for (int i=0; i<kRackTileCount; ++i) {
    TileView *tileView = [self viewForSlot:i];
    tileView.draggable = NO;
    [tileView.layer removeAllAnimations];
  }

  // Make it a bit more obvious that the letters should be selected.
  
  [UIView animateWithDuration:0.3 animations:^{
    self.transform = CGAffineTransformMakeScale(1.1, 1.1);
  }];
}

- (void)draggableViewWasTouched:(DraggableView *)draggableView {
  BOOL isTile = ([draggableView isKindOfClass:[TileView class]]);
  
  if (!isTile)
    return;
  
  if (_mode != kModeSelection)
    return;

  TileView *tileView = (TileView *)draggableView;

  NSNumber *member = @(tileView.letter.rackIndex);
  
  if ([_selectedLetters member:member]) {
    [_selectedLetters removeObject:member];
    [self makeTileViewUnselected:tileView];
  } else { 
    [_selectedLetters addObject:member];
    [self makeTileViewSelected:tileView];
  }
  
  DLog(@"rack tile touched in selection mode: selected=%@", _selectedLetters);
}

- (void)makeTileViewSelected:(TileView *)tileView {
  [tileView.layer removeAllAnimations];
  [tileView.layer addAnimation:[self shakeAnimation] forKey:@"shake"];
  
  [UIView animateWithDuration:0.2 animations:^{
    tileView.alpha = 0.6;
    tileView.layer.borderColor = [[UIColor redColor] colorWithAlphaComponent:0.6].CGColor;
    tileView.layer.borderWidth = 2;
  }];
}

- (void)makeTileViewUnselected:(TileView *)tileView {
  [tileView.layer removeAllAnimations];
  
  tileView.transform = CGAffineTransformIdentity;

  [UIView animateWithDuration:0.2 animations:^{
    tileView.alpha = 1;
    tileView.layer.borderWidth = 0;
  }];
}

- (NSSet *)endSelectionMode {
  _mode = kModeNormal;

  for (int i=0; i<kRackTileCount; ++i) {
    TileView *tileView = [self viewForSlot:i];
    tileView.draggable = YES;
    [self makeTileViewUnselected:tileView];
  }

  [UIView animateWithDuration:0.3 animations:^{
    self.transform = CGAffineTransformIdentity;
  }];

  return [_selectedLetters copy];
}

- (CAAnimation *)shakeAnimation {
  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
  animation.fromValue = [NSValue valueWithCATransform3D:CATransform3DMakeRotation(-10 * M_PI/180.0, 0, 0, 1.0)];
  animation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeRotation(10 * M_PI/180.0, 0, 0, 1.0)];
  animation.autoreverses = YES;  
  animation.duration = 0.5;  
  animation.repeatCount = HUGE_VALF;  
  return animation;
}

- (void)popTilesIn {
  for (int i = 0; i < kRackTileCount; ++i) {
    [self viewForSlot:i].hidden = YES;

    int index = i;
    [self performBlock:^(id sender) {
      [[self viewForSlot:index] backInFrom:kFTAnimationBottom withFade:YES duration:0.5 delegate:nil];
    } afterDelay:i*0.075];
  }
}

- (void)popTilesOut {
  for (int i = 0; i < kRackTileCount; ++i) {
    int index = i;
    [self performBlock:^(id sender) {
      [[self viewForSlot:index] backOutTo:kFTAnimationBottom withFade:YES duration:0.5 delegate:nil];
    } afterDelay:i*0.075];
  }
}

- (void)hideTiles {
  for (int i = 0; i < kRackTileCount; ++i) {
    [[self viewForSlot:i] setHidden:YES];
  }
}

- (void)slideTiles:(NSDictionary *)movements completion:(void (^)(void))completion {
  __weak id weakSelf = self;

  [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
    [movements each:^(id key, id obj) {
      int fromIndex = [key intValue];
      int toIndex = [obj intValue];
      DLog(@"Slide tile from index %d to %d", fromIndex, toIndex);

      TileView *tileView = [weakSelf tileAtSlot:fromIndex];
      if (tileView) {
        tileView.alpha = 1;
        tileView.frame = [weakSelf frameForCellAtIndex:toIndex];
      }
    }];
  } completion:^(BOOL finished) {
    completion();
  }];
}

- (TileView *)tileAtSlot:(int)slot {
  for (id subview in self.subviews) {
    if ([subview isKindOfClass:TileView.class]) {
      TileView *tileView = (TileView *)subview;
      if (tileView.letter.rackIndex == slot)
        return tileView;
    }
  }
  return nil;
}

@end
