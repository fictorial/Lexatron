//
//  PromptViewController.h
//  letterquest
//
//  Created by Brian Hammond on 8/6/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import "BaseViewController.h"

typedef void (^ PromptCallback)(NSString *textEntered);

@interface PromptViewController : BaseViewController <UITextFieldDelegate>

+ (id)controllerWithPrompt:(NSString *)prompt
               placeholder:(NSString *)placeholder
                  callback:(PromptCallback)callback;

@end
