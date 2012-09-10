//
//  ParticleTrailView.m
//  Lexatron
//
//  Created by Brian Hammond on 9/10/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "ParticleTrailView.h"

@implementation ParticleTrailView {
  CAEmitterLayer* emitter;
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

    emitter = (CAEmitterLayer *)self.layer;
    emitter.emitterPosition = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    emitter.emitterSize = CGSizeMake(1, 1);
    emitter.renderMode = kCAEmitterLayerAdditive;
    emitter.emitterCells = [NSArray arrayWithObjects:[self emitterCell], nil];
  }
  return self;
}

- (CAEmitterCell *)emitterCell {
  CAEmitterCell* cell = [CAEmitterCell emitterCell];
  [cell setName:@"cell"];
  cell.contents = (id)[[UIImage imageNamed:@"LittleStar"] CGImage];
  cell.birthRate = 100;
  cell.lifetime = 0.8;
  cell.lifetimeRange = 0;
  cell.velocity = 400;
  cell.velocityRange = 80;
  cell.emissionRange = 2*M_PI;
  cell.redRange = 0.5;
  cell.greenRange = 0.5;
  cell.blueRange = 0;
  cell.alphaRange = 0;
  return cell;
}

+ (Class)layerClass {
  return [CAEmitterLayer class];
}

@end
