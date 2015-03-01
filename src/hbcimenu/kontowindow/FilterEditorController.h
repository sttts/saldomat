//
//  FilterEditorController.h
//  hbci
//
//  Created by Stefan Schimanski on 21.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SidebarController;

@interface FilterEditorController : NSObject {
	IBOutlet NSPredicateEditor * predEditor_;
	IBOutlet NSArrayController * kontenArray_;
	IBOutlet NSArrayController * gefilterteBuchungenArray_;
	IBOutlet SidebarController * sidebarCtrl_;
	IBOutlet NSTableView * table_;
	
	int lockSetPredicate_;
	NSArray * anfangsRowTemplates_;
}

- (IBAction)predicateEditorChanged:(id)sender;

@property (readonly) NSPredicateEditor * predEditor;

@end
