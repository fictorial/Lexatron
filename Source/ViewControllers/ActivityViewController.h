//
//  ActivityViewController.h
//  Lexatron
//
//  Created by Brian Hammond on 8/14/12.
//  Copyright (c) 2012 Brian Hammond. All rights reserved.
//

#import "BaseViewController.h"
#import "SSPullToRefresh.h"

@interface ActivityViewController : BaseViewController <UITableViewDataSource, UITableViewDelegate, SSPullToRefreshViewDelegate>
@end
