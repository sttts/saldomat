//
//  FilterAktionController.h
//  hbci
//
//  Created by Stefan Schimanski on 04.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SidebarController.h"


@interface FilterAktionController : NSViewController {
	IBOutlet NSArrayController * aktionenArray_;
	IBOutlet SidebarController * sidebar_;
	IBOutlet NSArrayController * gefilterteBuchungen_;
	
	// Controls
	IBOutlet NSButton * addButton_;
	IBOutlet NSButton * removeButton_;
	IBOutlet NSMenu * addMenu_;
	IBOutlet NSTableView * tabelle_;
	IBOutlet NSColorWell * farbeWaehler_;
	IBOutlet NSTableView * buchungsTabelle_;
	
	// Aktionsviews
	IBOutlet NSView * growlAktionView_;
	IBOutlet NSView * quickenAktionView_;
	IBOutlet NSView * csvAktionView_;
	IBOutlet NSView * grandtotalAktionView_;
	IBOutlet NSView * farbAktionView_;
	IBOutlet NSView * appleScriptAktionView_;
	IBOutlet NSView * keineAktionView_;
}

- (IBAction)neueGrowlAktion:(id)sender;
- (IBAction)neueQuickenExportAktion:(id)sender;
- (IBAction)neueCsvExportAktion:(id)sender;
- (IBAction)neueGrandtotalExportAktion:(id)sender;
- (IBAction)neueFarbAktion:(id)sender;
- (IBAction)neueAppleScriptAktion:(id)sender;

- (IBAction)entferneAktion:(id)sender;
- (IBAction)dateiWaehlen:(id)sender;
- (IBAction)aktionAufAlleAnwenden:(id)sender;

@end
