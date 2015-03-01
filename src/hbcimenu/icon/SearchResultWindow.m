//
//  SearchResultWindow.m
//  hbci
//
//  Created by Stefan Schimanski on 09.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "SearchResultWindow.h"


@implementation SearchResultWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
	SearchResultWindow * result = [super initWithContentRect:contentRect
					    styleMask:NSBorderlessWindowMask
					      backing:NSBackingStoreBuffered 
						defer:NO];
	[result setBackgroundColor:[NSColor clearColor]];
	[result setAlphaValue:1.0];
	[result setOpaque:NO];
	[result setHasShadow:YES];
	
	[result setLevel:NSPopUpMenuWindowLevel];
	[result setBecomesKeyOnlyIfNeeded:YES];
	[result setFloatingPanel:YES];
	[result setWorksWhenModal:YES];
	
	return result;
}


- (BOOL) canBecomeKeyWindow
{
	return NO;
}


- (void)mouseDown:(NSEvent *)theEvent
{
	NSLog(@"mouseDown");
}

@end
