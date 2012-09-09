//
//  TileChooserView.m
//  WordGame
//
//  Created by Brian Hammond on 7/8/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "TileChooserView.h"

@implementation TileChooserView

+ (id)view {
  return [[TileChooserView alloc] initWithImage:[UIImage imageWithName:@"BlankChooser"]];
}

- (id)initWithImage:(UIImage *)image {
  self = [super initWithImage:image];
  
  if (self) {
    self.userInteractionEnabled = YES;
    self.multipleTouchEnabled = NO;

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 3);
    self.layer.shadowOpacity = 0.7;
    self.layer.shadowRadius = 8;
  }
  
  return self;
}

// Asset layout is:
// ABCDEF
// GHIJKL
// MNOPQR
// STUVWX
// YZ

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  UITouch *touch = [touches anyObject];
  CGPoint touchPoint = [touch locationInView:self];
  
  int cellsPerRow = 6;
  int cellSize = self.image.size.width / cellsPerRow;  // Square cells
  
  int row = touchPoint.y / cellSize;
  int col = touchPoint.x / cellSize;
  
  int letter = 'A' + cellsPerRow*row + col;
  
  if (letter > 'Z') {
    _callback(0);
    return;
  }

  DLog(@"touched chooser at %d %d for letter '%c'", col, row, letter);

  if (_callback)
    _callback(letter);
}

@end
