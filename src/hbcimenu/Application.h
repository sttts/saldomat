//
//  Application.h
//  hbci
//
//  Created by Stefan Schimanski on 18.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DockIconController.h"


@interface Application : NSApplication {
	IBOutlet NSArrayController * konten_;
}

@property (readonly) NSArray * kontenArray;

@end
