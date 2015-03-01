//
//  KontoMenuViewController.h
//  hbci
//
//  Created by Stefan Schimanski on 20.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Konto.h"
#import "RotGruenFormatter.h"
#import "IconController.h"

@interface KontoMenuViewController : NSViewController {
	IBOutlet Konto * konto_;
	IBOutlet NSScrollView * tableScrollView_;
	IBOutlet NSTableView * table_;
	IBOutlet NSArrayController * buchungen_;
	NSSize startViewBounds_;
	NSMenu * menu_;
	
	// Tendenzicons
	IBOutlet NSImageView * tendenzIconPositiv_;
	IBOutlet NSImageView * tendenzIconNegativ_;
	
	// je nach View
	IBOutlet NSView * viewHell_;
	IBOutlet NSView * viewDunkel_;
	IBOutlet NSButton * neuladenButton_;
	IBOutlet NSButton * neuladenButton2_;
	IBOutlet NSButton * abbrechenButton_;
	IBOutlet NSButton * abbrechenButton2_;
	IBOutlet NSButton * fehlerZeigenButton_;
	IBOutlet NSButton * fehlerZeigenButton2_;
	IBOutlet NSButton * fehlerGesehenButton_;
	IBOutlet NSButton * fehlerGesehenButton2_;
	IBOutlet NSTextField * fehlerLabel_;
	IBOutlet NSTextField * fehlerLabel2_;
	
	// Formatter
	IBOutlet RotGruenFormatter * saldoFormatter_;
	IBOutlet RotGruenFormatter * buchungFormatter_;
	
	// Testfarbe im tableView
	float textRedComp_;
	float textGreenComp_;
	float textBlueComp_;
	float textAlphaComp_;
	
}

- (id)initWithKonto:(Konto *)konto;
- (NSManagedObjectContext *)managedObjectContext;

- (IBAction)fehlerZeigenClicked:(id)sender;
- (IBAction)fehlerGesehenClicked:(id)sender;
- (IBAction)alleBuchungenZeigenClicked:(id)sender;
- (IBAction)kontoauszugHolen:(id)sender;
- (IBAction)kontoauszugAbbrechen:(id)sender;
- (IBAction)gelesenMarkieren:(id)sender;
- (IBAction)tabelleHoch:(id)sender;
- (IBAction)zuruecksetzen:(id)sender;
- (IBAction)naechsteNeueBuchungSelektieren:(id)sender;
- (IBAction)buchungOeffnen:(id)sender;
- (IBAction)feedOeffnen:(id)sender;
- (IBAction)nachiBankExportieren:(id)sender;
- (IBAction)nachQifExportieren:(id)sender;

@property (readonly) Konto * konto;
@property (retain) NSMenu * menu;

- (void)setKontoMenuViewDark:(BOOL)dark;
- (void)setSkalierung:(double)skalierung;

@end

@interface KontoMenuViewView : NSBox {
	
}
@end
