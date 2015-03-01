//
//  MenuIconView.m
//  hbci
//
//  Created by Stefan Schimanski on 15.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "MenuIconView.h"

#import "AppController.h"
#import "debug.h"
#import "DockIconController.h"
#import "IconController.h"


@implementation MenuIconView

- (id) initMitStatusItem:(NSStatusItem *)item undIconCtrl:(IconController *)ctrl
{
	self = [super init];
	item_ = item;
	ctrl_ = ctrl;
	highlighed_ = NO;
	warteAufAktivierung_ = NO;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(aktiviert:) 
						     name:NSApplicationDidBecomeActiveNotification
						   object:nil];
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}



- (void)drawRect:(NSRect)rect
{
	// A known bug with screen flashing and updating: http://www.cocoabuilder.com/archive/message/cocoa/2008/4/22/204861
	NSDisableScreenUpdates();
	
	[item_ drawStatusBarBackgroundInRect:[self frame] withHighlight:highlighed_];
	[super drawRect:rect];
	
	NSEnableScreenUpdates();
}


- (void)mouseDown:(NSEvent *)theEvent 
{
	[self setHighlighted:YES];
	
	// sind wir im Vordergrund?
	if ([NSApp isActive]) {
		// Fenster nach vorne bringen
		[[theAppCtrl dockIconController] activate];
		
		[ctrl_ oeffneMenu:self];
	} else {
		// aktivieren und auf Notification warten
		warteAufAktivierung_ = YES;
		[[theAppCtrl dockIconController] activate];
	}
}


- (void)setHighlighted:(BOOL)yes
{
	highlighed_ = yes;
	[self setNeedsDisplay:YES];
}


- (void)aktiviert:(NSNotification *)aNotification
{
	if (!warteAufAktivierung_)
		return;
	warteAufAktivierung_ = NO;
	NSLog(@"applicationDidBecomeActive");
	
	// Menue oeffnen
	[ctrl_ oeffneMenu:self];
}


- (void)setImage:(NSImage *)img
{
	[super setImage:img];
	[self setFrameSize:[img size]];
}


@end
