//
//  IJInventoryWindowController.h
//  InsideJob
//
//  Created by Adam Preble on 10/7/10.
//  Copyright 2010 Adam Preble. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IJInventoryView.h"

@class IJInventoryView;
@class IJMinecraftLevel;
@class MAAttachedWindow;
@class IJItemPropertiesViewController;

@interface IJInventoryWindowController : NSWindowController <NSWindowDelegate, IJInventoryViewDelegate> {
	IJMinecraftLevel *level;
   IJMinecraftLevel *player; /***< SMP Player.dat file use same format as level.dat */
	NSArray *inventory;
	
	NSPopUpButton *worldSelectionControl;
	NSTextField *statusTextField;
	
	IJInventoryView *inventoryView;
	IJInventoryView *quickView;
	IJInventoryView *armorView;
	
	NSMutableArray *armorInventory;
	NSMutableArray *quickInventory;
	NSMutableArray *normalInventory;
	
	// Search/Item List
	NSSearchField *itemSearchField;
	NSTableView *itemTableView;
	NSArray *allItemIds;
	NSArray *filteredItemIds;
	
	// 
	IJItemPropertiesViewController *propertiesViewController;
	MAAttachedWindow *propertiesWindow;
	id observerObject;
	
	// Document
	int64_t sessionLockValue;
   int loadedWorldIndex;
	NSString *loadedWorldFolder;
	NSString *attemptedLoadWorldFolder;
   NSString *loadedPlayer;
   NSPopUpButton *playerSelectionControl;
}

@property (nonatomic, assign) IBOutlet NSPopUpButton *worldSelectionControl;
@property (nonatomic, assign) IBOutlet NSTextField *statusTextField;
@property (nonatomic, assign) IBOutlet IJInventoryView *inventoryView;
@property (nonatomic, assign) IBOutlet IJInventoryView *quickView;
@property (nonatomic, assign) IBOutlet IJInventoryView *armorView;
@property (nonatomic, assign) IBOutlet NSSearchField *itemSearchField;
@property (nonatomic, assign) IBOutlet NSTableView *itemTableView;
@property (nonatomic, retain) NSNumber *worldTime;
@property (nonatomic, assign) IBOutlet NSPopUpButton *playerSelectionControl;

- (IBAction)menuSelectWorldFromPath:(id)sender;
- (IBAction)menuSelectWorld:(id)sender;
- (IBAction)worldSelectionChanged:(id)sender;
- (IBAction)updateItemSearchFilter:(id)sender;
- (IBAction)makeSearchFieldFirstResponder:(id)sender;
- (IBAction)itemTableViewDoubleClicked:(id)sender;

- (IBAction)setNextDay:(id)sender;
- (IBAction)setNextNight:(id)sender;
- (IBAction)setNextNoon:(id)sender;
- (IBAction)setNextMidnight:(id)sender;

- (IBAction)emptyInventory:(id)sender;
- (IBAction)saveInventoryItems:(id)sender;
- (IBAction)loadInventoryItems:(id)sender;
- (IBAction)playerSelectionChanged:(id)sender;

@end
