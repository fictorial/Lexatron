//
//  LQAudioManager.h
//  letterquest
//
//  Created by Brian Hammond on 8/4/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

enum {
  kEffectEndLost,
  kEffectEndWon,
  kEffectError,
  kEffectNotification,
  kEffectPlayedWord,
  kEffectPrompt,
  kEffectSelect,
  kEffectTilePlaced,
  kEffectBack,
  kEffectShuffle,
  kEffectRecall,
  kEffectSlide,
  kEffectNewGame,

  kEffectCount
};

@interface LQAudioManager : NSObject

+ (LQAudioManager *)sharedManager;
- (void)playEffect:(int)effectId;

@property (nonatomic, assign) BOOL soundEnabled;

@end
