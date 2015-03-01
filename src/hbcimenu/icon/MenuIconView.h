//
//  MenuIconView.h
//  hbci
//
//  Created by Stefan Schimanski on 15.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IconController;

@interface MenuIconView : NSImageView
{
	NSStatusItem * item_;
	IconController * ctrl_;
	BOOL highlighed_;
	BOOL warteAufAktivierung_;
}

- (id) initMitStatusItem:(NSStatusItem *)item undIconCtrl:(IconController *)ctrl;

- (void)setHighlighted:(BOOL)yes;
- (void)setImage:(NSImage *)img;

@end