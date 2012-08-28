//
//  AlertView.h
//  Lexatron
//
//  Created by Brian Hammond on 8/18/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^AlertBlock)(int buttonPressed);

@interface AlertView : UIView

+ (id)alertWithCaption:(NSString *)caption
          buttonTitles:(NSArray *)buttonTitles
          buttonColors:(NSArray *)buttonColors
                 block:(AlertBlock)block
               forView:(UIView *)forView;

@end
