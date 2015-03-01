//
//  hbcimenu_AppDelegate.h
//  hbcimenu
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 1stein.org 2008 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DockIconController.h"


@class SUUpdater;


@interface AppDelegate : NSObject 
{
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectModel *managedObjectModel;
	NSManagedObjectContext *managedObjectContext;
	IBOutlet SUUpdater * updater_;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;
+ (NSString *)applicationSupportFolder;

- (IBAction)saveAction:sender;

@end
