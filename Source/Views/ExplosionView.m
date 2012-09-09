//
//  ExplosionView.m
//  Word War III
//
//  Created by Brian Hammond on 7/20/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "ExplosionView.h"

static const CGFloat kExplosionDuration = 4;

@implementation ExplosionView {
  CAEmitterLayer* emitter;
}

- (id)init {
  self = [super initWithFrame:[UIScreen mainScreen].applicationFrame];

  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    
    emitter = (CAEmitterLayer *)self.layer;
    emitter.emitterPosition = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    emitter.emitterSize = CGSizeMake(1, 1);
    emitter.renderMode = kCAEmitterLayerBackToFront;
    emitter.emitterCells = [NSArray arrayWithObjects:[self starEmitterCell], nil];
  }
  
  return self;
}

- (CAEmitterCell *)bombEmitterCell {
  CAEmitterCell* cell = [CAEmitterCell emitterCell];
  [cell setName:@"explosion"];
  cell.color = [[UIColor colorWithRed:0.7 green:0.4 blue:0.2 alpha:0.1] CGColor];
  cell.contents = (id)[[UIImage imageWithName:@"particle-fire"] CGImage];
  cell.birthRate = 0;
  cell.lifetime = kExplosionDuration;
  cell.lifetimeRange = kExplosionDuration/4;
  cell.velocity = CGRectGetWidth(self.bounds);
  cell.velocityRange = 20;
  cell.emissionRange = 2*M_PI;  
  cell.scaleSpeed = 2;
  cell.spin = 0.2;
  return cell;
}

- (CAEmitterCell *)starEmitterCell {
  CAEmitterCell* cell = [CAEmitterCell emitterCell];
  [cell setName:@"cell"];
//  cell.color = [[UIColor colorWithRed:0.7 green:0.4 blue:0.2 alpha:0.1] CGColor];
  cell.contents = (id)[[UIImage imageWithName:@"Star"] CGImage];
  cell.birthRate = 0;
  cell.lifetime = kExplosionDuration;
  cell.lifetimeRange = kExplosionDuration/3;
  cell.velocity = CGRectGetWidth(self.bounds);
  cell.velocityRange = 60;
  cell.emissionRange = 2*M_PI;
  cell.spin = 1.25;
  return cell;
}

- (void)explodeFromPoint:(CGPoint)point completion:(void(^)())completion {
  emitter.emitterPosition = point;
  
  [emitter setValue:[NSNumber numberWithInt:CGRectGetWidth(self.bounds)*0.20] forKeyPath:@"emitterCells.cell.birthRate"];

  [self performBlock:^(id sender) {
    [emitter setValue:[NSNumber numberWithInt:0] forKeyPath:@"emitterCells.cell.birthRate"];
  } afterDelay:kExplosionDuration/2];

  [self performBlock:^(id sender) {
    if (completion)
      completion();
  } afterDelay:kExplosionDuration];
}

+ (Class)layerClass {
  return [CAEmitterLayer class];
}

@end
