//
//  DraggableImageView.m
//  Lexatron
//
//  Created by Brian Hammond on 9/12/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "DraggableImageView.h"

@interface DraggableImageView ()
@property (nonatomic, strong, readwrite) UIImageView *imageView;
@end

@implementation DraggableImageView

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  self.backgroundColor = [UIColor clearColor];
  return self;
}

+ (id)viewWithFrame:(CGRect)frame image:(UIImage *)image {
  DraggableImageView *div = [[DraggableImageView alloc] initWithFrame:frame];

  div.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
  div.imageView.image = image;
  div.imageView.contentMode = UIViewContentModeScaleAspectFit;
  div.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  [div addSubview:div.imageView];

  return div;
}

- (DraggableView *)makeDragProxyWithFrame:(CGRect)frame {
  return [DraggableImageView viewWithFrame:frame image:_imageView.image];
}

@end
