//
//  DebugWindowController.m
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "DebugWindowController.h"

#import "AppController.h"
#import "debug.h"

@implementation DebugWindowController

- (NSManagedObjectContext *)managedObjectContext
{
	return [[NSApp delegate] managedObjectContext];
}


- (AppController *)appCtrl
{
	return theAppCtrl;
}


- (IBAction)automatischeKontoauszuegeHolen:(id)sender
{
	[theAppCtrl starteKontoauszuegePerSync];
}

@end
