//
//  FindOpponentViewController.h
//  letterquest
//
//  Created by Brian Hammond on 8/5/12.
//  Copyright (c) 2012 Fictorial LLC. All rights reserved.
//

#import <MessageUI/MessageUI.h>

#import "BaseViewController.h"
#import "KNMultiItemSelector.h"

@interface FindOpponentViewController : BaseViewController <PF_FBRequestDelegate, PF_FBDialogDelegate, KNMultiItemSelectorDelegate, MFMailComposeViewControllerDelegate>

@end
