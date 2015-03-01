//
//  IconController.h
//  hbcimenu
//
//  Created by Stefan Schimanski on 06.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KontoWindowController.h"


@class IconController;
@class MenuIconView;
@class RotGruenFormatter;
@class SyncedAuthorizationView;


@interface SearchView : NSView
{}
@end


@interface SearchTextField : NSSearchField
{}
@end


@interface ToolbarView : NSView
{}
@end


@interface MehrButton : NSButton
{
	IBOutlet IconController * ctrl_;
}
@end


@interface IconController : NSResponder {
	// Icon im NSStatusBar
	NSStatusItem * statusItem_;
	MenuIconView * iconView_;
	double iconAngle_;
	NSTimer * iconTimer_;
	NSStatusBar * bar_;
	
	// Menues
	IBOutlet NSMenu * menu_;
	IBOutlet NSArrayController * konten_;
	NSMutableArray * kontoMenuViewCtrls_;
	BOOL menuOffenHalten_;
	
	// KontoMenuItem
	NSMutableArray * kontoMenuItemViewCtrls_;
	
	// Fehlericon
	BOOL fehlerIconAnzeigen_;
	NSImage * fehlerIcon_;
	NSImage * iconSchloss_;
	
	// Saldo-Warnung
	NSImage * saldoWarnungIcon_;
	BOOL saldoWarnungAktiv_;
	
	// Zaehler
	int posBuchungsZaehler_;
	int negBuchungsZaehler_;
	NSTimer * updateShotTimer_;
	NSTimer * alsNichtNeuMarkierTimer_;
	
	// Suche
	IBOutlet NSArrayController * searchBuchungen_;
	IBOutlet SearchTextField * searchField_;
	IBOutlet NSView * searchView_;
	IBOutlet NSWindow * searchResultsWindow_;
	IBOutlet NSTableView * searchTable_;
	IBOutlet NSScrollView * searchScrollView_;
	NSSize origSearchSize_;
	
	// Schloss
	IBOutlet NSView * schlossView_;
	
	// SummenItem
	IBOutlet NSView * summenView_;
	IBOutlet NSTextField *summenWert_;
	IBOutlet RotGruenFormatter * summenFormatter_;
	
	// Toolbar
	IBOutlet NSView * toolbarView_;
	IBOutlet NSButton * mehrButton_;
	IBOutlet NSMenu * mehrMenu_;
	IBOutlet NSButton * detailsFilterButton_;
	NSSize origToolbarSize_;
	
	IBOutlet KontoWindowController * kontoWindowCtrl_;
	IBOutlet NSFormatter * saldoFormatter_;
	IBOutlet NSNumberFormatter * saldoImMenuFormatter_;
}

- (IBAction)updateIcon:(id)sender;
- (IBAction)oeffneMenu:(id)sender;
- (IBAction)saldoClicked:(id)sender;

- (IBAction)geheZurOnlineHilfe:(id)sender;
- (IBAction)zeigePref:(id)sender;
- (IBAction)zeigeDebug:(id)sender;
- (IBAction)zeigeMehrMenu:(id)sender;
- (IBAction)zeigeKontenUndFilter:(id)sender;
- (IBAction)holeKontoauszuege:(id)sender;
- (IBAction)lock:(id)sender;
- (IBAction)unlock:(id)sender;

- (void)showSearchResult;

@property (readonly) MenuIconView * iconView;

@end


