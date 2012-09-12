//
//  LQAudioManager.m
//  letterquest
//
//  Created by Brian Hammond on 8/4/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "LQAudioManager.h"
#import <AudioToolbox/AudioServices.h>

static NSString * const kDefaultsKeyMusicDisabled = @"LQMusicDisabled";
static NSString * const kDefaultsKeySoundDisabled = @"LQSoundDisabled";

@implementation LQAudioManager {
  SystemSoundID _soundIDs[kEffectCount];
}

+ (LQAudioManager *)sharedManager {
  static dispatch_once_t once;
  static id sharedInstance;
  
  dispatch_once(&once, ^{
    sharedInstance = [[self alloc] init];
  });
  
  return sharedInstance;
}

- (id)init {
  self = [super init];
  
  if (self) {
    NSArray *sounds = @[ @"end-lost.caf", @"end-won.caf", @"error.caf",
    @"notification.caf", @"played-word.caf", @"prompt.caf", @"select.caf",
    @"tile.caf", @"back.caf", @"shuffle.caf", @"recall.caf", @"slide.caf", 
    @"new-game.caf", @"charge.caf", @"explode.caf"
    ];

    for (int i = 0; i < kEffectCount; ++i) {
      NSString *soundPath = [[NSBundle mainBundle] pathForResource:[sounds objectAtIndex:i] ofType:nil];
      CFURLRef soundURL = (__bridge CFURLRef)[NSURL fileURLWithPath:soundPath];
      AudioServicesCreateSystemSoundID(soundURL, &_soundIDs[i]);
    }

    self.soundEnabled = ![[NSUserDefaults standardUserDefaults] boolForKey:kDefaultsKeySoundDisabled];
  }
  
  return self;
}

- (void)playEffect:(int)effectId {
  NSParameterAssert(effectId >= 0 && effectId < kEffectCount);

  if (!_soundEnabled)
    return;

  AudioServicesPlaySystemSound(_soundIDs[effectId]);
}

- (void)setSoundEnabled:(BOOL)isSoundEnabled {
  _soundEnabled = isSoundEnabled;

  [[NSUserDefaults standardUserDefaults] setBool:!isSoundEnabled forKey:kDefaultsKeySoundDisabled];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  DLog(@"sound is now %@", _soundEnabled ? @"ENABLED" : @"DISABLED");  
}

@end
