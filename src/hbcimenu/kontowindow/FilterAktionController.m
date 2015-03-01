//
//  FilterAktionController.m
//  hbci
//
//  Created by Stefan Schimanski on 04.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "FilterAktionController.h"

#import "Aktion.h"
#import "AktionenController.h"
#import "AppController.h"
#import "debug.h"
#import "Filter.h"


@implementation FilterAktionController

- (void)awakeFromNib
{
	// Views einfuegen und Groesse anpassen
	[[self view] addSubview:growlAktionView_];
	[growlAktionView_ setFrame:[keineAktionView_ frame]];
	[growlAktionView_ setHidden:YES];
	
	[[self view] addSubview:quickenAktionView_];
	[quickenAktionView_ setFrame:[keineAktionView_ frame]];
	[quickenAktionView_ setHidden:YES];

	[[self view] addSubview:csvAktionView_];
	[csvAktionView_ setFrame:[keineAktionView_ frame]];
	[csvAktionView_ setHidden:YES];
	
	[[self view] addSubview:grandtotalAktionView_];
	[grandtotalAktionView_ setFrame:[keineAktionView_ frame]];
	[grandtotalAktionView_ setHidden:YES];
	
	[[self view] addSubview:farbAktionView_];
	[farbAktionView_ setFrame:[keineAktionView_ frame]];
	[farbAktionView_ setHidden:YES];

	[[self view] addSubview:appleScriptAktionView_];
	[appleScriptAktionView_ setFrame:[keineAktionView_ frame]];
	[appleScriptAktionView_ setHidden:YES];
}



- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSLog(@"Selektion geaendert");
	
	// "-" Button an oder aus?
	[removeButton_ setEnabled:[[aktionenArray_ arrangedObjects] count] > 0];
	
	// Welche Views anzeigen?
	BOOL growl = false;
	BOOL keine = false;
	BOOL quicken = false;
	BOOL csv = false;
	BOOL grandtotal = false;
	BOOL farbe = false;
	BOOL appleScript = false;
	int i = [aktionenArray_ selectionIndex];
	if (i == NSNotFound)
		// Nichts markiert
		keine = true;
	else {
		// Typ der Aktion ermitteln
		Aktion * aktion = [[aktionenArray_ arrangedObjects] objectAtIndex:i];
		NSString * type = [aktion type];
		if ([type compare:@"growl"] == 0)
			growl = true;
		else if ([type compare:@"quicken"] == 0)
			quicken = true;
		else if ([type compare:@"csv"] == 0)
			csv = true;
		else if ([type compare:@"grandtotal"] == 0)
			grandtotal = true;
		else if ([type compare:@"farbe"] == 0)
			farbe = true;
		else if ([type compare:@"applescript"] == 0)
			appleScript = true;
	}
	
	// Views an/ausschalten
	[keineAktionView_ setHidden:!keine];
	[growlAktionView_ setHidden:!growl];
	[quickenAktionView_ setHidden:!quicken];
	[csvAktionView_ setHidden:!csv];
	[grandtotalAktionView_ setHidden:!grandtotal];
	[farbAktionView_ setHidden:!farbe];
	[appleScriptAktionView_ setHidden:!appleScript];
}


- (IBAction)neueGrowlAktion:(id)sender
{
	NSString * filterName = [[sidebar_ markierterFilter] title];
	Aktion * aktion = [[[Aktion alloc] initWithType:@"growl"] autorelease];
	[aktion setOption:@"growl_titel" toValue:[NSString stringWithFormat:NSLocalizedString(@"Filter '%@' triggered", nil), filterName]];
	[aktionenArray_ addObject:aktion];
	[theAppCtrl saveUserDefaults];
}


- (IBAction)neueQuickenExportAktion:(id)sender
{
	Aktion * aktion = [[[Aktion alloc] initWithType:@"quicken"] autorelease];
	[aktionenArray_ addObject:aktion];
	[theAppCtrl saveUserDefaults];
}


- (IBAction)neueCsvExportAktion:(id)sender
{
	Aktion * aktion = [[[Aktion alloc] initWithType:@"csv"] autorelease];
	[aktionenArray_ addObject:aktion];
	[theAppCtrl saveUserDefaults];
}


- (IBAction)neueGrandtotalExportAktion:(id)sender
{
	Aktion * aktion = [[[Aktion alloc] initWithType:@"grandtotal"] autorelease];
	[aktionenArray_ addObject:aktion];
	[theAppCtrl saveUserDefaults];
}


- (IBAction)neueFarbAktion:(id)sender
{
	Aktion * aktion = [[[Aktion alloc] initWithType:@"farbe"] autorelease];
	[aktionenArray_ addObject:aktion];
	[theAppCtrl saveUserDefaults];
}


- (IBAction)neueAppleScriptAktion:(id)sender
{
	Aktion * aktion = [[[Aktion alloc] initWithType:@"applescript"] autorelease];
	[aktionenArray_ addObject:aktion];
	[theAppCtrl saveUserDefaults];
}


- (IBAction)entferneAktion:(id)sender
{
	NSLog(@"Segmented control action");
	[aktionenArray_ remove:self];
	[theAppCtrl saveUserDefaults];
}


- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[NSApp stopModalWithCode:returnCode];
}


- (IBAction)dateiWaehlen:(id)sender
{
	Aktion * aktion = [[aktionenArray_ selectedObjects] objectAtIndex:0];
	NSString * pfadKey = [NSString stringWithFormat:@"%@_pfad", [aktion type]];
	NSString * dateiKey = [NSString stringWithFormat:@"%@_datei", [aktion type]];
	
	NSString * ext;
	BOOL speichernPanel = YES;
	if ([[aktion type] isEqualToString:@"quicken"]) {
		ext = @"qif";
		NSLog(@"Aktiontyp war qif");
	} else if ([[aktion type] isEqualToString:@"csv"]) {
		ext = @"csv";
		NSLog(@"Aktiontyp war csv");
	} else {
		speichernPanel = NO;
		ext = @"scpt";
		NSLog(@"Aktiontyp war scpt");
	}
	
	// Dateiauswahl zeigen, modal fuers Fenster
	NSSavePanel * sp = speichernPanel ? [NSSavePanel savePanel] : [NSOpenPanel openPanel];
	[sp setRequiredFileType:ext];
	[sp beginSheetForDirectory:[aktion option:pfadKey]
			      file:[aktion option:dateiKey]
		    modalForWindow:[[self view] window]
		     modalDelegate:self 
		    didEndSelector:@selector(savePanelDidEnd: returnCode: contextInfo:)
		       contextInfo:nil];
	int ret = [NSApp runModalForWindow:sp];
	[NSApp endSheet:sp];
	[sp orderOut:self];
	
	// Datei-Dialog wurde beendet. Mit Ok?
	if (ret == NSOKButton) {
		Aktion * a = [[aktionenArray_ selectedObjects] objectAtIndex:0];
		NSString * pfad = [[sp filename] stringByDeletingLastPathComponent];
		NSString * datei = [[sp filename] substringFromIndex:[pfad length] + 1];
		[a setOption:dateiKey toValue:datei];
		[a setOption:pfadKey toValue:pfad];
	}
}


- (IBAction)aktionAufAlleAnwenden:(id)sender
{
	// Fokus auf Button setzen
	NSResponder * alterResponder = [[sender window] firstResponder];
	[[sender window] makeFirstResponder:sender];
	
	// Aktion bekommen
	int aktionIndex = [aktionenArray_ selectionIndex];
	if (aktionIndex == NSNotFound) {
		NSLog(@"Der Button sollte nicht aktiv sein.");
		return;
	}
	Aktion * aktion = [[aktionenArray_ arrangedObjects] objectAtIndex:aktionIndex];
	
	// was markiert?
	NSArray * buchungen = [gefilterteBuchungen_ selectedObjects];
	if (buchungen == nil || [buchungen count] == 0)
		buchungen = [gefilterteBuchungen_ arrangedObjects];
	
	// viele?
	if ([buchungen count] > 20) {
		int res = NSRunAlertPanelRelativeToWindow(NSLocalizedString(@"Many transactions", nil),
			NSLocalizedString(@"Do you really want to apply the action to all %d transactions?", nil),
			NSLocalizedString(@"Yes", nil), NSLocalizedString(@"Cancel", nil), nil,
			[[self view] window],
			[buchungen count]);
		if (res != NSAlertDefaultReturn)
			return;
	}
	
	// anwenden
	[[theAppCtrl aktionenController] aktionAusfuehren:aktion fuerBuchungen:buchungen];
	
	// Keyboard-Fokus zuruecksetzen
	[[sender window] makeFirstResponder:alterResponder];
	
	// Tabelle neuzeichnen
	[buchungsTabelle_ reloadData];
}


@end
