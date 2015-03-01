//
//  UpdateController.h
//  hbci
//
//  Created by Stefan Schimanski on 11.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SUUpdater;

@interface UpdateController : NSObject {
	IBOutlet SUUpdater * updater_;
	IBOutlet NSArrayController * konten_;
	
	NSInvocation * wartendesUpdate_;
}

- (IBAction)updateStarten:(id)sender;

@end
