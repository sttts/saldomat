//
//  ErrorWindowController.h
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Konto;

@interface ErrorWindowController : NSWindowController {
	// Fehlermeldung
	IBOutlet NSTextView * errorMessageText_;
	IBOutlet NSScrollView * errorScrollView_;
	
	// Verbindungsprotokoll
	IBOutlet NSScrollView * errorLogView_;
	IBOutlet NSTextView * errorLogText_;
	
	IBOutlet NSButton * btnErrorProtokollAusfahren;
	
	NSError * error_;
	NSData * data_;
	Konto * konto_;
	BOOL kritisch_;
}

- (id)initWithError:(NSError *)error forKonto:(Konto *)konto withLogRTFDData:(NSData *)data;
- (void)updateError:(NSError *)error forKonto:(Konto *)konto withLogRTFDData:(NSData *)data;

- (IBAction)closeClicked:(id)sender;
- (IBAction)showPrefClicked:(id)sender;
- (IBAction)errorWindow_protokollausfahren:(id)sender;

- (NSString *)fehlerMeldung;

@property BOOL kritischerFehler;

@end
