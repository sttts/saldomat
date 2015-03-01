//
//  Application.m
//  hbci
//
//  Created by Stefan Schimanski on 18.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Application.h"

#import "AppController.h"
#import "AuthorizationController.h"
#import "debug.h"


@implementation Application

- (id)init
{
	self = [super init];

	// NSConnection-Ports registrieren fuer die NSRunLoop, so dass
	// sie auch waehrend modaler Fenster und bei offenen Menues laufen.
	[[NSRunLoop currentRunLoop] addPort:[[NSConnection defaultConnection] receivePort] forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addPort:[[NSConnection defaultConnection] receivePort] forMode:NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addPort:[[NSConnection defaultConnection] sendPort] forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addPort:[[NSConnection defaultConnection] sendPort] forMode:NSModalPanelRunLoopMode];
	
	return self;
}


- (NSInteger)runModalForWindow:(NSWindow *)aWindow
{
	// Dock-Icon anzeigen und aktivieren
	if (![self isActive])
		[self activateIgnoringOtherApps:YES];
	[DockIconController showDockIcon:self];
	
	return [super runModalForWindow:aWindow];
}


- (NSModalSession)beginModalSessionForWindow:(NSWindow *)aWindow
{
	// Dock-Icon anzeigen und aktivieren
	if (![self isActive])
		[self activateIgnoringOtherApps:YES];
	[DockIconController showDockIcon:self];

	return [super beginModalSessionForWindow:aWindow];
}


- (NSArray *)kontenArray
{
	return [konten_ arrangedObjects];
}

@end
