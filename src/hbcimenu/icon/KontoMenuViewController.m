//
//  KontoMenuViewController.m
//  hbci
//
//  Created by Stefan Schimanski on 20.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "KontoMenuViewController.h"

#import "AppController.h"
#import "Buchung.h"
#import "debug.h"
#import "FeedServerController.h"
#import "iBankExporter.h"
#import "StringFarbeTransformer.h"
#import "RotGruenFormatter.h"


@implementation KontoMenuViewController


- (void)setKontoMenuViewDark:(BOOL)dark
{
	if (dark) {
		[self setView:viewDunkel_];
		[saldoFormatter_ setHell];
		[buchungFormatter_ setHell];
		
		//textRedComp_ = 205/255.0;
		textRedComp_ = 250/255.0;
		//textGreenComp_ = 205/255.0;
		textGreenComp_ = 250/255.0;
		//textBlueComp_ = 205/255.0;
		textBlueComp_ = 250/255.0;
		textAlphaComp_ = 1.0;
		//textColor_ = [NSColor colorWithDeviceRed:205/255.0 green:205/255.0 blue:205/255.0 alpha:1.0];
	} else {
		[self setView:viewHell_];
		[saldoFormatter_ setDunkel];
		[buchungFormatter_ setDunkel];
		
		textRedComp_ = 0.0;
		textGreenComp_ = 0.0;
		textBlueComp_ = 0.0;
		textAlphaComp_ = 1.0;
		//textColor_ = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0];
	}
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	Buchung * b = [[buchungen_ arrangedObjects] objectAtIndex:rowIndex];
	
	if ([[aTableColumn identifier] isEqualToString:@"zweck"])
		return [b andererNameUndZweck];
	
	if ([[aTableColumn identifier] isEqualToString:@"waehrung"]) {
		NSString * strWaehrung = [NSString stringWithFormat:@"%@", [b waehrung]];
		
		if ([strWaehrung isEqualToString:@"EUR"])
			return @"€";
		else
			return strWaehrung;
	}
	return nil;
}


- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (![aCell isKindOfClass:[NSTextFieldCell class]])
		return;
	NSTextFieldCell * tcell = aCell;
	
	// Farbe uebertragen
	Buchung * b = [[buchungen_ arrangedObjects] objectAtIndex:rowIndex];
	NSString * farbe = [b farbe];
	if (farbe)
		[tcell setTextColor:[farbe colorOfAnHexadecimalColorString]];
	else {
		//[tcell setTextColor:[NSColor colorWithDeviceRed:205/255.0 green:205/255.0 blue:205/255.0 alpha:1.0]];
		/*NSLog(@"Color - red:%f green:%f blu:%f alpha:%f",
		      [textColor_ redComponent],
		      [textColor_ greenComponent],
		      [textColor_ blueComponent],
		      [textColor_ alphaComponent]);
		 [tcell setTextColor:textColor_];*/
		
		[tcell setTextColor:[NSColor colorWithDeviceRed:textRedComp_ green:textGreenComp_ blue:textBlueComp_ alpha:textAlphaComp_]];
		
	}
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return 10;
	//return [[buchungen_ arrangedObjects] count]-1;
}



- (id)initWithKonto:(Konto *)konto
{
	self = [super initWithNibName:@"KontoMenuView" bundle:nil];
	
	konto_ = [konto retain];
	menu_ = nil;
	
	textRedComp_ = 0.0;
	textGreenComp_ = 0.0;
	textBlueComp_ = 0.0;
	textAlphaComp_ = 1.0;
	//textColor_ = [NSColor colorWithDeviceRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:1.0];
	
	return self;
}



- (void)dealloc
{
	[menu_ release];
	[konto_ release];
	[super dealloc];
}


- (void)updateNeuladenAbbrechen
{
	// Abbrechen- oder Neuladen-Button?
	if ([[theAppCtrl laufenderKontoauszug] konto] != konto_) {
		[abbrechenButton_ setHidden:YES];
		[abbrechenButton2_ setHidden:YES];
		[neuladenButton_ setHidden:NO];
		[neuladenButton2_ setHidden:NO];
	} else {
		[abbrechenButton_ setHidden:NO];
		[abbrechenButton2_ setHidden:NO];
		[neuladenButton_ setHidden:YES];
		[neuladenButton2_ setHidden:YES];
	}
}


- (void)awakeFromNib
{
	NSLog(@"KontoMenuViewController awakeFromNib");
	
	[self setKontoMenuViewDark:NO];
	
	// Anfangsgroesse, fuer die Skalierung noetig
	startViewBounds_ = [[self view] bounds].size;
	
	// Nach Datum absteigend sortieren
	NSSortDescriptor * nachDatum;
	NSSortDescriptor * nachDatumGeladen;
	nachDatum = [[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:NO] autorelease];
	nachDatumGeladen = [[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:NO] autorelease];
	[table_ setSortDescriptors:[NSArray arrayWithObjects:
				    nachDatum,
				    nachDatumGeladen,
				    nil]];
	
	// Mausereignisse mitbekommen
	[self setNextResponder:[table_ nextResponder]];
	[table_ setNextResponder:self];
	[table_ setDoubleAction:@selector(buchungOeffnen:)];
	
	[self updateNeuladenAbbrechen];
}


- (NSManagedObjectContext *)managedObjectContext
{
	return [[NSApp delegate] managedObjectContext];
}


- (void)fehlerZeigenClickedAsync
{
	[theAppCtrl zeigeFehler:konto_];
}
- (IBAction)fehlerZeigenClicked:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
		selector:@selector(fehlerZeigenClickedAsync)
		userInfo:nil repeats:NO];
}


- (void)fehlerGesehenClickedAsync
{
	[theAppCtrl fehlerGesehen:konto_];
}
- (IBAction)fehlerGesehenClicked:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(fehlerGesehenClickedAsync)
				       userInfo:nil repeats:NO];
}


- (void)alleBuchungenZeigenClickedAsync
{
	[theAppCtrl zeigeBuchungsFensterMitKonto:konto_];
}
- (IBAction)alleBuchungenZeigenClicked:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(alleBuchungenZeigenClickedAsync)
				       userInfo:nil repeats:NO];
}


- (void)kontoauszugHolenAsync
{
	[theAppCtrl holeKontoauszugFuer:konto_];
}
- (IBAction)kontoauszugHolen:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(kontoauszugHolenAsync)
				       userInfo:nil repeats:NO];
}


- (void)kontoauszugAbbrechenAsync
{
	[theAppCtrl stopKontoauszugFuerKonto:konto_];
}
- (IBAction)kontoauszugAbbrechen:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(kontoauszugAbbrechenAsync)
				       userInfo:nil repeats:NO];
}


- (void)gelesenMarkierenAsync
{
	// neueBuchungen als nicht-neu markieren
	NSMutableSet * neueBuchungen = [konto_ mutableSetValueForKey:@"neueBuchungen"];
	[neueBuchungen removeAllObjects];
}
- (IBAction)gelesenMarkieren:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(gelesenMarkierenAsync)
				       userInfo:nil repeats:NO];
}


- (IBAction)tabelleHoch:(id)sender
{
	[table_ scrollRowToVisible:0];
}


- (IBAction)zuruecksetzen:(id)sender
{
	[table_ scrollRowToVisible:0];
	[table_ deselectAll:self];
	BOOL fehler = [theAppCtrl kontoHatteFehler:konto_];
	[fehlerZeigenButton_ setHidden:!fehler];
	[fehlerGesehenButton_ setHidden:!fehler];
	[fehlerLabel_ setHidden:!fehler];
	[fehlerZeigenButton2_ setHidden:!fehler];
	[fehlerGesehenButton2_ setHidden:!fehler];
	[fehlerLabel2_ setHidden:!fehler];
	//[fehlerSymbol_ setHidden:!fehler];
	//[fehlerButtonleiste_ setHidden:!fehler];
	if (fehler) {
		NSString * meldung = [theAppCtrl kontoFehler:konto_];
		if (meldung) {
			[fehlerLabel_ setStringValue:meldung];
			[fehlerLabel_ setToolTip:meldung];
			[fehlerLabel2_ setStringValue:meldung];
			[fehlerLabel2_ setToolTip:meldung];
		} else {
			[fehlerLabel_ setStringValue:@""];
			[fehlerLabel_ setToolTip:@""];
			[fehlerLabel2_ setStringValue:@""];
			[fehlerLabel2_ setToolTip:@""];
		}
	}
	[self updateNeuladenAbbrechen];
}


- (IBAction)naechsteNeueBuchungSelektieren:(id)sender
{
	// naechste neue Buchung suchen
	int i = [buchungen_ selectionIndex];
	if (i == NSNotFound)
		i = 0;
	NSArray * buchungen = [buchungen_ arrangedObjects];
	while (i < [buchungen count] && ![[buchungen objectAtIndex:i] neu])
		++i;
	if (i < [buchungen count])
		[buchungen_ setSelectionIndex:i];
	else
		NSBeep();
}


- (void)mouseDown:(NSEvent *)ev
{
	NSLog(@"mouseDown");
	if ([ev modifierFlags] == 0 && [ev clickCount] == 2) {
//		[theAppCtrl showLog:<#(id)sender#>
		NSLog(@"Doppelklick");
	}
	
	[[self nextResponder] mouseDown:ev];
}


- (IBAction)buchungOeffnen:(id)sender
{
	[menu_ cancelTracking];
	
	NSArray * sel = [buchungen_ selectedObjects];
	
	if ([sel count] > 0) {
		NSLog(@"Buchung wird geoeffnet.");
		
		Buchung * b;
		if (sel && (b = [sel objectAtIndex:0]))
			[theAppCtrl zeigeBuchungsFensterMitBuchung:b];
	} else {
		NSLog(@"Keine Buchung selektiert.");
	}

}


- (void)setSkalierung:(double)skalierung
{
	NSLog(@"Skalierung = %f", skalierung);
	NSSize bounds = [tableScrollView_ bounds].size;
	NSSize skaliert = NSMakeSize(bounds.width * skalierung, bounds.height * skalierung);
	[[self view] setFrameSize:NSMakeSize(startViewBounds_.width + skaliert.width - bounds.width,
					     startViewBounds_.height + skaliert.height - bounds.height)];
	[tableScrollView_ setBoundsSize:bounds];
}


- (void)feedOeffnenAsync
{
	[[theAppCtrl feedServerController] oeffneFeedFuerKonto:konto_];
}
- (IBAction)feedOeffnen:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(feedOeffnenAsync)
				       userInfo:nil repeats:NO];
}

- (void)nachiBankExportierenAsync
{
	[[theAppCtrl ibankExporter] export:konto_];
}
- (IBAction)nachiBankExportieren:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(nachiBankExportierenAsync)
				       userInfo:nil repeats:NO];
}



- (void)nachQifExportierenAsync
{
	//[[theAppCtrl moneywellExporter] export:konto_];
	[[theAppCtrl universalQifExporter] export:konto_];
}
- (IBAction)nachQifExportieren:(id)sender
{
	[menu_ cancelTracking];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self 
				       selector:@selector(nachQifExportierenAsync)
				       userInfo:nil repeats:NO];
}


@synthesize konto = konto_;
@synthesize menu = menu_;

@end

@implementation KontoMenuViewView

- (void)viewDidMoveToWindow
{
	NSLog(@"viewDidMoveToWindow");
	[super viewDidMoveToWindow];
	[[self window] makeFirstResponder:self];
}


- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	
	if ([[self title] isEqualToString:@"dunkel"]) {
		// Transparent
		[[self window] setAlphaValue:0.85];
		NSView * v = [[self window] contentView];
		
		[v lockFocus];
		 
		// ### Grundfarbe ###
		[[NSColor colorWithDeviceRed:30/255.0 green:30/255.0 blue:30/255.0 alpha:1.0] setFill];
		int breite = 7;
		// oben
		[NSBezierPath fillRect:NSMakeRect(0, [v frame].size.height - breite, [v frame].size.width, breite)];
		// unten
		[NSBezierPath fillRect:NSMakeRect(0, 0, [v frame].size.width, breite)];
		// links
		[NSBezierPath fillRect:NSMakeRect(0, 0, breite, [v frame].size.height)];
		// rechts
		[NSBezierPath fillRect:NSMakeRect([v frame].size.width - breite, 0, breite, [v frame].size.height)];
		 
		// ### Rahmen ###
		int staerke = 3;
		[[NSColor colorWithDeviceRed:0.95 green:0.95 blue:0.95 alpha:1.0] setStroke];
		NSBezierPath * rahmen = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0+staerke/2, 0+staerke/2,[v frame].size.width-staerke/1.5,[v frame].size.height-staerke/1.5)
									 xRadius:5 - staerke/2
									 yRadius:5 - staerke/2];
		[rahmen setLineWidth:staerke];
		[rahmen stroke];
		
		[v unlockFocus];
	 }
	
	
}

@end


