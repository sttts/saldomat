//
//  ExpertenKontoController.h
//  hbci
//
//  Created by Stefan Schimanski on 18.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ExpertenKontoController : NSWindowController {
	IBOutlet NSTextField * regexp_;
	IBOutlet NSArrayController * zweckFilter_;
	IBOutlet NSArrayController * konten_;
	IBOutlet NSArrayController * buchungen_;
	IBOutlet NSTextField * bezeichnung_;
}

- (IBAction)sheetSchliessen:(id)sender;
- (IBAction)filternClicked:(id)sender;
- (IBAction)zweckFilterLoeschen:(id)sender;
- (IBAction)neuerZweckFilter:(id)sender;

@property (retain) NSArrayController * konten;

@end
