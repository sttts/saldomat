//
//  DockAppController.h
//  hbci
//
//  Created by Stefan Schimanski on 14.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DockIconControllerProtocol.h"


@interface DockAppController : NSObject<DockAppProtocol> {
	BOOL wasClickActivation_;
}

- (IBAction)preferences:(id)sender;
- (IBAction)about:(id)sender;
- (IBAction)showAll:(id)sender;
- (IBAction)hideAll:(id)sender;

@end
