//
//  ButtonPopupMenu.m
//  hbci
//
//  Created by Stefan Schimanski on 04.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "ButtonPopupMenu.h"


@implementation ButtonPopupMenu

- (void)awakeFromNib
{
	popupCell_ = [[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:YES];
	[popupCell_ setMenu:popupMenu_];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(menuClosed:)
						     name:NSMenuDidEndTrackingNotification
						   object:popupMenu_];
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:NSMenuDidEndTrackingNotification
						      object:popupMenu_];
	[popupCell_ release];
	[super dealloc];
}


- (void)mouseDown:(NSEvent *)theEvent
{
	[self highlight:YES];
	[popupCell_ performClickWithFrame:[self bounds] inView:self];
}


- (void)menuClosed:(NSNotification *)note
{
	[self highlight:NO];
}

@end
