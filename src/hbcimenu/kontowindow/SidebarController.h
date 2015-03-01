//
//  SidebarController.h
//  hbci
//
//  Created by Michael on 18.04.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KontoWindowController;
@class Filter;
@class FilterEditorController;
@class Konto;


@interface SidebarController : NSObject {
	IBOutlet NSView * sidebarMainView_;
	
	// Arrays
	IBOutlet NSArrayController * kontenCtrl_;
	
	// Modell
	NSString * kontenHeader_;
	NSString * filterHeader_;
	NSArray * konten_; // wir muessen die Objekte im Speicher halten
	NSArray * filters_; // wir muessen die Objekte im Speicher halten
	Filter * markierterFilter_;
	IBOutlet FilterEditorController * filterEditorCtrl_;
	
	// Views
	IBOutlet KontoWindowController * kontoWindowCtrl_;
	IBOutlet NSSplitView * splitView_;
	IBOutlet NSOutlineView * outlineView_;
	IBOutlet NSButton * removeFilterButton_;
	IBOutlet NSButton * addFilterButton_;
	
	// Bilder
	NSImage * trichterIcon_;
	NSImage * kontoIcon_;
	NSImage * proIcon_;
}

- (IBAction)addFilter:(id)sender;
- (IBAction)removeFilter:(id)sender;
- (void)selectKonto:(Konto *)konto;
- (void)selektionMitArraySync;

@property (retain) Filter * markierterFilter;

@end

@interface SidebarOutlineView : NSOutlineView {}
@end
