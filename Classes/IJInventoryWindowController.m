//
//  IJInventoryWindowController.m
//  InsideJob
//
//  Created by Adam Preble on 10/7/10.
//  Copyright 2010 Adam Preble. All rights reserved.
//  Changes for SMP World (external player support) ©2011 Manoel Trapier
//  Changes for searching Named SSP world and GUI changes ©2011 Nickloose
//

#import "IJInventoryWindowController.h"
#import "IJMinecraftLevel.h"
#import "IJInventoryItem.h"
#import "IJInventoryView.h"
#import "IJItemPropertiesViewController.h"
#import "MAAttachedWindow.h"
#import "NSFileManager+DirectoryLocations.h"

@interface IJInventoryWindowController ()
- (void)saveWorld;
- (void)loadWorldAtIndex:(int)worldIndex;
- (BOOL)isDocumentEdited;
- (void)loadWorldAtFolder:(NSString *)worldFolder;
- (void)loadWorldSelectionControl;
- (void)loadPlayerSelectionControl;
@end

@implementation IJInventoryWindowController
@synthesize playerSelectionControl;

@synthesize worldSelectionControl;
@synthesize statusTextField;
@synthesize inventoryView, armorView, quickView;
@synthesize itemSearchField, itemTableView;


- (void)awakeFromNib
{
    [self loadWorldSelectionControl];
    
	armorInventory = [[NSMutableArray alloc] init];
	quickInventory = [[NSMutableArray alloc] init];
	normalInventory = [[NSMutableArray alloc] init];
	statusTextField.stringValue = @"";
	
	[inventoryView setRows:3 columns:9 invert:NO];
	[quickView setRows:1 columns:9 invert:NO];
	[armorView setRows:4 columns:1 invert:YES];
	inventoryView.delegate = self;
	quickView.delegate = self;
	armorView.delegate = self;

	// Item Table View setup
	NSArray *keys = [[IJInventoryItem itemIdLookup] allKeys];
	keys = [keys sortedArrayUsingSelector:@selector(compare:)];
	allItemIds = [[NSArray alloc] initWithArray:keys];
	filteredItemIds = [allItemIds retain];
	[itemTableView setTarget:self];
	[itemTableView setDoubleAction:@selector(itemTableViewDoubleClicked:)];
}

- (void)dealloc
{
	[propertiesViewController release];
	[armorInventory release];
	[quickInventory release];
	[normalInventory release];
	[inventory release];
	[level release];
   [player release];
	[super dealloc];
}


#pragma mark -
#pragma mark World Selection

- (void)dirtyLoadSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	if (returnCode == NSAlertOtherReturn) // Cancel
	{
		[worldSelectionControl selectItemWithTitle:[loadedWorldFolder lastPathComponent]];
		return;
	}
	
	if (returnCode == NSAlertDefaultReturn) // Save
	{
		[self saveWorld];
      [self loadWorldAtFolder:attemptedLoadWorldFolder];
	}
	else if (returnCode == NSAlertAlternateReturn) // Don't save
	{
		[self setDocumentEdited:NO]; // Slightly hacky -- prevent the alert from being put up again.
      [self loadWorldAtFolder:attemptedLoadWorldFolder];
	}
}

- (void)loadWorldPlayerInventory:(NSString *)PlayerName
{
   /*
    * If passing NULL to PlayerName, we will use level.dat instead of
    * Players/PlayerName.dat file 
    */
   NSString *playerPath;
   
   [armorInventory removeAllObjects];
	[quickInventory removeAllObjects];
	[normalInventory removeAllObjects];
	
	[inventoryView setItems:normalInventory];
	[quickView setItems:quickInventory];
	[armorView setItems:armorInventory];
   
   [player release];
   player = nil;
	[inventory release];
	inventory = nil;
   
   loadedPlayer = nil;
   
   NSLog(@"Player name: %@",PlayerName);
   if ([PlayerName isEqualToString: @"World default"])
      playerPath = [IJMinecraftLevel pathForPlayer:nil withWorld: loadedWorldFolder];   
   else
      playerPath = [IJMinecraftLevel pathForPlayer:PlayerName withWorld: loadedWorldFolder];   
   
   NSLog(@"Path: %@", playerPath);
   
   NSData *playerFileData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:playerPath]];
	if (!playerFileData)
	{
		// Error loading 
		NSBeginCriticalAlertSheet(@"Error loading player.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"InsideJob was unable to load the level at %@.", playerPath);
		return;
	}
   
   player = [[IJMinecraftLevel nbtContainerWithData:playerFileData] retain];
	inventory = [[player inventory] retain];
	
	// Add placeholder inventory items:
	
	for (int i = 0; i < IJInventorySlotQuickLast + 1 - IJInventorySlotQuickFirst; i++)
		[quickInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotQuickFirst + i]];
	
	for (int i = 0; i < IJInventorySlotNormalLast + 1 - IJInventorySlotNormalFirst; i++)
		[normalInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotNormalFirst + i]];
	
	for (int i = 0; i < IJInventorySlotArmorLast + 1 - IJInventorySlotArmorFirst; i++)
		[armorInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotArmorFirst + i]];
	
	
	// Overwrite the placeholders with actual inventory:
	
	for (IJInventoryItem *item in inventory)
	{
		if (IJInventorySlotQuickFirst <= item.slot && item.slot <= IJInventorySlotQuickLast)
		{
			[quickInventory replaceObjectAtIndex:item.slot - IJInventorySlotQuickFirst withObject:item];
		}
		else if (IJInventorySlotNormalFirst <= item.slot && item.slot <= IJInventorySlotNormalLast)
		{
			[normalInventory replaceObjectAtIndex:item.slot - IJInventorySlotNormalFirst withObject:item];
		}
		else if (IJInventorySlotArmorFirst <= item.slot && item.slot <= IJInventorySlotArmorLast)
		{
			[armorInventory replaceObjectAtIndex:item.slot - IJInventorySlotArmorFirst withObject:item];
		}
	}
	
   //	NSLog(@"normal: %@", normalInventory);
   //	NSLog(@"quick: %@", quickInventory);
	
	[inventoryView setItems:normalInventory];
	[quickView setItems:quickInventory];
	[armorView setItems:armorInventory];
	
	[self setDocumentEdited:NO];
	statusTextField.stringValue = @"Player loaded!";
	loadedPlayer = [PlayerName retain];
}

- (void)loadWorldAtFolder:(NSString *)worldPath
{
	if ([self isDocumentEdited])
	{
      attemptedLoadWorldFolder = worldPath;
		NSBeginInformationalAlertSheet(@"Do you want to save the changes you made in this world?", @"Save", @"Don't Save", @"Cancel", self.window, self, @selector(dirtyLoadSheetDidEnd:returnCode:contextInfo:), nil, nil, @"Your changes will be lost if you do not save them.");
		return;
	}
	
   NSFileManager *filemgr;
   NSArray *filelist;
   NSError *fileError;
   int count, i;
   
	[armorInventory removeAllObjects];
	[quickInventory removeAllObjects];
	[normalInventory removeAllObjects];
	
	[inventoryView setItems:normalInventory];
	[quickView setItems:quickInventory];
	[armorView setItems:armorInventory];
	
	[self willChangeValueForKey:@"worldTime"];
	[level release];
	level = nil;
   [player release];
   player = nil;
	[inventory release];
	inventory = nil;
	[self didChangeValueForKey:@"worldTime"];
	
	statusTextField.stringValue = @"No world loaded.";
   NSString *levelPath = [IJMinecraftLevel pathForLevelDatAtFolder:worldPath];
   NSData *fileData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:levelPath]];

	sessionLockValue = [IJMinecraftLevel writeToSessionLockAtFolder:worldPath];
	if (![IJMinecraftLevel checkSessionLockAtFolder:worldPath value:sessionLockValue])
	{
		NSBeginCriticalAlertSheet(@"Error loading world.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable obtain the session lock.");
		return;
	}
    
	if (!fileData)
	{
		// Error loading 
		NSBeginCriticalAlertSheet(@"Error loading world.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"InsideJob was unable to load the level at %@.", levelPath);
		return;
	}
	
	[self willChangeValueForKey:@"worldTime"];
	
	/* Now search for first player .dat file (but by default try to load from level.dat */
	if (!fileData)
	{
		// Error loading 
		NSBeginCriticalAlertSheet(@"Error loading world.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"InsideJob was unable to load the level at %@.", levelPath);
		return;
	}
	
	[self willChangeValueForKey:@"worldTime"];
	
   [playerSelectionControl setHidden: YES];
   /* Now search for first player .dat file (but by default try to load from level.dat */
   /* Verify that a "Player" folder exist. If not do nt show the player list */
   filemgr = [NSFileManager defaultManager];
   
   filelist = [filemgr contentsOfDirectoryAtPath:worldPath error:&fileError];
   
   count = [filelist count];
   
   for (i = 0; i < count; i++)
   {
      NSLog (@"File in world/ %@", [filelist objectAtIndex: i]);
      if ([[filelist objectAtIndex: i] isEqualTo: @"players"])
      {
         [playerSelectionControl setHidden: NO];
         [self loadPlayerSelectionControl];
         break;
      }
   }
   
   loadedPlayer = nil;
   NSString *playerPath = [IJMinecraftLevel pathForPlayer:loadedPlayer withWorld:worldPath];

   /* Now load level.dat as if i is not a SMP. */
   
   NSData *playerFileData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:playerPath]];
	if (!playerFileData)
	{
		// Error loading 
		NSBeginCriticalAlertSheet(@"Error loading player.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"InsideJob was unable to load the level at %@.", playerPath);
		return;
	}
   
	level  = [[IJMinecraftLevel nbtContainerWithData:fileData] retain];
   player = [[IJMinecraftLevel nbtContainerWithData:playerFileData] retain];
	inventory = [[player inventory] retain];
	
	[self didChangeValueForKey:@"worldTime"];
	
	// Add placeholder inventory items:
	
	for (int i = 0; i < IJInventorySlotQuickLast + 1 - IJInventorySlotQuickFirst; i++)
		[quickInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotQuickFirst + i]];
	
	for (int i = 0; i < IJInventorySlotNormalLast + 1 - IJInventorySlotNormalFirst; i++)
		[normalInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotNormalFirst + i]];
	
	for (int i = 0; i < IJInventorySlotArmorLast + 1 - IJInventorySlotArmorFirst; i++)
		[armorInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotArmorFirst + i]];
	
	
	// Overwrite the placeholders with actual inventory:
	
	for (IJInventoryItem *item in inventory)
	{
		if (IJInventorySlotQuickFirst <= item.slot && item.slot <= IJInventorySlotQuickLast)
		{
			[quickInventory replaceObjectAtIndex:item.slot - IJInventorySlotQuickFirst withObject:item];
		}
		else if (IJInventorySlotNormalFirst <= item.slot && item.slot <= IJInventorySlotNormalLast)
		{
			[normalInventory replaceObjectAtIndex:item.slot - IJInventorySlotNormalFirst withObject:item];
		}
		else if (IJInventorySlotArmorFirst <= item.slot && item.slot <= IJInventorySlotArmorLast)
		{
			[armorInventory replaceObjectAtIndex:item.slot - IJInventorySlotArmorFirst withObject:item];
		}
	}
	
   //	NSLog(@"normal: %@", normalInventory);
   //	NSLog(@"quick: %@", quickInventory);
	
	[inventoryView setItems:normalInventory];
	[quickView setItems:quickInventory];
	[armorView setItems:armorInventory];
	
	[self setDocumentEdited:NO];
	statusTextField.stringValue = @"World loaded!";
	loadedWorldFolder = [worldPath retain];

   NSLog(@"%@",loadedWorldFolder);
   NSLog(@"%@",worldPath);
    
}

- (void)loadWorldAtIndex:(int)worldIndex
{
   NSString *worldPath;
   worldPath = [IJMinecraftLevel pathForWorldAtIndex:worldIndex];
   
   [self loadWorldAtFolder: worldPath];
}


- (void)saveWorld
{
	NSString *worldPath = loadedWorldFolder;

	if (inventory == nil)
		return; // no world loaded, nothing to save
	
	if (![IJMinecraftLevel checkSessionLockAtFolder:worldPath value:sessionLockValue])
	{
		NSBeginCriticalAlertSheet(@"Another application has modified this world.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"The session lock was changed by another application.");
		return;
	}
	
	NSString *levelPath = [IJMinecraftLevel pathForLevelDatAtFolder:worldPath];
	NSString *playerPath = [IJMinecraftLevel pathForPlayer:loadedPlayer withWorld:worldPath];
   
	NSMutableArray *newInventory = [NSMutableArray array];
	
	for (NSArray *items in [NSArray arrayWithObjects:armorInventory, quickInventory, normalInventory, nil])
	{
		for (IJInventoryItem *item in items)
		{
			if (item.count > 0 && item.itemId > 0)
				[newInventory addObject:item];
		}
	}
	
	[player setInventory:newInventory];
	
	NSString *backupLevelPath = [levelPath stringByAppendingPathExtension:@"insidejobbackup"];
   NSString *backupPlayerPath = [playerPath stringByAppendingPathExtension:@"insidejobbackup"];
	
	BOOL success = NO;
	NSError *error = nil;
	
	// Remove a previously-created .insidejobbackup, if it exists:
	if ([[NSFileManager defaultManager] fileExistsAtPath:backupLevelPath])
	{
		success = [[NSFileManager defaultManager] removeItemAtPath:backupLevelPath error:&error];
		if (!success)
		{
			NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [error localizedDescription]);
			NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to remove the prior backup of this level file:\n%@", [error localizedDescription]);
			return;
		}
	}
	
	// Create the backup:
	success = [[NSFileManager defaultManager] copyItemAtPath:levelPath toPath:backupLevelPath error:&error];
	if (!success)
	{
		NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [error localizedDescription]);
		NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to create a backup of the existing level file:\n%@", [error localizedDescription]);
		return;
	}

   // Write the new level.dat out:
	success = [[player writeData] writeToURL:[NSURL fileURLWithPath:levelPath] options:0 error:&error];
   
	if (!success)
	{
		NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [error localizedDescription]);
		
		NSError *restoreError = nil;
		success = [[NSFileManager defaultManager] copyItemAtPath:backupLevelPath toPath:levelPath error:&restoreError];
		if (!success)
		{
			NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [restoreError localizedDescription]);
			NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to save to the existing level file, and the backup could not be restored.\n%@\n%@", [error localizedDescription], [restoreError localizedDescription]);
		}
		else
      {
         NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to save to the existing level file, and the backup was successfully restored.\n%@", [error localizedDescription]);
      }
		return;
	}

   if (playerPath != levelPath)
   {
      
      // Remove a previously-created .insidejobbackup, if it exists:
      if ([[NSFileManager defaultManager] fileExistsAtPath:backupPlayerPath])
      {
         success = [[NSFileManager defaultManager] removeItemAtPath:backupPlayerPath error:&error];
         if (!success)
         {
            NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [error localizedDescription]);
            NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to remove   the prior backup of this player file:\n%@", [error localizedDescription]);
            return;
         }
      }
      
      success = [[NSFileManager defaultManager] copyItemAtPath:playerPath toPath:backupPlayerPath error:&error];
      if (!success)
      {
         NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [error localizedDescription]);
         NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to create a backup of the existing player file:\n%@", [error localizedDescription]);
         return;
      }

      // Write the new player.dat out:
      success = [[player writeData] writeToURL:[NSURL fileURLWithPath:playerPath] options:0 error:&error];
   
      if (!success)
      {
         NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [error localizedDescription]);
		
         NSError *restoreError = nil;
		
         success = [[NSFileManager defaultManager] copyItemAtPath:backupPlayerPath toPath:playerPath error:&restoreError];
         if (!success)
         {
            NSLog(@"%s:%d %@", __PRETTY_FUNCTION__, __LINE__, [restoreError localizedDescription]);
            NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to save to the existing player file, and the backup could not be restored.\n%@\n%@", [error localizedDescription], [restoreError localizedDescription]);
         }
         else
         {
            NSBeginCriticalAlertSheet(@"An error occurred while saving.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Inside Job was unable to save to the existing player file, and the backup was successfully restored.\n%@", [error localizedDescription]);
         }
         return;
      }
   }
	[self setDocumentEdited:NO];
	statusTextField.stringValue = @"Saved.";
}

- (void)setDocumentEdited:(BOOL)edited
{
	[super setDocumentEdited:edited];
	if (edited)
		statusTextField.stringValue = @"World has unsaved changes.";
}

- (BOOL)isDocumentEdited
{
	return [self.window isDocumentEdited];
}

#pragma mark -
#pragma mark Actions

- (IBAction)menuSelectWorld:(id)sender
{
	int worldIndex = [sender tag];
	[self loadWorldAtIndex:worldIndex];
	[worldSelectionControl selectItemWithTitle:[loadedWorldFolder lastPathComponent]];
}

- (IBAction)menuSelectWorldFromPath:(id)sender
{
    NSInteger openResult;
    /* Ask user for world folder path */
    NSOpenPanel *panel = [NSOpenPanel openPanel];   
    NSString *worldPath;
    
    /* Only allow to choose a folder */
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    openResult = [panel runModal];
    
    if (openResult == NSOKButton)
    {
        worldPath = [[panel directoryURL] path];
        
        /* Verify for level.dat */
        if (![IJMinecraftLevel worldExistsAtFolder: worldPath])
        {
            NSBeginCriticalAlertSheet(@"No world exists in that slot.", @"Dismiss", nil, nil, self.window, nil, nil, nil, nil, @"Please create a new single player world in this slot using Minecraft and try again.");
            return;
        }
        /* Now try to open the world... */
        [self loadWorldAtFolder:[[panel directoryURL] path]];
        [worldSelectionControl addItemWithTitle:[loadedWorldFolder lastPathComponent]];
        [worldSelectionControl selectItemWithTitle:[loadedWorldFolder lastPathComponent]];
        
    }
}

- (IBAction)worldSelectionChanged:(id)sender
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [paths objectAtIndex:0];
	path = [path stringByAppendingPathComponent:@"minecraft"];
	path = [path stringByAppendingPathComponent:@"saves"];
    
    
   NSString* worldName = [worldSelectionControl titleOfSelectedItem];
	NSString* worldPath = [path stringByAppendingPathComponent:worldName];
    
   NSLog(@"loadedWorldFolder: %@",loadedWorldFolder);
   NSLog(@"worldName: %@",worldName);
   NSLog(@"worldPath: %@",worldPath);

   [self loadWorldAtFolder:worldPath];
}

- (void)loadWorldSelectionControl
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [paths objectAtIndex:0];
	path = [path stringByAppendingPathComponent:@"minecraft"];
	path = [path stringByAppendingPathComponent:@"saves"];
    
    
    NSFileManager *filemgr;
    NSArray *filelist;
    NSError *fileError;
    int count;
    int i;
    
    filemgr = [NSFileManager defaultManager];
    
    filelist = [filemgr contentsOfDirectoryAtPath:path error:&fileError];
    
    count = [filelist count];
    
    
    [worldSelectionControl removeAllItems];
    for (i = 0; i < count; i++)
    {
        NSLog (@"%@", [filelist objectAtIndex: i]);
        if([IJMinecraftLevel worldExistsAtFolder:[path stringByAppendingPathComponent:[filelist objectAtIndex: i]]])
            [worldSelectionControl addItemWithTitle:[filelist objectAtIndex: i]];
    }
    
    [filemgr release];
    
}

- (void)loadPlayerSelectionControl
{
	NSString *playerPath = loadedWorldFolder; 
   playerPath = [playerPath stringByAppendingPathComponent:@"players"];
   
   NSFileManager *filemgr;
   NSArray *filelist;
   NSError *fileError;
   int count;
   int i;
   
   filemgr = [NSFileManager defaultManager];
   
   filelist = [filemgr contentsOfDirectoryAtPath:playerPath error:&fileError];
   
   count = [filelist count];
      
   [playerSelectionControl removeAllItems];
   
   [playerSelectionControl addItemWithTitle:@"World default"];
   
   for (i = 0; i < count; i++)
   {
      NSLog (@"%@", [filelist objectAtIndex: i]);
      /* Get only .dat file */
      if ([[[filelist objectAtIndex: i] pathExtension] isEqualToString:@"dat"])
         [playerSelectionControl addItemWithTitle:[[filelist objectAtIndex: i] stringByDeletingPathExtension]];
   }
   
   [filemgr release];
   
}

- (void)saveDocument:(id)sender
{
	[self saveWorld];
}

- (void)delete:(id)sender
{
//	IJInventoryItem *item = [outlineView itemAtRow:[outlineView selectedRow]];
//	item.count = 0;
//	item.itemId = 0;
//	item.damage = 0;
//	[self setDocumentEdited:YES];
//	[outlineView reloadItem:item];
}

- (IBAction)makeSearchFieldFirstResponder:(id)sender
{
	[itemSearchField becomeFirstResponder];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if (anItem.action == @selector(saveDocument:))
		return inventory != nil;
		
	return YES;
}


- (NSNumber *)worldTime
{
	return 	[level worldTimeContainer].numberValue;
}

- (void)setWorldTime:(NSNumber *)number
{
	[self willChangeValueForKey:@"worldTime"];
	[level worldTimeContainer].numberValue = number;
	[self didChangeValueForKey:@"worldTime"];
	[self setDocumentEdited:YES];
}


- (void)calcTimePoints:(int)number
{
	int result;
	int wTime = [[self worldTime] intValue];
	result =wTime +(number - (wTime % number));
	
	NSNumber *newTime = [NSNumber numberWithInt:result];
	[self setWorldTime:newTime];
}

- (IBAction)setNextDay:(id)sender
{
	int number = 24000;
	[self calcTimePoints:number];
}

- (IBAction)setNextNight:(id)sender
{
	int number = 12000;
	[self calcTimePoints:number];
}

- (IBAction)setNextMidnight:(id)sender
{
	int number = 18000;
	[self calcTimePoints:number];
}

- (IBAction)setNextNoon:(id)sender
{
	int number = 6000;
	[self calcTimePoints:number];
}

- (void)clearInventory{
	
	[armorInventory removeAllObjects];
	[quickInventory removeAllObjects];
	[normalInventory removeAllObjects];
	
	[inventoryView setItems:normalInventory];
	[quickView setItems:quickInventory];
	[armorView setItems:armorInventory];
	
	[self setDocumentEdited:YES];
}

- (void)saveInventory
{
	
	NSString *path = [[NSFileManager defaultManager] applicationSupportDirectory];
	NSLog(@"%@",path);
	NSString *file = @"Inventory.plist";
	
	
	NSString *InventoryPath = [path stringByAppendingPathComponent:file];
	
	NSLog(@"%@",InventoryPath);

	
	NSMutableArray *newInventory = [NSMutableArray array];
	
	for (NSArray *items in [NSArray arrayWithObjects:armorInventory, quickInventory, normalInventory, nil])
	{
		for (IJInventoryItem *item in items)
		{
			if (item.count > 0 && item.itemId > 0)
				[newInventory addObject:item];
		}
	}
	
	[NSKeyedArchiver archiveRootObject: newInventory toFile:InventoryPath];
}

-(void)loadInventory
{
	NSString *path = [[NSFileManager defaultManager] applicationSupportDirectory];
	NSString *file = @"Inventory.plist";
	NSString *InventoryPath = [path stringByAppendingPathComponent:file];
	
	
	[self clearInventory];
	NSArray *newInventory = [NSKeyedUnarchiver unarchiveObjectWithFile:InventoryPath];
	
	for (int i = 0; i < IJInventorySlotQuickLast + 1 - IJInventorySlotQuickFirst; i++)
		[quickInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotQuickFirst + i]];
	
	for (int i = 0; i < IJInventorySlotNormalLast + 1 - IJInventorySlotNormalFirst; i++)
		[normalInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotNormalFirst + i]];
	
	for (int i = 0; i < IJInventorySlotArmorLast + 1 - IJInventorySlotArmorFirst; i++)
		[armorInventory addObject:[IJInventoryItem emptyItemWithSlot:IJInventorySlotArmorFirst + i]];
	
	for (IJInventoryItem *item in newInventory)
	{
		if (IJInventorySlotQuickFirst <= item.slot && item.slot <= IJInventorySlotQuickLast)
		{
			[quickInventory replaceObjectAtIndex:item.slot - IJInventorySlotQuickFirst withObject:item];
		}
		else if (IJInventorySlotNormalFirst <= item.slot && item.slot <= IJInventorySlotNormalLast)
		{
			[normalInventory replaceObjectAtIndex:item.slot - IJInventorySlotNormalFirst withObject:item];
		}
		else if (IJInventorySlotArmorFirst <= item.slot && item.slot <= IJInventorySlotArmorLast)
		{
			[armorInventory replaceObjectAtIndex:item.slot - IJInventorySlotArmorFirst withObject:item];
		}
	}
	
	[inventoryView setItems:normalInventory];
	[quickView setItems:quickInventory];
	[armorView setItems:armorInventory];
	
}

- (IBAction)emptyInventory:(id)sender
{
	[self clearInventory];
}

- (IBAction)saveInventoryItems:(id)sender
{
	[self saveInventory];
}

- (IBAction)loadInventoryItems:(id)sender
{
	[self loadInventory];
}

- (IBAction)playerSelectionChanged:(id)sender
{
   [self loadWorldPlayerInventory: [playerSelectionControl titleOfSelectedItem]];
}


#pragma mark -
#pragma mark IJInventoryViewDelegate

- (IJInventoryView *)inventoryViewForItemArray:(NSMutableArray *)theItemArray
{
	if (theItemArray == normalInventory)
		return inventoryView;
	if (theItemArray == quickInventory)
		return quickView;
	if (theItemArray == armorInventory)
		return armorView;
	
	return nil;
}

- (NSMutableArray *)itemArrayForInventoryView:(IJInventoryView *)theInventoryView slotOffset:(int*)slotOffset
{
	if (theInventoryView == inventoryView)
	{
		if (slotOffset) *slotOffset = IJInventorySlotNormalFirst;
		return normalInventory;
	}
	else if (theInventoryView == quickView)
	{
		if (slotOffset) *slotOffset = IJInventorySlotQuickFirst;
		return quickInventory;
	}
	else if (theInventoryView == armorView)
	{
		if (slotOffset) *slotOffset = IJInventorySlotArmorFirst;
		return armorInventory;
	}
	return nil;
}

- (void)inventoryView:(IJInventoryView *)theInventoryView removeItemAtIndex:(int)itemIndex
{
	int slotOffset = 0;
	NSMutableArray *itemArray = [self itemArrayForInventoryView:theInventoryView slotOffset:&slotOffset];
	
	if (itemArray)
	{
		IJInventoryItem *item = [IJInventoryItem emptyItemWithSlot:slotOffset + itemIndex];
		[itemArray replaceObjectAtIndex:itemIndex withObject:item];
		[theInventoryView setItems:itemArray];
	}
	[self setDocumentEdited:YES];
}

- (void)inventoryView:(IJInventoryView *)theInventoryView setItem:(IJInventoryItem *)item atIndex:(int)itemIndex
{
	int slotOffset = 0;
	NSMutableArray *itemArray = [self itemArrayForInventoryView:theInventoryView slotOffset:&slotOffset];
	
	if (itemArray)
	{
		[itemArray replaceObjectAtIndex:itemIndex withObject:item];
		item.slot = slotOffset + itemIndex;
		[theInventoryView setItems:itemArray];
	}
	[self setDocumentEdited:YES];
}

- (void)inventoryView:(IJInventoryView *)theInventoryView selectedItemAtIndex:(int)itemIndex
{
	// Show the properties window for this item.
	IJInventoryItem *lastItem = propertiesViewController.item;
	
	NSPoint itemLocationInView = [theInventoryView pointForItemAtIndex:itemIndex];
	NSPoint point = [theInventoryView convertPoint:itemLocationInView toView:nil];
	point.x += 16 + 8;
	point.y -= 16;
	
	NSArray *items = [self itemArrayForInventoryView:theInventoryView slotOffset:nil];
	IJInventoryItem *item = [items objectAtIndex:itemIndex];
	//NSLog(@"%s index=%d item=%@", _cmd, itemIndex, item);
	if (item.itemId == 0 || lastItem == item)
	{
		// Perhaps caused by a bug, but it seems to be possible for the window to not be invisible at this point,
		// so we will set the alpha value here to be sure.
		[propertiesWindow setAlphaValue:0.0];
		propertiesViewController.item = nil;
		return; // can't show info on nothing
	}
	
	if (!propertiesViewController)
	{
		propertiesViewController = [[IJItemPropertiesViewController alloc] initWithNibName:@"ItemPropertiesView" bundle:nil];
		
		propertiesWindow = [[MAAttachedWindow alloc] initWithView:propertiesViewController.view
												  attachedToPoint:point
														 inWindow:self.window
														   onSide:MAPositionRight
													   atDistance:0];
		[propertiesWindow setBackgroundColor:[NSColor controlBackgroundColor]];
		[propertiesWindow setViewMargin:4.0];
		[propertiesWindow setAlphaValue:1.0];
		[[self window] addChildWindow:propertiesWindow ordered:NSWindowAbove];
	}
	if (observerObject)
		[[NSNotificationCenter defaultCenter] removeObserver:observerObject];
	observerObject = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignKeyNotification
																	   object:propertiesWindow
																		queue:[NSOperationQueue mainQueue]
																   usingBlock:^(NSNotification *notification) {
																	   [propertiesViewController commitEditing];
																	   if (item.count == 0)
																		   item.itemId = 0;
																	   [theInventoryView reloadItemAtIndex:itemIndex];
																	   [propertiesWindow setAlphaValue:0.0];
																   }];
	propertiesViewController.item = item;
	
	if (propertiesViewController.item.damage == -1000){
		[propertiesViewController setState:YES];
	}else {
		[propertiesViewController setState:NO];
	}

	
	[propertiesWindow setPoint:point side:MAPositionRight];
	[propertiesWindow makeKeyAndOrderFront:nil];
	[propertiesWindow setAlphaValue:1.0];
}

#pragma mark -
#pragma mark Item Picker


- (IBAction)updateItemSearchFilter:(id)sender
{
	NSString *filterString = [sender stringValue];
	
	if (filterString.length == 0)
	{
		[filteredItemIds autorelease];
		filteredItemIds = [allItemIds retain];
		[itemTableView reloadData];
		return;
	}
	
	NSMutableArray *results = [NSMutableArray array];
	
	for (NSNumber *itemId in allItemIds)
	{
		NSString *name = [[IJInventoryItem itemIdLookup] objectForKey:itemId];
		NSRange range = [name rangeOfString:filterString options:NSCaseInsensitiveSearch];
		if (range.location != NSNotFound)
		{
			[results addObject:itemId];
			continue;
		}
		
		// Also search the item id:
		range = [[itemId stringValue] rangeOfString:filterString];
		if (range.location != NSNotFound)
		{
			[results addObject:itemId];
			continue;
		}
	}
	
	[filteredItemIds autorelease];
	filteredItemIds = [results retain];
	[itemTableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)theTableView
{
	return filteredItemIds.count;
}
- (id)tableView:(NSTableView *)theTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSNumber *itemId = [filteredItemIds objectAtIndex:row];
	
	if ([tableColumn.identifier isEqual:@"itemId"])
	{
		return itemId;
	}
	else if ([tableColumn.identifier isEqual:@"image"])
	{
		return [IJInventoryItem imageForItemId:[itemId shortValue]];
	}
	else
	{
		NSString *name = [[IJInventoryItem itemIdLookup] objectForKey:itemId];
		return name;
	}
}
- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	[pboard declareTypes:[NSArray arrayWithObjects:IJPasteboardTypeInventoryItem, nil] owner:nil];
	
	NSNumber *itemId = [filteredItemIds objectAtIndex:[rowIndexes firstIndex]];
	
	IJInventoryItem *item = [[IJInventoryItem alloc] init];
	item.itemId = [itemId shortValue];
	item.count = 1;
	item.damage = 0;
	item.slot = 0;
	
	[pboard setData:[NSKeyedArchiver archivedDataWithRootObject:item]
			forType:IJPasteboardTypeInventoryItem];
	
	[item release];

	return YES;
}

- (NSMutableArray *)inventoryArrayWithEmptySlot:(NSUInteger *)slot
{
	for (NSMutableArray *inventoryArray in [NSArray arrayWithObjects:quickInventory, normalInventory, nil])
	{
		__block BOOL found = NO;
		[inventoryArray enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
			IJInventoryItem *item = obj;
			if (item.count == 0)
			{
				*slot = index;
				*stop = YES;
				found = YES;
			}
		}];
		if (found)
			return inventoryArray;
	}
	return nil;
}

- (IBAction)itemTableViewDoubleClicked:(id)sender
{
	NSUInteger slot;
	NSMutableArray *inventoryArray = [self inventoryArrayWithEmptySlot:&slot];
	if (!inventoryArray)
		return;

	IJInventoryItem *item = [inventoryArray objectAtIndex:slot];
	item.itemId = [[filteredItemIds objectAtIndex:[itemTableView selectedRow]] shortValue];
	item.count = 1;
	[self setDocumentEdited:YES];

	IJInventoryView *invView = [self inventoryViewForItemArray:inventoryArray];
	[invView reloadItemAtIndex:slot];
	[self inventoryView:invView selectedItemAtIndex:slot];
}

#pragma mark -
#pragma mark NSWindowDelegate

- (void)dirtyCloseSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	if (returnCode == NSAlertOtherReturn) // Cancel
		return;
	
	if (returnCode == NSAlertDefaultReturn) // Save
	{
		[self saveWorld];
		[self.window performClose:nil];
	}
	else if (returnCode == NSAlertAlternateReturn) // Don't save
	{
		[self setDocumentEdited:NO]; // Slightly hacky -- prevent the alert from being put up again.
		[self.window performClose:nil];
	}
}


- (BOOL)windowShouldClose:(id)sender
{
	if ([self isDocumentEdited])
	{
		// Note: We use the didDismiss selector becuase the sheet needs to be closed in order for performClose: to work.
		NSBeginInformationalAlertSheet(@"Do you want to save the changes you made in this world?", @"Save", @"Don't Save", @"Cancel", self.window, self, nil, @selector(dirtyCloseSheetDidDismiss:returnCode:contextInfo:), nil, @"Your changes will be lost if you do not save them.");
		return NO;
	}
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification
{
	[NSApp terminate:nil];
}


#pragma mark -
#pragma mark NSControlTextEditingDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if (command == @selector(moveDown:))
	{
		if ([itemTableView numberOfRows] > 0)
		{
			[self.window makeFirstResponder:itemTableView];
			[itemTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		}
		return YES;
	}
	return YES;
}

@end
