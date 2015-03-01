//
//  PinWindowController.h
//  hbcipref
//
//  Created by Stefan Schimanski on 30.03.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CocoaBanking;

@interface InputWindowController : NSWindowController {
	IBOutlet NSTextField * description_;
}

- (void)setDescription:(NSAttributedString *)description;
- (void)setDescriptionWith:(NSString *)string;
- (IBAction)cancelClicked:(id)sender;
- (IBAction)okClicked:(id)sender;

@end


@interface NormalInputWindowController : InputWindowController {
	IBOutlet NSTextField * input_;
}

- (id)init;
- (NSString *)input;

@end


@interface PinWindowController : InputWindowController {
	IBOutlet NSSecureTextField * pin_;
	IBOutlet NSButton * savePin_;
	CocoaBanking * banking_;
	
	// Sicherheitshinweis-Sheet
	IBOutlet NSWindow * sicherheitsWindowSheet_;
	IBOutlet NSButton * akzeptierenButton_;
	IBOutlet NSButton * abbrechenButton_;
	BOOL ichHabeEsGelesen;
}

- (id)initWithCocoaBanking:(CocoaBanking *)banking;
- (NSString *)readPinAndClear;
- (BOOL)shouldSavePin;

- (IBAction)sheetSchliessen:(id)sender;

@end