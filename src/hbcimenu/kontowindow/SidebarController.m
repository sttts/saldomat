//
//  SidebarController.m
//  hbci
//
//  Created by Michael on 18.04.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "SidebarController.h"

#import "AppController.h"
#import "debug.h"
#import "Filter.h"
#import "FilterEditorController.h"
#import "ImageAndTextCell.h"
#import "KontoWindowController.h"
#import "Konto.h"
#import "ZaehlerImage.h"


@implementation SidebarController


- (void)filterButtonsAnAus
{
	[removeFilterButton_ setEnabled:markierterFilter_ != nil];
	[addFilterButton_ setEnabled:[konten_ count] > 0];
}


- (void)selektionMitArraySync
{
	long sel = NSNotFound;
	if ([kontoWindowCtrl_ kontoViewIsSichtbar]) {
		// Kontoansicht => Selektiertes Konto suchen
		long ki = [kontenCtrl_ selectionIndex];
		if (ki != NSNotFound) {
			Konto * konto = [[kontenCtrl_ arrangedObjects] objectAtIndex:ki];
			sel = [outlineView_ rowForItem:konto];
		}
	} else if (markierterFilter_) {
		// Filter wieder markieren
		sel = [outlineView_ rowForItem:markierterFilter_];
	}
	
	// Versuchen was zu markieren
	if (sel == NSNotFound) {
		if ([konten_ count]) {
			[kontoWindowCtrl_ showKontoView:self];
			sel = [outlineView_ rowForItem:[konten_ objectAtIndex:0]];
		} if ([filters_ count]) {
			[kontoWindowCtrl_ showFilterView:self];
			sel = [outlineView_ rowForItem:[filters_ objectAtIndex:0]];
		} else
			// nix da zum Markieren
			[kontoWindowCtrl_ showKontoView:self];
			
	}
	
	if (sel == NSNotFound) {
		NSLog(@"Sidebar: Selektion nicht moeglich");
	} else {
		// neue Selektion setzen
		[outlineView_ selectRowIndexes:[NSIndexSet indexSetWithIndex:sel] byExtendingSelection:NO];
		//	[outlineView_ selectRow:sel byExtendingSelection:NO]; Deprecated in 10.3
	}
	
}


- (id) init
{
	self = [super init];
	
	konten_ = nil;
	filters_ = nil;
	kontenHeader_ = nil;
	filterHeader_ = nil;
	markierterFilter_ = nil;
	
	return self;
}


- (void)awakeFromNib
{
	NSLog(@"SidebarController awakeFromNib");
	
	// Sortieren nach "order"
	[kontenCtrl_ setSortDescriptors:
	 [NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES] autorelease]]];
	
	// Kopien im Speicher halten (laut Docs von NSOutlineView noetig)
	[konten_ release];
	konten_ = [[kontenCtrl_ arrangedObjects] copy];

	[filters_ release];
	NSArray * sharedFilters = [[theAppCtrl sharedFilters] filters];
	filters_ = [sharedFilters copy];
	
	// Observer erstellen, um neue Konten zu sehen
	[kontenCtrl_ addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew context:@"kontenCtrl.arrangedObjects"];
	[[theAppCtrl sharedFilters] addObserver:self forKeyPath:@"filters" options:NSKeyValueObservingOptionNew context:@"sharedFilters.filters"];
	[kontenCtrl_ addObserver:self forKeyPath:@"selection" options:NSKeyValueObservingOptionNew context:@"kontenCtrl.selection"];
	
	// Wurzeln
	kontenHeader_ = [[NSLocalizedString(@"Accounts", nil) uppercaseString] retain];
	filterHeader_ = [[NSLocalizedString(@"Filters and Actions", nil) uppercaseString] retain];
		
	// Kosmetik
	[outlineView_ setAutosaveExpandedItems:NO];
	[outlineView_ setIndentationPerLevel:20.0];

	// Icons laden
	trichterIcon_ = [[NSImage imageNamed:@"Trichter"] retain];
	kontoIcon_ = [[NSImage imageNamed:@"einKonto"] retain];
	[trichterIcon_ setSize:NSMakeSize(16, 16)];
	[kontoIcon_ setSize:NSMakeSize(16, 16)];
	proIcon_ = [[NSImage imageNamed:@"pro.png"] copy];
	[proIcon_ setScalesWhenResized:YES];
	[proIcon_ setSize:NSMakeSize([proIcon_ size].width * 2 / 3, [proIcon_ size].height * 2 / 3)];
	
	// Anfangsanzeigzustand herstellen
	[outlineView_ reloadData];
	[self selektionMitArraySync];
	[self filterButtonsAnAus];

	// Lizenzeingabe mitbekommen
	[addFilterButton_ setHidden:[[theAppCtrl standardVersion] boolValue]];
	[removeFilterButton_ setHidden:[[theAppCtrl standardVersion] boolValue]];
}


- (void)dealloc
{
	[konten_ release];
	[filters_ release];
	[kontenHeader_ release];
	[filterHeader_ release];
	[trichterIcon_ release];
	[kontoIcon_ release];
	[proIcon_ release];
	[super dealloc];
}


- (BOOL)tryToSelectFilter:(Filter *)filter
{
	NSLog(@"Will select filter %@", [filter title]);
	
	// Praedikat setzen im Editor
	@try {
		[self setMarkierterFilter:filter];
		
		// Filter-View zeigen
		[kontoWindowCtrl_ showFilterView:self];
		[self filterButtonsAnAus];

	}
	@catch (NSException * e) {
		NSLog(@"Selection failed. Refused: %@", [e description]);
		[self setMarkierterFilter:nil];
		
		// Selektion ablehnen
		return NO;
	}
	
	return YES;
}


- (void)selectKonto:(Konto *)konto
{
	[self setMarkierterFilter:nil];
	NSLog(@"Selected Konto %@", [konto bezeichnung]);
	
	// Konto im ArrayController selektieren
	[kontenCtrl_ setSelectedObjects:[NSArray arrayWithObject:konto]];
	
	// Konto-View zeigen
	[kontoWindowCtrl_ showKontoView:self];
	[self filterButtonsAnAus];
	[self selektionMitArraySync];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	// nichts markiert?
	if ([outlineView_ selectedRow] == -1) {
		[self selektionMitArraySync];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	NSLog(@"sidebar should select");
	
	// Wurzeln nicht markierbar machen
	if ([item isKindOfClass:[NSString class]])
		return NO;

	// Konto selektiert?
	if ([item isKindOfClass:[Konto class]])
		[self selectKonto:(Konto *)item];
	else if ([item isKindOfClass:[Filter class]])
		return [self tryToSelectFilter:item];
	
	return YES;
}


- (void)lizenzGeaendert:(NSNotification *)notification
{
	[outlineView_ reloadData];
	[self selektionMitArraySync];
	[self filterButtonsAnAus];
	[addFilterButton_ setHidden:[[theAppCtrl standardVersion] boolValue]];
	[removeFilterButton_ setHidden:[[theAppCtrl standardVersion] boolValue]];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	if ([(id)context isKindOfClass:[NSString class]]) {
		if ([(NSString *)context compare:@"kontenCtrl.arrangedObjects"] == 0) {
			NSLog(@"SidebarController Konten geaendert");
			
			// Kopien im Speicher halten (laut Docs von NSOutlineView noetig)
			[konten_ release];
			konten_ = [[kontenCtrl_ arrangedObjects] copy];

			// Bezeichnung der Konten beobachten
			for (Konto * konto in [kontenCtrl_ arrangedObjects]) {
				[konto addObserver:self forKeyPath:@"bezeichnung" options:NSKeyValueObservingOptionNew context:konto];
				[konto addObserver:self forKeyPath:@"neueBuchungen" options:NSKeyValueObservingOptionNew context:konto];
			}
			
			// Konten neuzeichn
			[outlineView_ reloadData];
			[self selektionMitArraySync];
			[self filterButtonsAnAus];
		} else if ([(NSString *)context compare:@"kontenCtrl.selection"] == 0) {
			[self selektionMitArraySync];
		} else if ([(NSString *)context compare:@"sharedFilters.filters"] == 0) {
			NSLog(@"SidebarController Filter geaendert");
			
			// Kopien im Speicher halten (laut Docs von NSOutlineView noetig)
			[filters_ release];
			filters_ = [[[theAppCtrl sharedFilters] filters] copy];
			
			// Makierung noch dabei?
			if (markierterFilter_ && [filters_ indexOfObject:markierterFilter_] == NSNotFound)
				[self setMarkierterFilter:nil];
			
			// Konten neuzeichnen
			[outlineView_ reloadData];
			[self selektionMitArraySync];
			[self filterButtonsAnAus];
		}
	} else {
		// Konto geaendert => neuzeichnen
		[outlineView_ reloadItem:context reloadChildren:YES];
	}
}


- (BOOL)outlineView:(NSOutlineView *)sender isGroupItem:(id)item
{
	// Wurzeln sind GroupItems
	if ([item isKindOfClass:[NSString class]])
		return YES;
	else
		return NO;
}


- (id)outlineView:(NSOutlineView *)ov child:(int)index ofItem:(id)item 
{
	if (item == kontenHeader_) {
		// Konto zurueckgeben
		if (index >= [[kontenCtrl_ arrangedObjects] count])
			return nil;
		return [[kontenCtrl_ arrangedObjects] objectAtIndex:index];
	} else if (item == filterHeader_) {
		// Filter zurueckgeben
		if (index >= [filters_ count])
			return nil;
		return [filters_ objectAtIndex:index];
	} else if (index == 0)
		return kontenHeader_;
	else if (index == 1 && ![[theAppCtrl standardVersion] boolValue])
		return filterHeader_;
	
	return nil;
}


- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn 
	   byItem:(id)item
{
	// Titel der Wurzeln
	if ([item isKindOfClass:[NSString class]])
		return item;
	else if ([item isKindOfClass:[Konto class]])
		return [(Konto *)item bezeichnung];
	else if ([item isKindOfClass:[Filter class]])
		return [(Filter *)item title];

	return nil;
}


- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell 
     forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	ImageAndTextCell * imcell = cell;
	if ([item isKindOfClass:[NSString class]]) {
		if (item == filterHeader_ && ![[theAppCtrl proVersion] boolValue])
			[imcell setImage:proIcon_];
		else
			[imcell setImage:nil];
	} else if ([item isKindOfClass:[Konto class]]) {
		Konto * konto = item;
		if ([[konto neueBuchungen] count] > 0)
			[imcell setImage:[[[ZaehlerImage alloc] initMitKonto:konto] autorelease]];
		else
			[imcell setImage:kontoIcon_];
	} else if ([item isKindOfClass:[Filter class]])
		[imcell setImage:trichterIcon_];
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		// 2 Wurzeln (in Standard-Version nur eine)
		return [[theAppCtrl standardVersion] boolValue] ? 1 : 2;
	else if (item == kontenHeader_)
		return [[kontenCtrl_ arrangedObjects] count];
	else if (item == filterHeader_ && ![[theAppCtrl standardVersion] boolValue])
		return [filters_ count];
	
	// Keine Kinder sonst
	return 0;
}


- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
	// Wurzeln sind ausklappbar,
	if ([item isKindOfClass:[NSString class]])
		return YES;
	
	// Andere Zellen nicht
	return NO;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	// Nur Filter und Konten kann man editieren, nicht die Header
	return [item isKindOfClass:[Konto class]] || [item isKindOfClass:[Filter class]];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn
{
	// Spalte nicht markierbar
	return NO;
}


- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (![object isKindOfClass:[NSString class]])
		return;
	
	// Bezeichnung bzw. Titel aendern
	if ([item isKindOfClass:[Konto class]])
		[(Konto *)item setBezeichnung:object];
	else if ([item isKindOfClass:[Filter class]])
		[(Filter *)item setTitle:object];
}


- (IBAction)addFilter:(id)sender
{
	// Filter erstellen
	Filter * filter = [[Filter new] autorelease];
	[filter setAktiverView:FilterAktiverKriterienView];
	
	// aktuelles Konto (vom selektieren Filter oder Konto)
	int sel = [outlineView_ selectedRow];
	if (sel == NSNotFound)
		return;
	id selItem = [outlineView_ itemAtRow:sel];
	if ([selItem isKindOfClass:[Konto class]]) {
		NSString * ident = [(Konto *)selItem ident];
		NSPredicate * kontoPred = [NSPredicate predicateWithFormat:@"(kontoIdent = %@)"
							     argumentArray:[NSArray arrayWithObject:ident]];
		[filter setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:
				      [NSArray arrayWithObject:kontoPred]]];
	}
	
	int n = [[theAppCtrl sharedFilters] countOfFilters];
	[[theAppCtrl sharedFilters] insertObject:filter
				inFiltersAtIndex:n];
	
	// Markieren
	[self tryToSelectFilter:filter];
	[self selektionMitArraySync];
	[self filterButtonsAnAus];
	
	// Name editieren
	if (markierterFilter_)
		[outlineView_ editColumn:0 row:[outlineView_ rowForItem:markierterFilter_]
			       withEvent:nil select:YES];
}


- (IBAction)removeFilter:(id)sender
{
	// Loeschen, wenn markiert in der Sidebar
	if (markierterFilter_ && [kontoWindowCtrl_ filterViewIsSichtbar]) {
		int i = [filters_ indexOfObject:markierterFilter_];
		[self setMarkierterFilter:nil];
		[kontenCtrl_ setSelectionIndex:NSNotFound];
		
		// Workaround fuer Crash vom NSTableView, weil das editierte Item schon
		// weg ist
		if ([outlineView_ editedRow] != NSNotFound)
			[outlineView_ reloadData];
		
		// noch ein Filter da? Dann schalten wir erst um
		if ([filters_ count] > 1) {
			if (i == [filters_ count] - 1)
				[self tryToSelectFilter:[filters_ objectAtIndex:i - 1]];
			else
				[self tryToSelectFilter:[filters_ objectAtIndex:i + 1]];
		}

		// loeschen
		[[theAppCtrl sharedFilters] removeObjectFromFiltersAtIndex:i];
		[theAppCtrl saveUserDefaults];
		
		// Wenn kein Filter mehr da ist -> erstes Konto selektieren
		if ([filters_ count] == 0 && [konten_ count] > 0) {
			[kontenCtrl_ setSelectionIndex:0];
		}
	}
}


@synthesize markierterFilter = markierterFilter_;

@end


@implementation SidebarOutlineView

- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row
{
	// von http://blog.petecallaway.net/?p=11
	return NSZeroRect;
}


- (void)reloadData
{
	// von http://gibbston.net/?p=4
	[super reloadData];
	NSInteger i;
	for( i = 0; i < [self numberOfRows]; i++ ) {
		NSTreeNode* item = [self itemAtRow:i];
		[self expandItem:item];
	}
}


@end

