//
//  KNSelectorItem.m
//  KNFBFriendSelectorDemo
//
//  Created by Kent Nguyen on 4/6/12.
//  Copyright (c) 2012 Kent Nguyen. All rights reserved.
//

#import "KNSelectorItem.h"

@implementation KNSelectorItem

@synthesize displayValue, selectValue, detailValue, imageUrl, selected;

-(id)initWithDisplayValue:(NSString*)displayVal {
  return [self initWithDisplayValue:displayVal selectValue:displayVal imageUrl:nil];
}

-(id)initWithDisplayValue:(NSString*)displayVal
              selectValue:(id)selectVal
                 imageUrl:(NSString*)image {
  return [self initWithDisplayValue:displayVal selectValue:displayVal detailValue:nil imageUrl:nil];
}

-(id)initWithDisplayValue:(NSString *)displayVal
              selectValue:(id)selectVal
              detailValue:(NSString *)detailVal
                 imageUrl:(NSString *)image {
  if ((self=[super init])) {
    self.displayValue = displayVal;
    self.selectValue = selectVal;
    self.detailValue = detailVal;
    self.imageUrl = image;
  }
  return self;
}

#pragma mark - Sort comparison

-(NSComparisonResult)compareByDisplayValue:(KNSelectorItem*)other {
  return [self.displayValue compare:other.displayValue];
}

-(NSComparisonResult)compareBySelectedValue:(KNSelectorItem*)other {
  return [self.selectValue compare:other.selectValue];
}
@end
