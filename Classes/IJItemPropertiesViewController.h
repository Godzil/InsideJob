//
//  IJItemPropertiesViewController.h
//  InsideJob
//
//  Created by Adam Preble on 10/9/10.
//  Copyright 2010 Adam Preble. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IJInventoryItem;

@interface IJItemPropertiesViewController : NSViewController {
	IJInventoryItem *item;
	IBOutlet NSButton *checkIndestructible;
}
@property (nonatomic, retain) IJInventoryItem *item;

- (void)setState:(bool)enabel;
- (IBAction)closeButton:(id)sender;
- (IBAction)makeIndestructible:(id)sender;
@end
