//
//  TileView.m
//  Lexatron
//
//  Created by Brian Hammond on 8/7/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "TileView.h"
#import "MatchLogic.h"
#import "UIView-GeomHelpers.h"

enum {
  kLetterLabelTag = 1,
  kPointLabelTag
};

@implementation TileView

- (id)init {
  self = [super initWithFrame:CGRectZero];
  self.backgroundColor = [UIColor clearColor];
  self.layer.shouldRasterize = YES;
  return self;
}

+ (id)viewWithFrame:(CGRect)frame letter:(Letter *)letter {
  TileView *tileView = [[TileView alloc] init];
  tileView.frame = frame;
  tileView.letter = letter;
  return tileView;
}

// The board can be zoomed in. We want the tiles too look good when zoomed in (i.e. non-pixelated).
// Thus, we can configure a tile view to draw itself at a larger size and scale it down for "normal" zoomed-out display.
// When zoomed in, et voila, higher quality.

- (void)configureForBoardDisplay {
  CGFloat newWidth = kTileWidth * kBoardMaxZoomScale;
  CGFloat newHeight = kTileHeight * kBoardMaxZoomScale;

  self.frame = CGRectMake(self.frame.origin.x + self.frame.size.width/2 - newWidth/2,
                          self.frame.origin.y + self.frame.size.height/2 - newHeight/2,
                          newWidth, newHeight);

  self.transform = CGAffineTransformMakeScale(1 / kBoardMaxZoomScale, 1 / kBoardMaxZoomScale);

  [self updateLabels];
}

// When on the rack, the tile is zoomed-out so draw at 1:1

- (void)configureForRackDisplayWithSize:(CGFloat)size {
  self.frame = CGRectMake(self.frame.origin.x + self.frame.size.width/2 - size/2,
                          self.frame.origin.y + self.frame.size.height/2 - size/2,
                          size, size);

  self.transform = CGAffineTransformIdentity;

  [self updateLabels];
}

- (void)setLetter:(Letter *)aLetter {
  _letter = [aLetter copy];
  [self updateLabels];
  [self setNeedsDisplay];
}

- (void)setIsNew:(BOOL)newlyPlaced {
  _isNew = newlyPlaced;
  [self updateLabels];
  [self setNeedsDisplay];
}

- (void)updateLabels {
  [[self viewWithTag:kLetterLabelTag] removeFromSuperview];
  [[self viewWithTag:kPointLabelTag] removeFromSuperview];

  UIFont *letterFont = [UIFont fontWithName:kTileLetterFontName size:roundf(self.bounds.size.height/1.7)];
  NSString *letterText = [NSString stringWithFormat:@"%c", [_letter effectiveLetter]];
  CGSize letterSize = [letterText sizeWithFont:letterFont];
  UILabel *letterLabel = [[UILabel alloc] initWithFrame:self.bounds];
  letterLabel.backgroundColor = [UIColor clearColor];
  letterLabel.font = letterFont;
  letterLabel.text = letterText;
  letterLabel.textAlignment = UITextAlignmentCenter;
  letterLabel.textColor = [self textColor];
  letterLabel.tag = kLetterLabelTag;
  letterLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  [self addSubview:letterLabel];

  if (_letter.letter != ' ') {
    CGFloat pointsFontSize = MAX(8, roundf(self.bounds.size.height/3.7));
    UIFont *pointsFont = [UIFont fontWithName:kTilePointFontName size:pointsFontSize];
    NSString *pointsText = [NSString stringWithFormat:@"%d", letterValue(_letter.letter)];
    CGSize pointsLabelSize = [pointsText sizeWithFont:pointsFont];
    CGFloat xOffset = _letter.letter == 'Q' ? -2 : 0;  // Fucker is wide!
    CGRect pointLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width/2 + letterSize.width/2 + xOffset,
                                        self.bounds.size.height/2 + letterSize.height/2 - pointsLabelSize.height - 2,
                                        pointsLabelSize.width, pointsLabelSize.height));
    UILabel *pointsLabel = [[UILabel alloc] initWithFrame:pointLabelFrame];
    pointsLabel.backgroundColor = [UIColor clearColor];
    pointsLabel.font = pointsFont;
    pointsLabel.text = pointsText;
    pointsLabel.textAlignment = UITextAlignmentCenter;
    pointsLabel.textColor = [self textColor];
    pointsLabel.tag = kPointLabelTag;
    pointsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self addSubview:pointsLabel];
  }
}

- (UIColor *)tileColor {
  return _letter.playerOwner == 0 ? kTileColorPlayerOne : kTileColorPlayerTwo;
}

- (UIColor *)textColor {
  if (_letter.turnNumber == -1 && _letter.rackIndex == -1)
    return [UIColor whiteColor];

  if (_isNew)
    return [[UIColor yellowColor] colorWithAlphaComponent:0.6];

  return _letter.playerOwner == 0 ? kTileTextColorPlayerOne : kTileTextColorPlayerTwo;
}

- (void)drawRect:(CGRect)rect {
  float w = self.bounds.size.width;
  float h = self.bounds.size.height;
  float hh = h/2;
  float hw = w/2;

  CGContextRef c = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(c, [self tileColor].CGColor);

  if (_letter.cellIndex != -1) {
    CGContextBeginPath(c);                 // fill 2:1 isometric diamond shape
    CGContextMoveToPoint(c, 0.5, hh);      // W
    CGContextAddLineToPoint(c, hw, 0.5);   // N
    CGContextAddLineToPoint(c, w-0.5, hh); // E
    CGContextAddLineToPoint(c, hw, h-0.5); // S
    CGContextAddLineToPoint(c, 0.5, hh);   // W

    CGContextClosePath(c);
    CGContextFillPath(c);
  } else {
    CGContextFillRect(c, self.bounds);   // Rack tiles aren't isometric
  }
}

- (DraggableView *)makeDragProxyWithFrame:(CGRect)frame {
  TileView *tileView = [TileView viewWithFrame:frame letter:_letter];
  return tileView;
}

@end
