//
//  DockIconController.h
//  hbci
//
//  Created by Stefan Schimanski on 14.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DockIconControllerProtocol.h"

extern NSString * DockIconControllerDidActivateNotification;
extern NSString * DockIconControllerWillActivateNotification;

@interface DockIconController : NSObject<DockIconControllerProtocol> {
}

+ (IBAction)showDockIcon:(id)sender;
+ (IBAction)hideDockIcon:(id)sender;
+ (void)dockIconEvtlSchliessen;

@end


@interface DockWindow : NSWindow

- (void)awakeFromNib;

@end
