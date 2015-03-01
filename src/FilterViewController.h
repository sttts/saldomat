//
//  FilterViewController.h
//  hbci
//
//  Created by Michael on 27.04.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FilterViewController : NSView {
	IBOutlet NSView * filterView_;
	
	// Views im filterView
	IBOutlet NSView * filterPrefView_;
	IBOutlet NSView * filterBuchungsEditView_; // beinhaltet Editfelder im grauen Bereich des filterView
	IBOutlet NSScrollView * filterTableMainView_;
}

- (void)FilterPrefViewAusfahren;
- (void)FilterPrefViewEinfahren;
- (IBAction)FilterPrefViewAusfahrenClicked:(id)sender;

@end
