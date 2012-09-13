//
//  BoardView.m
//  Lexatron
//
//  Created by Brian Hammond on 8/7/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "BoardView.h"
#import "TileView.h"
#import "MatchLogic.h"
#import "UIImage+PDF.h"

static UIImage *zoomedOutBoardImage;
static UIImage *zoomedInBoardImage;

static inline int sign(float x) {
  return x == 0 ? 0 : x < 0 ? -1 : 1;
}

static inline int sideOfLine(CGPoint A, CGPoint B, CGPoint P) {
  return sign((B.x-A.x)*(P.y-A.y) - (B.y-A.y)*(P.x-A.x));  // 2D determinant of AB AP
}

@interface BoardView ()
@property (nonatomic, strong) UIView *selectionView;
@end

@implementation BoardView {
  UILabel *_label;
  BOOL _zoomed;
}

+ (void)convertPDFs {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    CGSize zoomedOutSize = CGSizeMake(kBoardWidthPoints, kBoardHeightPoints);
    CGSize zoomedInSize  = CGSizeMake(zoomedOutSize.width * kBoardMaxZoomScale,
                                      zoomedOutSize.height * kBoardMaxZoomScale);

    DLog(@"converting PDF to images...");

    zoomedOutBoardImage = [UIImage imageWithPDFNamed:@"Board.pdf" atSize:zoomedOutSize];
    zoomedInBoardImage = [UIImage imageWithPDFNamed:@"Board.pdf" atSize:zoomedInSize];

    DLog(@"done converting PDF to images.");

    [[NSNotificationCenter defaultCenter] postNotificationName:@"boardPDFsConverted" object:nil];
  });
}

- (id)initWithContainerSize:(CGSize)size {
  self = [super initWithFrame:CGRectMake(0,0,1,1)];

  if (!zoomedOutBoardImage) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(conversionDidFinish:) name:@"boardPDFsConverted" object:nil];
  } else {
    [self setImageViewFromConvertedImage];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)conversionDidFinish:(NSNotification *)notification {
  [self setImageViewFromConvertedImage];
}

- (void)setImageViewFromConvertedImage {
  _imageView = [[UIImageView alloc] initWithImage:zoomedOutBoardImage];
  self.frame = _imageView.bounds;
  [self addSubview:_imageView];
}

- (void)willZoomIn {
  _imageView.image = zoomedInBoardImage;
  _imageView.frame = CGRectMake(0, 0, _imageView.image.size.width/kBoardMaxZoomScale, _imageView.image.size.height/kBoardMaxZoomScale);
  self.bounds = _imageView.bounds;

  _label.hidden = YES;
  _zoomed = YES;
}

- (void)didZoomOut {
  _imageView.image = zoomedOutBoardImage;
  _imageView.frame = CGRectMake(0, 0, _imageView.image.size.width, _imageView.image.size.height);
  self.bounds = _imageView.bounds;

  _label.hidden = NO;
  _zoomed = NO;
}

- (CGRect)boardFromCellX:(CGFloat)x y:(CGFloat)y {
  return CGRectMake(x*kTileWidth/2, y*kTileHeight/2, kTileWidth, kTileHeight);
}

// Find the tile bounding box in which P is contained.
// This initially ignores the fact that odd-numbered rows/columns (from 0 in top-left)
// are offset by kTileHalfHeight/kTileHalfWidth from their previous row/column.
// Determine if P is on the same side of each of the 4 sides of the tile.
// If they all have side of 1 given a clockwise ordering, P is inside.

- (CGPoint)boardToCell:(CGPoint)P {
  int tx = MIN(kBoardSize/2, MAX(0, P.x / kTileWidth));
  int ty = MIN(kBoardSize/2, MAX(0, P.y / kTileHeight));

  CGFloat T = ty * kTileHeight;
  CGFloat L = tx * kTileWidth;
  CGFloat B = (ty + 1) * kTileHeight;
  CGFloat R = (tx + 1) * kTileWidth;

  CGFloat CX = (L + R) / 2.0;
  CGFloat CY = (T + B) / 2.0;

  CGPoint N = CGPointMake(CX, T);
  CGPoint E = CGPointMake(R, CY);
  CGPoint S = CGPointMake(CX, B);
  CGPoint W = CGPointMake(L, CY);

  BOOL inside = (sideOfLine(N,E,P) == 1 &&
                 sideOfLine(E,S,P) == 1 &&
                 sideOfLine(S,W,P) == 1 &&
                 sideOfLine(W,N,P) == 1);

  // Since we ignored inbetween columns/rows, reaccount for them.

  ty *= 2;
  tx *= 2;

  // If the point is not inside the tile bound by TLBR, look to see which
  // neighboring cell it is inside.  P is inside one of the corner triangles.

  if (!inside) {
    if (P.x < N.x) {    // xW
      if (P.y < W.y) {  // NW
        if (tx > 0 && ty > 0)
          --tx, --ty;
      } else {          // SW
        if (tx > 0 && ty < kBoardSize-1)
          --tx, ++ty;
      }
    } else {            // xE
      if (P.y < W.y) {  // NE
        if (tx < kBoardSize-1 && ty > 0)
          ++tx, --ty;
      } else {          // SE
        if (tx < kBoardSize-1 && ty < kBoardSize-1)
          ++tx, ++ty;
      }
    }
  }

  return isValidCell(tx, ty) ? CGPointMake(tx, ty) : CGPointMake(-1, -1);
}

// Override hit-testing since the tile view shape is a diamond.
// Had we not done this, TileView touches would be based on its frame
// which could include areas of a neighboring tile.

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  CGPoint cell = [self boardToCell:point];

  int cellIndex = cellIndexFor(cell.x, cell.y);
  if (!isValidCellIndex(cellIndex))
    return nil;

  for (UIView *subview in self.subviews) {
    if ([subview isKindOfClass:TileView.class]) {
      TileView *tileView = (TileView *)subview;
      if (tileView.letter.cellIndex == cellIndex)
        return tileView;
    }
  }

  return nil;
}

- (void)updateTilesRemainingLabelFromMatch:(Match *)match {
  [_label removeFromSuperview];

  if (match.state != kMatchStateActive)
    return;

  _label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(_imageView.bounds)-kFontSizeSmall, CGRectGetWidth(_imageView.bounds), kFontSizeSmall)];
  int count = [match bagTileCount];
  _label.text = [NSString stringWithFormat:@"%d letter%@ remain%@", count, count == 1 ? @"" : @"s", count == 1 ? @"s" : @""];
  _label.textAlignment = UITextAlignmentCenter;
  _label.textColor = [UIColor colorWithWhite:0.4 alpha:1];
  _label.backgroundColor = [UIColor clearColor];
  _label.shadowColor = [UIColor whiteColor];
  _label.shadowOffset = CGSizeMake(0,1);
  _label.lineBreakMode = UILineBreakModeWordWrap;
  _label.numberOfLines = 2;
  _label.font = [UIFont fontWithName:kFontName size:kFontSizeSmall];
  [_imageView addSubview:_label];

  _label.hidden = YES;

  if (!_zoomed) {
    [self performBlock:^(id sender) {
      [_label fadeIn:0.9 delegate:nil];
    } afterDelay:2];
  }
}

#if 0

// Shows selection of cells with an overlay view.... Just for testing

- (void)handleTouches:(NSSet *)touches {
  CGPoint P = [[touches anyObject] locationInView:_imageView];

  CGPoint cellTouched = [self boardToCell:P];

  if (cellTouched.x >= 0) {
    [self setSelection:[self boardFromCellX:cellTouched.x y:cellTouched.y] tx:cellTouched.x ty:cellTouched.y];
  } else {
    [self setSelection:CGRectZero tx:-1 ty:-1];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  [self handleTouches:touches];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  [self handleTouches:touches];
}

- (void)setSelection:(CGRect)aSelection tx:(int)tx ty:(int)ty {
  [_selectionView removeFromSuperview];
  [_label removeFromSuperview];

  NSString *text = [NSString stringWithFormat:@"(%d, %d)", tx, ty];
  NSArray *modTexts = [NSArray arrayWithObjects:@"", @"DL", @"TL", @"DW", @"TW", @"Start1", @"End1", @"Start2", @"End2", @"???", nil];

  if (aSelection.size.width > 0) {
    _selectionView = [[UIView alloc] initWithFrame:aSelection];
    _selectionView.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
    [_imageView addSubview:_selectionView];
  } else {
    text = @"Unplayable Area";
  }

  _label = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(_imageView.bounds)-30, CGRectGetWidth(_imageView.bounds), 20)];
  _label.text = [NSString stringWithFormat:@"%@ %@", text, [modTexts objectAtIndex:modifierAt(tx, ty)]];
  _label.textAlignment = UITextAlignmentCenter;
  _label.backgroundColor = [UIColor clearColor];
  _label.shadowColor = [UIColor whiteColor];
  _label.shadowOffset = CGSizeMake(0,1);
  [_imageView addSubview:_label];
}

#endif

@end
