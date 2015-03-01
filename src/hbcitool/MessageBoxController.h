//
//  MessageBoxController.h
//  hbci
//
//  Created by Stefan Schimanski on 17.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CocoaBanking;
@class CocoaBankingGui;

@interface MessageBoxController : NSWindowController {
	IBOutlet NSTextView * message_;
	IBOutlet NSButton * antwortMerken_;
	IBOutlet NSButton * button1_;
	IBOutlet NSButton * button2_;
	IBOutlet NSButton * button3_;
	IBOutlet CocoaBanking * banking_;
	IBOutlet NSImageView * zertifikatsBild_;
	IBOutlet NSImageView * euroBild_;
}

- (int)runModalMessage:(NSAttributedString *)msg title:(NSString *)title
	       button1:(NSString *)b1 button2:(NSString *)b2 button3:(NSString *)b3
	       bankingGui:(CocoaBankingGui *)banking;

- (IBAction)buttonClicked:(id)sender;

@end
