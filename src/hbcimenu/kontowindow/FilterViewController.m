//
//  FilterViewController.m
//  hbci
//
//  Created by Michael on 27.04.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import "FilterViewController.h"

#import "Buchung.h"
#import "debug.h"
#import "Filter.h"
#import "Konto.h"
#import "SidebarController.h"
#import "StringFarbeTransformer.h"
#import "urls.h"


@interface FilterViewController(Private)

- (void)updateViewsFuerFilter:(Filter *)filter;

@end


@implementation FilterViewController

- (void)awakeFromNib {	
	//NSSize s = [filterPrefMainView_ frame].size;
	NSSize s = NSMakeSize([filterPrefView_ frame].size.width, 250);
	[filterPrefMainView_ setFrameSize:s];
	[filterPrefView_ setFrameSize:s];
	[actionPrefView_ setFrameSize:s];
	
	// Subview hinzufuegen und Positionieren
	[filterPrefMainView_ addSubview:filterPrefView_];
	[filterPrefMainView_ addSubview:actionPrefView_];
	
	// PrefViews verstecken!
	[filterPrefView_ setHidden:YES];
	[actionPrefView_ setHidden:YES];
	aktionSichtbar_ = NO;
	kriterienSichtbar_ = NO;
	
	// feste Groessen (im IB festgelegt)
	toolbarHeight = [toolbarView_ frame].size.height;
	//buchungsEditHeight = [buchungsEditView_ frame].size.height;
	prefViewHeight = [filterPrefMainView_ frame].size.height; // angenommen: FilterPrefView und AktionPrefView gleich hoch!
	
	// Anfangsposition der SplitView-Schieber setzen 
	[filterSplitView_ setPosition:-[filterSplitView_ dividerThickness] ofDividerAtIndex:0];
	//[[filterSplitView_ animator] setPosition:([filterSplitView_ frame].size.height
	//					  - buchungsEditHeight
	//					  - [filterSplitView_ dividerThickness]) ofDividerAtIndex:1];
	
	// Animation definieren
	ersterSchieberAnimation = [CABasicAnimation animation];
	[ersterSchieberAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
	[ersterSchieberAnimation setDuration:0.2f];
	
	//zweiterSchieberAnimation = [CABasicAnimation animation];
	//[zweiterSchieberAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
	//[zweiterSchieberAnimation setDuration:0.2f];	
	
	// Animationen setzen
	NSDictionary * animations = [NSDictionary dictionaryWithObjectsAndKeys:
				     ersterSchieberAnimation, @"firstDividerPosition",
				     //zweiterSchieberAnimation, @"secondDividerPosition",
				     nil];
	[filterSplitView_ setAnimations:animations];
	
//	[actionPrefView_ setWantsLayer:YES];
//	[filterPrefView_ setWantsLayer:YES];
	
	// Auf Selektion eines Filters warten in der Sidebar
	[sidebarCtrl_ addObserver:self forKeyPath:@"markierterFilter" options:NSKeyValueObservingOptionNew context:@"sidebarCtrl.markierterFilter"];
	[self updateViewsFuerFilter:[sidebarCtrl_ markierterFilter]];
		
}


- (IBAction)geheZurOnlineHilfe:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_HILFE_URL_FILTER]];
}


- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
	NSLog(@"resizeSubviewsWithOldSize");
	
	// eingestellte SplitViewgroesse laden
	NSRect newFrame = [sender frame];
	
	// eingestellte Groesse des 1. Views laden
	NSView *firstView = [[filterSplitView_ subviews] objectAtIndex:0];
	NSRect firstFrame = [firstView frame];
	
	// eingestellte Groesse des 2. Views laden
	NSView *secondView = [[filterSplitView_ subviews] objectAtIndex:1];
	NSRect secondFrame = [secondView frame];
	
	// eingestellte Groesse des 3. Views laden
	//NSView *thirdView = [[filterSplitView_ subviews] objectAtIndex:2];
	//NSRect thirdFrame = [thirdView frame];

	// Dicke des Schiebers laden
	float Schieberdicke = [filterSplitView_ dividerThickness];
	
	// Aenderungen vornehmen
	// btnFilterPref_ oder btnActionPref_ ON
	if ([aktionFilterButton_ isSelectedForSegment:0] || [aktionFilterButton_ isSelectedForSegment:1]) {
		firstFrame.size.height = prefViewHeight;
		secondFrame.size.height = newFrame.size.height - prefViewHeight - Schieberdicke;
		//thirdFrame.size.height = 0;
	} else {
		firstFrame.size.height = 0;
		secondFrame.size.height = newFrame.size.height - buchungsEditHeight - Schieberdicke;
		//thirdFrame.size.height = buchungsEditHeight;
	}
	
	// Breite setzen
	firstFrame.size.width = newFrame.size.width;
	secondFrame.size.width = newFrame.size.width;	
	//thirdFrame.size.width = newFrame.size.width;
	
	// Positionen setzen
	firstFrame.origin.y = 0;
	secondFrame.origin.y = firstFrame.size.height + Schieberdicke;
	//thirdFrame.origin.y = firstFrame.size.height + secondFrame.size.height + 2* Schieberdicke;

	// neue Frames setzen
	[firstView setFrame:firstFrame];
	[secondView setFrame:secondFrame];
	//[thirdView setFrame:thirdFrame];
}


- (void)aktionClickedAnimated:(BOOL)animated
{
	[filterPrefView_ setHidden:YES];
	[actionPrefView_ setHidden:NO];
	
	// Splitter setzen
	id view = filterSplitView_;
	if (animated)
		view = [view animator]; 
	[view setFirstDividerPosition:prefViewHeight];
	
	// Buchungseditor anzeigen, wenn Panel wirklich ausfaehrt
	//if (!kriterienSichtbar_)
	//	[view setSecondDividerPosition:[filterSplitView_ frame].size.height];
	
	// Zustand setzen
	[aktionFilterButton_ setSelected:NO forSegment:0];
	[aktionFilterButton_ setSelected:YES forSegment:1];
	aktionSichtbar_ = YES;
	kriterienSichtbar_ = NO;	
	[[sidebarCtrl_ markierterFilter] setAktiverView:FilterAktiverAktionenView];
	[altHilfe_ setHidden:YES];
}


- (void)kriterienClickedAnimated:(BOOL)animated
{
	[filterPrefView_ setHidden:NO];
	[actionPrefView_ setHidden:YES];

	// beide Splitter anpassen, wenn Panel wirklich ausfaehrt
	if (!aktionSichtbar_) {
		id view = filterSplitView_;
		if (animated)
			view = [view animator]; 
		[view setFirstDividerPosition:prefViewHeight];
		//[view setSecondDividerPosition:[filterSplitView_ frame].size.height];
	}
	
	// Zustand setzen
	[aktionFilterButton_ setSelected:YES forSegment:0];
	[aktionFilterButton_ setSelected:NO forSegment:1];
	aktionSichtbar_ = NO;
	kriterienSichtbar_ = YES;
	[[sidebarCtrl_ markierterFilter] setAktiverView:FilterAktiverKriterienView];
	[altHilfe_ setHidden:NO];
}


- (void)einfahrenClickedAnimated:(BOOL)animated
{
	id view = filterSplitView_;
	if (animated)
		view = [view animator]; 
	[view setFirstDividerPosition:-[filterSplitView_ dividerThickness]];
	//[view setSecondDividerPosition:
	// [filterSplitView_ frame].size.height - buchungsEditHeight - [filterSplitView_ dividerThickness]];	
	
	// Zustand setzen
	[aktionFilterButton_ setSelected:NO forSegment:0];
	[aktionFilterButton_ setSelected:NO forSegment:1];
	aktionSichtbar_ = NO;
	kriterienSichtbar_ = NO;
	[[sidebarCtrl_ markierterFilter] setAktiverView:FilterKeinAktiverView];
	[altHilfe_ setHidden:YES];
}


- (IBAction)filterAktionButtonClicked:(id)sender {
	BOOL aktionClicked = [aktionFilterButton_ isSelectedForSegment:1] && !aktionSichtbar_;
	BOOL kriterienClicked = [aktionFilterButton_ isSelectedForSegment:0] && !kriterienSichtbar_;
	
	if (kriterienClicked)
		[self kriterienClickedAnimated:YES];
	else if (aktionClicked)
		[self aktionClickedAnimated:YES];
	else
		[self einfahrenClickedAnimated:YES];
}


- (void)updateViewsFuerFilter:(Filter *)filter
{
	if (filter == nil)
		return;
	
	switch ([filter aktiverView]) {
		case FilterAktiverKriterienView:
			[self kriterienClickedAnimated:NO];
			break;
		case FilterAktiverAktionenView:
			[self aktionClickedAnimated:NO];
			break;
		default:
			[self einfahrenClickedAnimated:NO];
			break;
	}
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	[self updateViewsFuerFilter:[sidebarCtrl_ markierterFilter]];
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (![aCell isKindOfClass:[NSTextFieldCell class]])
		return;
	NSTextFieldCell * tcell = aCell;
	
	// Farbe uebertragen
	Buchung * b = [[gefilterteBuchungen_ arrangedObjects] objectAtIndex:rowIndex];
	NSString * farbe = [b farbe];
	if (farbe)
		[tcell setTextColor:[farbe colorOfAnHexadecimalColorString]];
	else
		[tcell setTextColor:[NSColor blackColor]];
}


- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin 
	 ofSubviewAt:(NSInteger)offset
{
	if (offset == 0) {
		// Aktion-View nicht skalierbar
		if (aktionSichtbar_) {
			float momentaneHoehe = [filterPrefMainView_ frame].size.height;
			return MIN(prefViewHeight, momentaneHoehe); // MIN, um den Animator nicht einzuschraenken
		}
	}
	
	// der untere nicht zu weit nach oben
	if (offset == 1)
		return [filterSplitView_ frame].size.height - buchungsEditHeight;
	
	return proposedMin;
}


- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax 
	 ofSubviewAt:(NSInteger)offset
{
	// oberer Splitter
	if (offset == 0) {
		// Nicht aenderbar, wenn kein View aktiv ist
		if (!aktionSichtbar_ && !kriterienSichtbar_)
			return [filterPrefMainView_ frame].size.height;
		
		// Aktion-View auch konstant lassen
		else if (aktionSichtbar_) {
			float momentaneHoehe = [filterPrefMainView_ frame].size.height;
			return MAX(momentaneHoehe, prefViewHeight); // MAX, um den Animator nicht einzuschraenken
		}
	}
	
	return proposedMax;
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	// Summe der markierten Buchungen anzeigen
	NSArray * markierte = [gefilterteBuchungen_ selectedObjects];
	if ([markierte count] > 1) {
		NSLog(@"Berechne Summe fuer %d Buchungen", [markierte count]);
		[summe_ setHidden:NO];
		NSDecimalNumber * wert = [NSDecimalNumber decimalNumberWithString:@"0.00"];
		for (Buchung * b in markierte) {
			wert = [wert decimalNumberByAdding:[b wert]];
		}
		
		if ([wert doubleValue] > 0) {
			[von_ setHidden:NO];
			[nach_ setHidden:YES];
		} else {
			[von_ setHidden:YES];
			[nach_ setHidden:NO];
		}
		
		[summe_ setObjectValue:wert];
		[wert_ setHidden:YES];
	} else {
		[summe_ setHidden:YES];
		[wert_ setHidden:NO];
	}
}

@end


@implementation DualSplitView

- (double)firstDividerPosition
{
	return [[[self subviews] objectAtIndex:0] frame].size.height;
}


- (double)secondDividerPosition
{
	return [[[self subviews] objectAtIndex:2] frame].origin.y - [self dividerThickness];
}


- (void)setFirstDividerPosition:(double)pos
{
	[self setPosition:pos ofDividerAtIndex:0];
}


- (void)setSecondDividerPosition:(double)pos
{
	[self setPosition:pos ofDividerAtIndex:1];
}

@end

