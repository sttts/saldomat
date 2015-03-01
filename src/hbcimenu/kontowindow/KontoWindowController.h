//
//  KontoWindowController.h
//  hbci
//
//  Created by Stefan Schimanski on 13.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Konto.h"
#import "RotGruenFormatter.h"

@class Buchung;
@class FilterEditorController;
@class FilterViewController;
@class SidebarController;

@interface KontoWindowController : NSWindowController {
	// Arrays
	IBOutlet NSArrayController * kontenCtrl_;
	IBOutlet NSArrayController * buchungsCtrl_;
	
	IBOutlet FilterEditorController * filterEditorCtrl_;
	IBOutlet FilterViewController * filterViewCtrl_;

	IBOutlet RotGruenFormatter * buchungsWertFormatter_;
	
	IBOutlet NSSplitView * splitView_;
	IBOutlet NSTableView * table_;
	IBOutlet NSView * kontoView_;
	
	IBOutlet NSView * filterView_;
	IBOutlet NSTableView * actionTableView_;
	
	IBOutlet NSView * sidebarView_;
	IBOutlet NSView * contentView_;
	IBOutlet NSTextField * summe_;
	IBOutlet NSTextField * von_;
	IBOutlet NSTextField * nach_;
	IBOutlet NSTextField * wert_;
	
	IBOutlet SidebarController * sidebarCtrl_;
	
	
}

- (void)showWithKonto:(Konto *)konto;
- (void)showWithBuchung:(Buchung *)buchung;
- (NSManagedObjectContext *)managedObjectContext;

- (IBAction)showKontoView:(id)sender;
- (IBAction)showFilterView:(id)sender;
- (BOOL)kontoViewIsSichtbar;
- (BOOL)filterViewIsSichtbar;


@end
