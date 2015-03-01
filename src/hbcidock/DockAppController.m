//
//  DockAppController.m
//  hbci
//
//  Created by Stefan Schimanski on 14.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "DockAppController.h"

#import "debug.h"


#ifdef DEBUG
NSString * dockId_ = @"com.limoia.Saldomat.Dock-debug";
NSString * dockIconControllerId_ = @"com.limoia.Saldomat.DockIconController-debug";
#else
NSString * dockId_ = @"com.limoia.Saldomat.Dock";
NSString * dockIconControllerId_ = @"com.limoia.Saldomat.DockIconController";
#endif


@implementation DockAppController

- (NSProxy<DockIconControllerProtocol> *)dockIconController
{
	@try {
		// mit Saldomat verbinden
		id proxy = [NSConnection rootProxyForConnectionWithRegisteredName:dockIconControllerId_ host:nil];
		if (proxy == nil) {
			NSLog(@"Cannot find %@ object", dockIconControllerId_);
			[NSApp terminate:self];
			return nil;
		}
		
		// Verbinden hat geklappt
		[proxy setProtocolForProxy:@protocol(DockIconControllerProtocol)];
		NSLog(@"Connected to %@", dockIconControllerId_);
		return (NSProxy<DockIconControllerProtocol> *)proxy;
	}
	@catch (NSException * e) {
		NSLog(@"Exception when connecting to %@: %@", dockIconControllerId_, e);
		[NSApp terminate:self];
	}
	
	return nil;
}


- (id) init
{
	self = [super init];
	wasClickActivation_ = YES;
	return self;
}


- (void)awakeFromNib
{
	// Auf Drops von Dateien reagieren
	[NSApp setDelegate:self];
	
	// Auf Terminieren reagieren
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:NSApplicationWillTerminateNotification
						   object:nil];
	
	// DO-Objekt freigeben
	NSConnection * con = [NSConnection defaultConnection];
	[con setRootObject:self];
	if ([con registerName:dockId_] == NO)
		NSLog(@"Could not vend %@ object", dockId_);
	
	// Mit hbcimenu verbinden
	[self dockIconController];
}


- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	NSLog(@"applicationDidBecomeActive");
	if (wasClickActivation_)
		[[self dockIconController] activate];
	wasClickActivation_ = YES;
}


- (void)terminate
{
	NSLog(@"terminating");
	[NSApp terminate:self];
}


- (void)activate
{
	if (![NSApp isActive]) {
		wasClickActivation_ = NO;
		[NSApp activateIgnoringOtherApps:YES];
	}
}


- (void)willTerminate:(NSNotification *)notification
{
	[[self dockIconController] hideWindows];
}


- (IBAction)preferences:(id)sender
{
	[[self dockIconController] preferences];
}


- (IBAction)about:(id)sender
{
	[[self dockIconController] about];
}


- (IBAction)showAll:(id)sender
{
	[[self dockIconController] activate];
}


- (IBAction)hideAll:(id)sender
{
	[[self dockIconController] hideWindows];
}

@end
