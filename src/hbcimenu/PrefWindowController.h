//
//  PrefWindow.h
//  hbcimenu
//
//  Created by Stefan Schimanski on 23.03.08.
//  Copyright (c) 2008 1stein.org. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

#import "HbciToolLoader.h"
#import "Konto.h"

@class KontenPaneController;
@class SyncedAuthorizationView;

@interface PrefWindowController : NSWindowController {
	IBOutlet NSButton * autoloadCheckbox_;
	IBOutlet KontenPaneController * kontenPane_;
	IBOutlet NSPopUpButton * intervall_;
	IBOutlet NSTextField * version_;
	IBOutlet NSDrawer * kontenDrawer_;
	
	// Verbindung mit Views
	IBOutlet NSView * mainView_;
	IBOutlet NSView * aboutView_;
	IBOutlet NSView * allgemeinView_;
	IBOutlet NSView * kontenView_;
	IBOutlet NSView * sicherheitView_;
	IBOutlet NSView * feedView_;
	IBOutlet NSView * updateView_;
	NSArray * views_;
	NSArray * toolbarItems_;
	IBOutlet NSImageView * betaView_;
	IBOutlet NSButton * betaLaden_;
	IBOutlet NSTextView * betaLadenText_;
	IBOutlet SyncedAuthorizationView * allgemeinSchloss_;
	IBOutlet SyncedAuthorizationView * kontenSchloss_;
	IBOutlet SyncedAuthorizationView * feedSchloss_;
	IBOutlet NSView * kontenBlz_;
	IBOutlet NSView * kontenKonto_;
	IBOutlet NSView * kontenUnterkonto_;
	IBOutlet NSView * kontenLimit_;

	// Verbindung zu ToolbarItems
	IBOutlet NSToolbarItem * toolbarItemAbout_;
	IBOutlet NSToolbarItem * toolbarItemAllgemein_;
	IBOutlet NSToolbarItem * toolbarItemKonten_;
	IBOutlet NSToolbarItem * toolbarItemSicherheit_;
	IBOutlet NSToolbarItem * toolbarItemFeed_;
	IBOutlet NSToolbarItem * toolbarItemUpdate_;
	IBOutlet NSToolbarItem * toolbarItemLizenz_;

	// je nach Lizenz
	IBOutlet NSControl * exportMethode_;
	IBOutlet NSControl * exportMethodePlacebo_;
	IBOutlet NSControl * exportPro_;
	IBOutlet NSControl * exportButton_;
	IBOutlet NSControl * exportRechtesPro_;
	IBOutlet NSControl * rssButton_;
	IBOutlet NSControl * feedPro_;
	IBOutlet NSControl * feedPort_;
	IBOutlet NSButton * feedEnabled_;
	IBOutlet NSControl * feedGelesen_;
}

- (IBAction)clickAbout:(id)sender;
- (IBAction)clickAllgemein:(id)sender;
- (IBAction)clickKonten:(id)sender;
- (IBAction)clickUpdate:(id)sender;
- (IBAction)clickSicherheit:(id)sender;
- (IBAction)clickFeed:(id)sender;

- (IBAction)startUpdate:(id)sender;
- (IBAction)neuesKonto:(id)sender;
- (IBAction)geheZurHomepage:(id)sender;
- (IBAction)geheZuHBCIToolQuellen:(id)sender;
- (IBAction)unlock:(id)sender;
- (IBAction)lock:(id)sender;

@property (readonly) BOOL verschlossen;
@property (readonly) BOOL pseudoSchloss;

@end
