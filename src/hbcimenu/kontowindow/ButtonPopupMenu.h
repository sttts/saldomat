//
//  ButtonPopupMenu.h
//  hbci
//
//  Created by Stefan Schimanski on 04.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// alles von http://www.jimmcgowan.net/Site/Blog/Entries/2007/8/27_Adding_a_Menu_to_an_NSButton.html

@interface ButtonPopupMenu : NSButton {
	IBOutlet NSMenu * popupMenu_;
	NSPopUpButtonCell * popupCell_;
}

@end
