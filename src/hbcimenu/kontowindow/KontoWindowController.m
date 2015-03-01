//
//  KontoWindowController.m
//  hbci
//
//  Created by Stefan Schimanski on 13.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "KontoWindowController.h"

#import "Buchung.h"
#import "debug.h"
#import "FilterEditorController.h"
#import "FilterViewController.h"
#import "SidebarController.h"
#import "StringFarbeTransformer.h"


@implementation KontoWindowController

- (id)init
{
	self = [super initWithWindowNibName:@"KontoWindow"];
	return self;
}


- (void)windowDidLoad
{
	NSLog(@"windowDidLoad");
	[kontenCtrl_ addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew context:nil];
	
	// Farben fuer die Buchungswerte
	[buchungsWertFormatter_ setRot:[NSColor colorWithDeviceRed:0.5 green:0.0 blue:0.0 alpha:1.0]];
	[buchungsWertFormatter_ setGruen:[NSColor colorWithDeviceRed:0.0 green:0.5 blue:0.0 alpha:1.0]];
	
	// Splitview konfigurieren
	[self showKontoView:self];
	
	// FIXME: zuMarkierendeBuchung markieren!!!
	
	// Nach Datum absteigend sortieren
	NSSortDescriptor * nachDatum;
	NSSortDescriptor * nachDatumGeladen;
	nachDatum = [[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:NO] autorelease];
	nachDatumGeladen = [[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:NO] autorelease];
	[table_ setSortDescriptors:[NSArray arrayWithObjects:
				    nachDatum,
				    nachDatumGeladen,
				    nil]];
	
	// Subviews hinzufuegen
	[kontoView_ setFrameSize:[contentView_ frame].size];
	[filterView_ setFrameSize:[contentView_ frame].size];
	[contentView_ addSubview:filterView_];
	[contentView_ addSubview:kontoView_];
	
	// ArrayController fuellen
	NSError * error = nil;
	[kontenCtrl_ fetchWithRequest:nil merge:NO error:&error];
	
	// neuzeichnen, wenn sich ein ZweckFilter aendert
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(tabelleNeuladen:)
						     name:ZweckFilterGeaendertNotification
						   object:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	NSLog(@"Konten-Array geaendert");
}


- (void)tabelleNeuladen:(NSNotification *)n
{
	[buchungsCtrl_ rearrangeObjects];
}


- (void)showWithKonto:(Konto *)konto
{
	// KontoWindow anzeigen
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] makeKeyAndOrderFront:self];
	
	// Nib schon wach und Konto vorhanden?
	if (konto)
		[sidebarCtrl_ selectKonto:konto];
	else {
		// zumindest irgendwas markieren
		[sidebarCtrl_ selektionMitArraySync];
	}
}


- (void)showWithBuchung:(Buchung *)buchung
{
	// KontoWindow anzeigen
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] makeKeyAndOrderFront:self];
	
	// Konto selektieren
	Konto * konto = [buchung konto];
	NSArray * konten = [kontenCtrl_ arrangedObjects];
	int ki = [konten indexOfObject:konto];
	if (ki == NSNotFound) {
		NSLog(@"Sehr komisch. Das Konto sollte existieren.");
		return;
	}
	[sidebarCtrl_ selectKonto:konto];
	
	// Buchung waehlen
	NSError * error = nil;
	if ([[buchungsCtrl_ arrangedObjects] count] == 0)
		[buchungsCtrl_ fetchWithRequest:nil merge:NO error:&error];
	NSArray * buchungen = [buchungsCtrl_ arrangedObjects];
	int i  = [buchungen indexOfObject:buchung];
	if (i != NSNotFound) {
		[buchungsCtrl_ setSelectionIndex:i];
		[table_ scrollRowToVisible:i];
	}
	
	// Tabelle markieren
	[[self window] makeFirstResponder:table_];
}


- (IBAction)showKontoView:(id)sender
{
	[kontoView_ setHidden:NO];
	[filterView_ setHidden:YES];
}


- (IBAction)showFilterView:(id)sender
{
	[kontoView_ setHidden:YES];
	[filterView_ setHidden:NO];
	
	// Actions grundsätzlich deaktivieren
	[actionTableView_ deselectAll:self];
	// Normalzustand wieder herstellen
	[filterViewCtrl_ einfahrenClickedAnimated:NO];
}


- (BOOL)kontoViewIsSichtbar
{
	return [kontoView_ isHidden] == NO;
}


- (BOOL)filterViewIsSichtbar
{
	return [filterView_ isHidden] == NO;
}


- (NSManagedObjectContext *)managedObjectContext
{
	return [[NSApp delegate] managedObjectContext];
}


- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{	
	// eingestellte SplitViewgroesse laden
	NSRect newFrame = [sender frame];
	
	// eingestellte Groesse der linken Seite laden
	NSView *left = [[sender subviews] objectAtIndex:0];
	NSRect leftFrame = [left frame];
	
	// eingestellte Groesse der rechten Seite laden
	NSView *right = [[sender subviews] objectAtIndex:1];
	NSRect rightFrame = [right frame];
	
	// Dicke des Schiebers laden
	float Schieberdicke = [sender dividerThickness];
	
	// Aenderungen vornehmen
	rightFrame.size.width = newFrame.size.width - leftFrame.size.width - Schieberdicke;
	rightFrame.size.height = newFrame.size.height;
	leftFrame.size.height = newFrame.size.height;
	
	// Schieberdicke in der Position beruecksichtigen
	rightFrame.origin.x = leftFrame.size.width + Schieberdicke;
	
	// neue Frames setzen
	[left setFrame:leftFrame];
	[right setFrame:rightFrame];
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (![aCell isKindOfClass:[NSTextFieldCell class]])
		return;
	NSTextFieldCell * tcell = aCell;
	
	// Farbe uebertragen
	Buchung * b = [[buchungsCtrl_ arrangedObjects] objectAtIndex:rowIndex];
	NSString * farbe = [b farbe];
	if (farbe)
		[tcell setTextColor:[farbe colorOfAnHexadecimalColorString]];
	else
		[tcell setTextColor:[NSColor blackColor]];
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	// FIXME: Beim selektieren einer Buchung, die Buchung als gelesen markieren.
	/*if ([[buchungsCtrl_ selectedObjects] count] == 1) {
		NSNumber * neu = [[[buchungsCtrl_ selectedObjects] objectAtIndex:0] neu];
		neu = [NSNumber numberWithBool:NO];
	}*/

	// Summe der markierten Buchungen anzeigen
	NSArray * markierte = [buchungsCtrl_ selectedObjects];
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
