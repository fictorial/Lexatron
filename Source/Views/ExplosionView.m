//
//  ExplosionView.m
//  Word War III
//
//  Created by Brian Hammond on 7/20/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "ExplosionView.h"

@implementation ExplosionView {
  CAEmitterLayer* emitter;
  int _birthRate;
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
  }
  
  return self;
}

- (void)useBombEmitter {
  emitter.emitterCells = [NSArray arrayWithObjects:[self bombEmitterCell], nil];
  emitter.renderMode = kCAEmitterLayerAdditive;
  _birthRate = CGRectGetWidth(self.bounds)*0.50;
}

- (void)useStarEmitter {
  emitter.emitterCells = [NSArray arrayWithObjects:[self starEmitterCell], nil];
  emitter.renderMode = kCAEmitterLayerBackToFront;
  _birthRate = CGRectGetWidth(self.bounds)*0.10;
}

- (CAEmitterCell *)bombEmitterCell {
  CAEmitterCell* cell = [CAEmitterCell emitterCell];
  [cell setName:@"cell"];
  cell.color = [[UIColor colorWithRed:0.8 green:0.4 blue:0.2 alpha:0.5] CGColor];
  cell.redRange = 0.2;
  cell.greenRange = 0.1;
  cell.blueRange = 0;
  cell.contents = (id)[[UIImage imageWithName:@"FireBall"] CGImage];
  cell.birthRate = 0;
  cell.lifetime = 1;
  cell.lifetimeRange = 0.5;
  cell.velocity = CGRectGetWidth(self.bounds);
  cell.velocityRange = 2;
  cell.emissionRange = 2*M_PI;  
  cell.scaleSpeed = 1.1;
  cell.spin = 0.4;
  return cell;
}

- (CAEmitterCell *)starEmitterCell {
  CAEmitterCell* cell = [CAEmitterCell emitterCell];
  [cell setName:@"cell"];
  cell.contents = (id)[[UIImage imageWithName:@"Star"] CGImage];
  cell.birthRate = 0;
  cell.lifetime = 4;
  cell.lifetimeRange = 4/3.;
  cell.velocity = CGRectGetWidth(self.bounds);
  cell.velocityRange = 60;
  cell.emissionRange = 2*M_PI;
  cell.spin = 1.25;
  return cell;
}

- (void)explodeFromPoint:(CGPoint)point completion:(void(^)())completion {
  emitter.emitterPosition = point;
  
  [emitter setValue:[NSNumber numberWithInt:_birthRate] forKeyPath:@"emitterCells.cell.birthRate"];

  [self performBlock:^(id sender) {
    [emitter setValue:[NSNumber numberWithInt:0] forKeyPath:@"emitterCells.cell.birthRate"];
  } afterDelay:[[emitter.emitterCells objectAtIndex:0] lifetime]/2];

  [self performBlock:^(id sender) {
    if (completion)
      completion();
  } afterDelay:[[emitter.emitterCells objectAtIndex:0] lifetime]];
}

+ (Class)layerClass {
  return [CAEmitterLayer class];
}

@end
