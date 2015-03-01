//
//  LogWindowController.h
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LogWindowController : NSWindowController {
	IBOutlet NSTextView * logView_;
}

- (IBAction)clear:(id)sender;
- (NSData *)RFTDData;
- (NSTextView *)logView;

@end
