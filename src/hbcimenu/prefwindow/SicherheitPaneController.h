//
//  SicherheitPaneController.h
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SicherheitPaneController : NSViewController {
	NSMutableArray * pins_;
}

- (IBAction)oeffneSchluesselbund:(id)sender;

@end
