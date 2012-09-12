//
//  DraggableImageView.h
//  Lexatron
//
//  Created by Brian Hammond on 9/12/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "DraggableView.h"

@interface DraggableImageView : DraggableView

@property (nonatomic, strong, readonly) UIImageView *imageView;

+ (id)viewWithFrame:(CGRect)frame image:(UIImage *)image;

@end
