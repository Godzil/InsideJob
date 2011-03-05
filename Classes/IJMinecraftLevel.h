//
//  IJMinecraftLevel.h
//  InsideJob
//
//  Created by Adam Preble on 10/7/10.
//  Copyright 2010 Adam Preble. All rights reserved.
//  Changes for opening folder Copyright 2011 Manoel Trapier
//

#import <Cocoa/Cocoa.h>
#import "NBTContainer.h"

@interface IJMinecraftLevel : NBTContainer {

}

@property (nonatomic, copy) NSArray *inventory; // Array of IJInventoryItem objects.
@property (nonatomic, readonly) NBTContainer *worldTimeContainer;

+ (NSString *)pathForWorldAtIndex:(int)worldIndex;

+ (NSString *)pathForLevelDatAtFolder:(NSString *)worldPath;
+ (NSString *)pathForSessionLockAtFolder:(NSString *)worldPath;

+ (BOOL)worldExistsAtFolder:(NSString *)worldPath;

+ (int64_t)writeToSessionLockAtFolder:(NSString *)worldPath;
+ (BOOL)checkSessionLockAtFolder:(NSString *)worldPath value:(int64_t)checkValue;


@end
