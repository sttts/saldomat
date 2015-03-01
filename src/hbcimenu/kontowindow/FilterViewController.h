//
//  FilterViewController.h
//  hbci
//
//  Created by Michael on 27.04.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@class SidebarController;


@interface FilterViewController : NSView {
	IBOutlet SidebarController * sidebarCtrl_;
	
	// Filteransicht
	IBOutlet NSView * filterView_;
	IBOutlet NSSplitView * filterSplitView_;
	
	// Subviews im filterView
	IBOutlet NSView * filterPrefMainView_;
	IBOutlet NSView * filterPrefView_;
	IBOutlet NSView * actionPrefView_;
	IBOutlet NSView * buchungsEditView_; // beinhaltet Editfelder im grauen Bereich des filterView
	IBOutlet NSView	* toolbarView_;
	
	// Views
	IBOutlet NSTextField * altHilfe_;
	IBOutlet NSSegmentedControl * aktionFilterButton_;
	IBOutlet NSTextField * summe_;
	IBOutlet NSTextField * von_;
	IBOutlet NSTextField * nach_;
	IBOutlet NSTextField * wert_;
	
	// feste Hoehen
	float toolbarHeight;
	float buchungsEditHeight;
	float prefViewHeight;
	
	// CoreAnimation
	CABasicAnimation * ersterSchieberAnimation;
	CABasicAnimation * zweiterSchieberAnimation;
	
	// Zustaende
	BOOL aktionSichtbar_;
	BOOL kriterienSichtbar_;
	
	IBOutlet NSArrayController * gefilterteBuchungen_;
}

- (IBAction)geheZurOnlineHilfe:(id)sender;
- (IBAction)filterAktionButtonClicked:(id)sender;
- (void)einfahrenClickedAnimated:(BOOL)animated;

@end


@interface DualSplitView : NSSplitView
{
}

@property double firstDividerPosition;
@property double secondDividerPosition;

@end
