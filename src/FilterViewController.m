//
//  FilterViewController.m
//  hbci
//
//  Created by Michael on 27.04.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import "FilterViewController.h"


@implementation FilterViewController

- (void)awakeFromNib {	
	// Subview hinzufuegen
	[filterView_ addSubview:filterPrefView_];
	
	// filterPrefView verstecken!
	[filterPrefView_ setHidden:YES];
}


- (void)FilterPrefViewAusfahren {
	// FIXME: CoreAnimation einbauen
	// Startposition des filterPrefView setzen
	[filterPrefView_ setFrameOrigin:NSMakePoint(0, [filterTableMainView_ frame].size.height + [filterBuchungsEditView_ frame].size.height)];
	[filterPrefView_ setHidden:NO];
	[filterPrefView_ setFrameOrigin:NSMakePoint(0, [filterTableMainView_ frame].size.height + [filterBuchungsEditView_ frame].size.height - [filterPrefView_ frame].size.height)];
	//[filterPrefView_ setFrameOrigin:NSMakePoint(0, [filterTableMainView_ frame].size.height + [filterBuchungsEditView_ frame].size.height - 100)];
}


- (void)FilterPrefViewEinfahren {
	[filterPrefView_ setHidden:YES];
	//[filterPrefView_ setFrameOrigin:NSMakePoint(0, [filterTableMainView_ frame].size.height + [filterBuchungsEditView_ frame].size.height)];
}


- (IBAction)FilterPrefViewAusfahrenClicked:(id)sender {
	if ([sender state] == 1) { //NSOnState
		[self FilterPrefViewAusfahren];
	}
	if ([sender state] == 0) { //NSOffState
		[self FilterPrefViewEinfahren];
	}
	
}


@end
