//
//  KontenPaneController.m
//  hbcipref
//
//  Created by Michael on 23.03.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "KontenPaneController.h"
#import "RegexKitLite.h"
#import <WebKit/WebKit.h>

#import "AppController.h"
#import "AppDelegate.h"
#import "debug.h"
#import "ExpertenKontoController.h"
#import "FeedServerController.h"
#import "FintsInstituteLeser.h"
#import "iBankExporter.h"
#import "Konto.h"
#import "NSManagedObject+Clone.h"
#import "NSString+UrlEscape.h"
#import "urls.h"


NSString * KontoDragType = @"KontoDragType";


@implementation KontenPaneController

- (HbciToolLoader *)hbciToolLoader
{
	if (hbcitoolLoader_ == nil) {
		hbcitoolLoader_ = [[HbciToolLoader alloc] init];
		[hbcitoolLoader_ addLogView:statusLogView_];
		[theAppCtrl leereLogView];
		[hbcitoolLoader_ addLogView:[theAppCtrl logView]];
	}
	
	return hbcitoolLoader_;
}


- (void)quitHbcitoolLoader
{
	if (hbcitoolLoader_) {
		[hbcitoolLoader_ unload];
		[hbcitoolLoader_ release];
		hbcitoolLoader_ = nil;
	}
}


- (void)vollstaendigkeitPruefen {
	if ([[kontenController_ selectedObjects] count] == 0) {
		[btnUnterkontoHolen_ setEnabled:NO];
		return;
	}
	Konto * konto = [[kontenController_ selectedObjects] objectAtIndex:0];
	
#ifdef DEBUG
	NSLog(@"TextFieldValue Bankleitzahl: %@", [tfBankleitzahl stringValue]);
	NSLog(@"Datenbankeintrag Bankleitzahl: %@", konto.bankleitzahl);
	NSLog(@"TextFieldValue Kennung: %@", [tfKennung stringValue]);
	NSLog(@"Datenbankeintrag Kennung: %@", konto.kennung);
#endif
	
	// FIXME: Bankleitzahllaenge -> Laenderspezifisch
	if ([konto.bankleitzahl length] < 8 || konto.server == nil || [konto.server length] == 0 
	    || konto.bankleitzahl == nil ||[konto.bankleitzahl length] == 0 
	    || konto.kennung == nil || [konto.kennung length] == 0) {
		[btnUnterkontoHolen_ setEnabled:NO];
	} else
		[btnUnterkontoHolen_ setEnabled:YES];
}


- (void)bankInfosPruefen:(NSNotification *)aNotification
{
	
	Konto * konto = [[kontenController_ selectedObjects] objectAtIndex:0];
	NSString * s = [konto server];
	NSString * bankname = [konto bankname];
	NSString * blz = [konto bankleitzahl];
	
	// Wenn die Bankleitzahl vorhanden ist...
	if (blz != nil && [blz length] > 7) { // FIXME: bei anderen Laendern evtl. BLZ-Laenge beachten! Deutschland - 8Ziffern
		// BankInfos vorhanden -> Serveradresse vorhanden?
		if ( s == nil || [s length] == 0 || bankname == nil || [bankname length] == 0) {
			// Warnungen setzen
			[ServerWarningView_ setHidden:NO];
			[BanknameView_ setHidden:YES];
			if ([[aNotification name] isEqualToString:@"Bankleitzahl"]) {
				[drawer_ open];
			}
			[hbciServerLabel_ setTextColor:[NSColor redColor]];
		} else {
			// Bankname einblenden
			[BanknameView_ setHidden:NO];
			[ServerWarningView_ setHidden:YES];
			[hbciServerLabel_ setTextColor:[NSColor blackColor]];
		}
	} else {
		[ServerWarningView_ setHidden:YES];
		[BanknameView_ setHidden:YES];
		[hbciServerLabel_ setTextColor:[NSColor blackColor]];
	}
	
	[self vollstaendigkeitPruefen];
}


- (void)errorProtokollZeigen {
	[errorWindowSheet_ setFrame:NSMakeRect ([errorWindowSheet_ frame].origin.x,
						[errorWindowSheet_ frame].origin.y-[errorScrollView_ frame].size.height,
						[errorWindowSheet_ frame].size.width,
						[errorWindowSheet_ frame].size.height+[errorScrollView_ frame].size.height)
			    display:YES animate:YES];
}


- (void)errorProtokollVerbergen {
	[errorWindowSheet_ setFrame:NSMakeRect ([errorWindowSheet_ frame].origin.x,
						[errorWindowSheet_ frame].origin.y+[errorScrollView_ frame].size.height,
						[errorWindowSheet_ frame].size.width,
						[errorWindowSheet_ frame].size.height-[errorScrollView_ frame].size.height)
			    display:YES animate:YES];
}



- (void)awakeFromNib
{
	NSLog(@"KontenPaneController awakeFromNib");
	subAccounts_ = nil;
	showErrorIfAny_ = YES;
	[statusLogView_ setFont:[NSFont userFixedPitchFontOfSize:9.0]];
	hbcitoolLoader_ = nil;
	[webView_ setApplicationNameForUserAgent:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]];
	
	// Warnungen und Bestaetigungen entfernen
	[ServerWarningView_ setHidden:YES];
	[BanknameView_ setHidden:YES];
	
	// Protokoll im ErrorWindow ausfahren
	[errorProtokollAusfahren setState:1];
	[self errorProtokollZeigen];
	
	// ProgressIndicator verbergen
	[piBankWirdErmittelt_ setHidden:YES];
	
	// KontoController-Selection beobachten
	[kontenController_ addObserver:self forKeyPath:@"selection" options:NSKeyValueObservingOptionNew context:@"kontenController.selection"];
	
	// Sortieren nach "order"
	[kontenController_ setSortDescriptors:
		[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES] autorelease]]];
}



- (IBAction)lock:(id)sender
{
	if ([[kontenController_ arrangedObjects] count] > 0)
		[kontenController_ setSelectionIndexes:[NSIndexSet indexSet]];
	//[[tableView_ enclosingScrollView] setEnabled:NO];
}

- (IBAction)unlock:(id)sender
{
	//[tableView_ setEnabled:YES];
	if ([[kontenController_ arrangedObjects] count] > 0)
		[kontenController_ setSelectionIndex:0];
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	if (context && [(NSString *)context isEqualToString:@"kontenController.selection"]) {
		// BankInfos vorhanden?
		if ([kontenController_ selectionIndex] != NSNotFound) {
			[self bankInfosPruefen:[NSNotification notificationWithName:@"ObservSelection" object:nil]];
		} else {
			[ServerWarningView_ setHidden:YES];
			[BanknameView_ setHidden:YES];
		}
		
		// Verschlossen?
		if ([[theAppCtrl authController] verschlossen]) {
			[self lock:self];
		}
	}
}



- (void)dealloc
{
	NSLog(@"KontenPaneController dealloc");	
	[hbcitoolLoader_ setDelegate:nil];
	[hbcitoolLoader_ release];
	
	[super dealloc];
}


- (NSError *)error:(NSString *)desc
{
	NSDictionary * details = 
	[NSMutableDictionary dictionaryWithObject:NSLocalizedString(desc, nil)
					   forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:@"KontenPaneController" code:1 userInfo:details];
}


- (Konto *)currentKonto
{
	NSArray * selection = [kontenController_ selectedObjects];
	if ([selection count] != 1)
		return nil;
	return [selection objectAtIndex:0];
}


- (IBAction)protokollAnzeigen:(id)sender
{
	[theAppCtrl showLog:self];
}


- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	[self vollstaendigkeitPruefen];
}


- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	if ([[theAppCtrl authController] verschlossen])
		return NO;
	return YES;
}


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	// Warnung weg
	[ServerWarningView_ setHidden:YES];
	
	// ... Warnsaldo aktualisieren
	NSArray * selection = [kontenController_ selectedObjects];
	if ([selection count] == 0) {
		// nichts angewaehlt, also zuruecksetzen
		[tfWarnSaldo_ setDoubleValue:0.0];
		[chkWarnen_ setState:NSOffState];
	} else {
		[self vollstaendigkeitPruefen]; // Nach Aenderung der Selektion in der Kontentabelle ...
		[self bankInfosPruefen:[NSNotification notificationWithName:@"TableSelection" object:nil]];
		Konto * konto = [selection objectAtIndex:0];
		
		// Warnsaldo uebertragen
		NSNumber * warnSaldo = [konto warnSaldo];
		if (warnSaldo == nil) {
			// keiner vorhanden, also zuruecksetzen
			[tfWarnSaldo_ setDoubleValue:0.0];
			[chkWarnen_ setState:NSOffState];			
		} else {
			[tfWarnSaldo_ setDoubleValue:[warnSaldo doubleValue]];
			[chkWarnen_ setState:NSOnState];
		}
	}
	
	// BankWiki-Webseite laden
	if ([drawer_ state] != NSDrawerClosedState)
		[self bankWikiLaden];
	
	// TAN-Methoden aktualisieren
	//[self updateTanMethods];
}


- (void)presentHbciError:(NSError *)error
{
	// Fehler-Meldung einsetzen
	[errorMessage_ setStringValue:[error localizedDescription]];
	
	// Log kopieren vom Status-Sheet
	NSRange r;
	r.location = 0;
	r.length = [[statusLogView_ textStorage] length];
	NSData * data = [statusLogView_ RTFDFromRange:r];
	r.length = [[errorLogView_ textStorage] length];
	[errorLogView_ replaceCharactersInRange:r withRTFD:data];
	
	// nach unten scrollen
	r.location = [[errorLogView_ textStorage] length];
	r.length = 0;
	[errorLogView_ scrollRangeToVisible:r];	
	
	// Fehler-Sheet anzeigen
	[NSApp beginSheet:errorWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
	    modalDelegate:nil didEndSelector:nil contextInfo:nil];
}


- (IBAction)kontoauszugTesten:(id)sender
{	
	// Fokus auf Button setzen
	[[sender window] makeFirstResponder:sender];
	
	NSLog(@"tryConnection");
	Konto * konto = [self currentKonto];
	if (!konto)
		return;
	
	// log leeren
	NSRange r;
	r.location = 0;
	r.length = [[statusLogView_ textStorage] length];
	[statusLogView_ replaceCharactersInRange:r withString:@""];
	
	// moeglichen Fehler zeigen
	showErrorIfAny_ = YES;
	
	// Sheet anzeigen
	[NSApp beginSheet:statusWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
	    modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[statusSpinner_ startAnimation:self];	
	
	// hbcitool laden
	[self hbciToolLoader];
	
	// Eigentlichen hbcitool-Aufruf im Thread durchfuehren, damit die GUI aktiv bleibt.
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[NSThread detachNewThreadSelector:@selector(kontoauszugTestenThread:) toTarget:self withObject:[konto objectID]];
}


- (IBAction)kontoauszugTestenErfolgsSheetSchliessen:(id)sender
{
	[kontoauszugTestenErfolgsSheet_ orderOut:self];
	[NSApp endSheet:kontoauszugTestenErfolgsSheet_];
}


- (void)kontoauszugTestenThread:(NSManagedObjectID *)kontoId
{	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	NSError * error = nil;
	
	// Thread CoreData-Context erstellen
	NSManagedObjectContext * ctx = [[[NSManagedObjectContext alloc] init] autorelease];
	[ctx setPersistentStoreCoordinator:[[NSApp delegate] persistentStoreCoordinator]];
	[ctx setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
	
	// Konto-Objekt im Thread-Context erstellen
	Konto * konto = (Konto *)[ctx objectWithID:kontoId];
	
	// Accounts vom hbcitool bekommen
	@synchronized (hbcitoolLoader_) {
		@try {
			NSProxy<CocoaBankingProtocol> * banking = [hbcitoolLoader_ banking];
			double saldo = 0.0;
			NSString * currency = nil;
			NSArray * buchungen_ = [banking getTransactions:konto 
					    from:[NSDate dateWithTimeIntervalSinceNow:-3600*24*7*4]
				       balanceTo:&saldo 
			       balanceCurrencyTo:&currency
					   error:&error];
			if (buchungen_)
				geladeneBuchungenImTestKontoauszug_ = [buchungen_ count];
			else
				geladeneBuchungenImTestKontoauszug_ = -1;
		}
		@catch (NSException * e) {
			error = [self error:[e description]];
		}
	}
	
	// Thread-Ende an Hauptthread melden
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[self performSelectorOnMainThread:@selector(kontoauszugTestenEnde:) withObject:error waitUntilDone:NO];
	[pool release];
}


- (void)kontoauszugTestenEnde:(NSError *)error
{
	//[self updateTanMethods];
	[self quitHbcitoolLoader];
	
	// statusWindowSheet verstecken
	[statusWindowSheet_ orderOut:self];
	[NSApp endSheet:statusWindowSheet_];
	
	// Fehler-Sheet zeigen
	if (!showErrorIfAny_)
		return;
	if (error != nil) {
		[self presentHbciError:error];
		return;
	}
	
	// Erfolgmeldung anzeigen
	[NSApp beginSheet:kontoauszugTestenErfolgsSheet_ modalForWindow:[prefWindowCtrl_ window]
	    modalDelegate:nil didEndSelector:nil contextInfo:nil];
}


- (IBAction)kontenErmitteln:(id)sender
{	
	// Fokus auf Button setzen
	[[sender window] makeFirstResponder:sender];

	NSLog(@"tryConnection");
	Konto * konto = [self currentKonto];
	if (!konto)
		return;
		
	// log leeren
	NSRange r;
	r.location = 0;
	r.length = [[statusLogView_ textStorage] length];
	[statusLogView_ replaceCharactersInRange:r withString:@""];

	// moeglichen Fehler zeigen
	showErrorIfAny_ = YES;
	
	// Sheet anzeigen
	[NSApp beginSheet:statusWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
	    modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[statusSpinner_ startAnimation:self];	
	
	// hbcitool laden
	[self hbciToolLoader];
	
	// Eigentlichen hbcitool-Aufruf im Thread durchfuehren, damit die GUI aktiv bleibt.
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[NSThread detachNewThreadSelector:@selector(kontenErmittelnThread:) toTarget:self withObject:[konto objectID]];
}


- (void)kontenErmittelnThread:(NSManagedObjectID *)kontoId
{	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	NSError * error = nil;
	
	// Thread CoreData-Context erstellen
	NSManagedObjectContext * ctx = [[[NSManagedObjectContext alloc] init] autorelease];
	[ctx setPersistentStoreCoordinator:[[NSApp delegate] persistentStoreCoordinator]];
	[ctx setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
	
	// Konto-Objekt im Thread-Context erstellen
	Konto * konto = (Konto *)[ctx objectWithID:kontoId];
	
	// Accounts vom hbcitool bekommen
	@synchronized (hbcitoolLoader_) {
		@try {
			[subAccounts_ autorelease];
			subAccounts_ = nil;
			NSProxy<CocoaBankingProtocol> * banking = [hbcitoolLoader_ banking];
			subAccounts_ = [[banking getSubAccounts:konto error:&error] retain];
		}
		@catch (NSException * e) {
			error = [self error:[e description]];
		}
	}
	
	// Thread-Ende an Hauptthread melden
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[self performSelectorOnMainThread:@selector(kontenErmittelnEnde:) withObject:error waitUntilDone:NO];
	[pool release];
}


- (void)kontenErmittelnEnde:(NSError *)error
{
	[self quitHbcitoolLoader];

	// statusWindowSheet verstecken
	[statusWindowSheet_ orderOut:self];
	[NSApp endSheet:statusWindowSheet_];
	
	// Fehler-Sheet zeigen
	if (!showErrorIfAny_)
		return;
	if (error != nil) {
		[self presentHbciError:error];
		return;
	}
	
	Konto * konto = [self currentKonto];
	if (!konto)
		return;
	
	// alte Selektion merken
	NSString * altesUnterkonto = [[konto unterkonto] kontonummer];
	if (altesUnterkonto == nil)
		altesUnterkonto = [konto kennung];
	[konto setUnterkonto:nil];
	
	// neue Unterkontenliste erstellen
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	NSMutableSet * unterkonten = [konto mutableSetValueForKey:@"unterkonten"];
	for (Unterkonto * uk in unterkonten)
		[ctx deleteObject:uk];
	[unterkonten removeAllObjects];
	
	id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	for (NSDictionary * dict in subAccounts_) {
		Unterkonto * unterkonto
		= [NSEntityDescription insertNewObjectForEntityForName:@"Unterkonto"
						inManagedObjectContext:ctx];
		[ctx assignObject:unterkonto toPersistentStore:globalStore];
		[unterkonto setKontonummer:[dict objectForKey:@"kontonummer"]];
		[unterkonto setName:[dict objectForKey:@"name"]];
		[unterkonto setBankleitzahl:[dict objectForKey:@"bankleitzahl"]];
		[unterkonten addObject:unterkonto];
	}
	
	for (Unterkonto * uk in [konto unterkonten]) {
		if ([[uk kontonummer] compare:altesUnterkonto] == 0)
			[konto setUnterkonto:uk];
	}
	
	// Combobox markieren
	[[prefWindowCtrl_ window] makeFirstResponder:unterkonten_];
	//[unterkonten_ performSelector:@selector(performClick:) withObject:self afterDelay:0.01];
}


- (IBAction)errorCloseClicked:(id)sender
{
	[errorWindowSheet_ orderOut:self];
	[NSApp endSheet:errorWindowSheet_];
}


- (NSArray *)subAccounts
{
	return subAccounts_;
}



- (IBAction)updateTanMethods:(id)sender
{
	// Fokus auf Button setzen
	[[sender window] makeFirstResponder:sender];
	
	NSLog(@"tryConnection");
	Konto * konto = [self currentKonto];
	if (!konto)
		return;
	
	// log leeren
	NSRange r;
	r.location = 0;
	r.length = [[statusLogView_ textStorage] length];
	[statusLogView_ replaceCharactersInRange:r withString:@""];
	
	// moeglichen Fehler zeigen
	showErrorIfAny_ = YES;
	
	// Sheet anzeigen
	[NSApp beginSheet:statusWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
	    modalDelegate:nil didEndSelector:nil contextInfo:nil];
	[statusSpinner_ startAnimation:self];	
	
	// hbcitool laden
	[self hbciToolLoader];
	
	// Eigentlichen hbcitool-Aufruf im Thread durchfuehren, damit die GUI aktiv bleibt.
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[NSThread detachNewThreadSelector:@selector(updateTanMethodsThread:) toTarget:self withObject:[konto objectID]];
}


- (void)updateTanMethodsThread:(NSManagedObjectID *)kontoId
{	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	NSError * error = nil;
	
	// Thread CoreData-Context erstellen
	NSManagedObjectContext * ctx = [[[NSManagedObjectContext alloc] init] autorelease];
	[ctx setPersistentStoreCoordinator:[[NSApp delegate] persistentStoreCoordinator]];
	[ctx setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
	
	// Konto-Objekt im Thread-Context erstellen
	Konto * konto = (Konto *)[ctx objectWithID:kontoId];
	
	// TanMethoden vom hbcitool bekommen
	@synchronized (hbcitoolLoader_) {
		@try {
			[theTanMethods_ autorelease];
			theTanMethods_ = nil;
			NSProxy<CocoaBankingProtocol> * banking = [hbcitoolLoader_ banking];
			theTanMethods_ = [[banking getTanMethods:konto error:&error] retain];
		}
		@catch (NSException * e) {
			error = [self error:[e description]];
			NSLog(@"Fehler beim Ermitteln der TAN-Methoden: %@", [e description]);
		}
	}
		
	// Thread-Ende an Hauptthread melden
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[self performSelectorOnMainThread:@selector(updateTanMethodsEnde:) withObject:error waitUntilDone:NO];
	[pool release];
}


- (void)updateTanMethodsEnde:(NSError *)error {
	[self quitHbcitoolLoader];
	
	// statusWindowSheet verstecken
	[statusWindowSheet_ orderOut:self];
	[NSApp endSheet:statusWindowSheet_];
	
	// Fehler-Sheet zeigen
	if (!showErrorIfAny_)
		return;
	if (error != nil) {
		[self presentHbciError:error];
		return;
	}
	
	Konto * konto = [self currentKonto];
	if (!konto)
		return;
	
	// alte Selektion merken
	NSString * alteTanMethode = [[konto tanMethode] id_name];
	[konto setTanMethode:nil];
	
	// neue TanMethoden-Liste erstellen
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	NSMutableSet * tanMethoden = [konto mutableSetValueForKey:@"tanMethoden"];
	for (TanMethode * tm in tanMethoden)
		[ctx deleteObject:tm];
	[tanMethoden removeAllObjects];
	id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	
	// Gefundene TanMethoden hinzufuegen
	for (NSDictionary * dict in theTanMethods_) {
		TanMethode * tanMethode
		= [NSEntityDescription insertNewObjectForEntityForName:@"TanMethode"
						inManagedObjectContext:ctx];
		
		[ctx assignObject:tanMethode toPersistentStore:globalStore];
		[tanMethode setId_name:[dict objectForKey:@"id_name"]];
		[tanMethode setName:[dict objectForKey:@"name"]];
		[tanMethode setFunktion:[dict objectForKey:@"funktion"]];
		[tanMethoden addObject:tanMethode];
	}
	
	for (TanMethode * tm in [konto tanMethoden]) {
		if ([[tm id_name] compare:alteTanMethode] == 0)
			[konto setTanMethode:tm];
	}
	
	// Combobox markieren
	[[prefWindowCtrl_ window] makeFirstResponder:popupTanMethods_];
}



- (IBAction)statusStopClicked:(id)sender
{
	showErrorIfAny_ = NO;
	[hbcitoolLoader_ unload];
}



- (IBAction)statusWindowSheet_protokollausfahren:(id)sender
{
	if ([statusProtokollAusfahren state] == NSOnState) {
		[statusWindowSheet_ setFrame:NSMakeRect ([statusWindowSheet_ frame].origin.x,
							 [statusWindowSheet_ frame].origin.y-[statusScrollView_ frame].size.height,
							 [statusWindowSheet_ frame].size.width,
							 [statusWindowSheet_ frame].size.height+[statusScrollView_ frame].size.height)
				     display:YES animate:YES];
	}
	
	if ([statusProtokollAusfahren state] == NSOffState) {
		[statusWindowSheet_ setFrame:NSMakeRect ([statusWindowSheet_ frame].origin.x,
							 [statusWindowSheet_ frame].origin.y+[statusScrollView_ frame].size.height,
							 [statusWindowSheet_ frame].size.width,
							 [statusWindowSheet_ frame].size.height-[statusScrollView_ frame].size.height)
				     display:YES animate:YES];
	}
}


- (IBAction)errorWindowSheet_protokollausfahren:(id)sender
{
	if ([errorProtokollAusfahren state] == NSOnState) {
		[self errorProtokollZeigen];
	}
	
	if ([errorProtokollAusfahren state] == NSOffState) {
		[self errorProtokollVerbergen];
	}
}


- (IBAction)warnCheckboxClicked:(id)sender
{
	Konto * konto = [[kontenController_ selectedObjects] objectAtIndex:0];
	if ([chkWarnen_ state] == NSOnState)
		[konto setWarnSaldo:[NSNumber numberWithDouble:0.0]];
	else
		[konto setWarnSaldo:nil];
}


- (NSManagedObjectContext *)managedObjectContext
{
	 return [[NSApp delegate] managedObjectContext];
}


- (IBAction)neuesKonto:(id)sender
{
	// Neues Konto erzeugen
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	Konto * konto = [NSEntityDescription insertNewObjectForEntityForName:@"Konto"
						      inManagedObjectContext:ctx];
	[ctx assignObject:konto toPersistentStore:globalStore];
		[konto setBezeichnung:NSLocalizedString(@"New account", nil)];
	
	// am Ende einsortieren
	int n = [[kontenController_ arrangedObjects] count];
	if (n > 0) {
		int groessteOrderBisher = [[[[kontenController_ arrangedObjects] objectAtIndex:n - 1] order] intValue];
		[konto setOrder:[NSNumber numberWithInt:groessteOrderBisher + 1]];
	}
	
	[kontenController_ addObject:konto];
	
	// Neue Zeile editieren
	[tableView_ editColumn:0 
			   row:[kontenController_ selectionIndex]
		     withEvent:nil
			select:YES];
}
	

- (IBAction)kontoDuplizieren:(id)sender
{
	// nur ausgewaehlte Eigenschaften kopieren
	Konto * altesKonto = [[kontenController_ selectedObjects] objectAtIndex:0];
	Konto * konto = (Konto *)[altesKonto cloneOfSelf];
	[konto setBezeichnung:[NSString stringWithFormat:NSLocalizedString(@"Copy of %@", nil),
							  [konto bezeichnung]]];
		
	// hinter altem Konto einsortieren
	int i = [[kontenController_ arrangedObjects] indexOfObject:altesKonto] + 1;
	for (; i < [[kontenController_ arrangedObjects] count]; ++i) {
		Konto * k = [[kontenController_ arrangedObjects] objectAtIndex:i];
		[k setOrder:[NSNumber numberWithInt:[[k order] intValue] + 1]];
	}
	[konto setOrder:[NSNumber numberWithInt:[[altesKonto order] intValue] + 1]];
	
	// im Store speichern
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	[ctx assignObject:konto toPersistentStore:globalStore];
	for (Unterkonto * uk in [konto unterkonten])
		[ctx assignObject:uk toPersistentStore:globalStore];
	
	[kontenController_ addObject:konto];

	
	// Neue Zeile editieren
	[tableView_ editColumn:0 
			   row:[kontenController_ selectionIndex]
		     withEvent:nil
			select:YES];
}


- (IBAction)loescheKonto:(id)sender
{
	int idx = [kontenController_ selectionIndex];
	if (idx != NSNotFound) {
		Konto * konto = [[kontenController_ selectedObjects] objectAtIndex:0];
		// Konten ohne Buchungen werden gleich geloescht
		if ([[konto buchungen] count] == 0) {
			[kontenController_ remove:self];
			return;
		}
		
		// Sonst vorher fragen
		int ret = NSRunAlertPanelRelativeToWindow(
			NSLocalizedString(@"Caution", nil),
			NSLocalizedString(@"Are you sure you want to delete the account '%@'?", nil),
			NSLocalizedString(@"Yes, delete it!", nil),
			NSLocalizedString(@"Cancel", nil),
			nil,
			[prefWindowCtrl_ window],
			[konto bezeichnung]);
		if (ret == NSAlertDefaultReturn)
			[kontenController_ remove:self];
	}
}


- (void)banknameErmittelnThread:(NSManagedObjectID *)kontoId
{	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	NSError * error = nil;
	
	// Thread CoreData-Context erstellen
	NSManagedObjectContext * ctx = [[[NSManagedObjectContext alloc] init] autorelease];
	[ctx setPersistentStoreCoordinator:[[NSApp delegate] persistentStoreCoordinator]];
	[ctx setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
	
	// Konto-Objekt im Thread-Context erstellen
	Konto * konto = (Konto *)[ctx objectWithID:kontoId];
	
	// Accounts vom hbcitool bekommen
	@synchronized (hbcitoolLoader_) {
		@try {
			[[hbcitoolLoader_ banking] updateBankName:konto];
		}
		@catch (NSException * e) {
			error = [self error:[e description]];
		}
	}
	
	// Thread-Ende an Hauptthread melden
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[self performSelectorOnMainThread:@selector(banknameErmittelnEnde:) withObject:error waitUntilDone:NO];
	[pool release];
}


- (void)banknameErmittelnEnde:(NSError *)error
{
	// BankInfos vorhanden?
	[self bankInfosPruefen:[NSNotification notificationWithName:@"Bankleitzahl" object:nil]];
	[self quitHbcitoolLoader];
	
	// ProgressIndikator ausschalten
	[piBankWirdErmittelt_ stopAnimation:self];
	[piBankWirdErmittelt_ setHidden:YES];
	
	// Fehler-Sheet zeigen
	if (!showErrorIfAny_)
		return;
	if (error != nil) {
		[self presentHbciError:error];
		return;
	}
}


- (void)banknameErmitteln:(Konto *)konto
{
	// Erst mit Fints-Datenbank probieren
	NSArray * bankDaten = [fintsInstituteLeser_ bankDaten:[konto bankleitzahl]];
	if (bankDaten) {
		// Was gefunden
		NSString * url = [bankDaten objectAtIndex:FintsInstitutePinTanUrl];
		NSString * name = [bankDaten objectAtIndex:FintsInstituteName];
		NSString * hbciVer = [bankDaten objectAtIndex:FintsInstituteHbciVersion];
		if (url && [url length] == 0)
			url = nil;
		if (name && [name length] == 0)
			name = nil;
		
		if (url) {
			NSLog(@"Server in fints_institute gefunden: %@", url);
			[konto setServer:url];
		}
		if (name) {
			NSLog(@"Bankname in fints_institute gefunden: %@", name);
			[konto setBankname:name];
		}
		if (hbciVer) {
			if ([hbciVer isEqualToString:@"4.0"])
				[konto setHbciVersion:[NSNumber numberWithInt:400]];
			else if ([hbciVer isEqualToString:@"3.0"])
				[konto setHbciVersion:[NSNumber numberWithInt:300]];
			else if ([hbciVer isEqualToString:@"2.2"])
				[konto setHbciVersion:[NSNumber numberWithInt:220]];
			else if ([hbciVer isEqualToString:@"2.1"])
				[konto setHbciVersion:[NSNumber numberWithInt:210]];
			else if ([hbciVer isEqualToString:@"2.0.1"])
				[konto setHbciVersion:[NSNumber numberWithInt:201]];
		}
		
		// beides hat geklappt?
		if (url && name) {
			[self banknameErmittelnEnde:nil];
			return;
		}
	}
	
	// dann mit der AqBanking-Datenbank:
	// hbcitool laden
	if (hbcitoolLoader_ == nil) {
		hbcitoolLoader_ = [[HbciToolLoader alloc] init];
		[hbcitoolLoader_ addLogView:statusLogView_];
		[theAppCtrl leereLogView];
		[hbcitoolLoader_ addLogView:[theAppCtrl logView]];
	}
	
	// Eigentlichen hbcitool-Aufruf im Thread durchfuehren, 
	// damit die GUI aktiv bleibt.
	showErrorIfAny_ = YES;
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[NSThread detachNewThreadSelector:@selector(banknameErmittelnThread:)
				 toTarget:self withObject:[konto objectID]];	
}


- (int)blzLaengeNachLand {
	// Unterscheidung der Laender -> Bankleitzahllaenge
	return 8;
	// NSString *land = [konto land];
	// FIXME: Land - Fuer spaetere Aenderungen des verwendeten Standards -> fuer die nicht zu fruehe Anzeige
	// der Warnungen 
	/*switch (land) {
	 case @"ca": l = 8; // Canada 
	 break;
	 case @"at": l = 8; // Austria
	 break;
	 case @"de": l = 8; // Deutschland
	 break;
	 case @"us": l = 8; // United States
	 break;
	 case @"ch": l = 8; // Schweiz
	 break;
	 default: l = 8;
	 break;
	 }*/	
}


- (void)bankWikiLaden
{
	if ([[tfBankleitzahl stringValue] length] >= [self blzLaengeNachLand]) {
		NSString * blzUrl = [NSString stringWithFormat:@"%@%@", LIMOIA_BANKENWIKI_BLZURL, [tfBankleitzahl stringValue]];
		[[webView_ mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:blzUrl]]];
	}	
}


- (void)drawerDidOpen:(NSNotification *)notification {
	[self bankWikiLaden];	
}


- (void)bankdatenAktualisieren {
	// Banknamen aktualisieren
	Konto * konto = [self currentKonto];
	
	// Banknamen aktualisieren
	if (konto && [[tfBankleitzahl stringValue] length] >= [self blzLaengeNachLand]) {
		// ProgressIndikator starten
		[piBankWirdErmittelt_ setHidden:NO];
		[piBankWirdErmittelt_ startAnimation:self];
		
		// Alten Server entfernen
		[konto setServer:@""];
		
		// Versuchen, neue Bankinfos zu setzen
		[self banknameErmitteln:konto];
	} else
		[konto setBankname:@""];
	
	// BankWiki-Webseite laden
	if ([drawer_ state] != NSDrawerClosedState)
		[self bankWikiLaden];
}


- (void)controlTextDidChange:(NSNotification *)aNotification
{	
	if ([aNotification object] != tableView_) {	// Beim Editieren des Kontonames nichts ermitteln.
		[self vollstaendigkeitPruefen];
		
		// Warnungen und Bestaetigungen entfernen
		[BanknameView_ setHidden:YES];
		[ServerWarningView_ setHidden:YES];
		
		// Wenn TextField Kennung geaendert wird
		if ([aNotification object] == tfKennung) {
			[self bankInfosPruefen:[NSNotification notificationWithName:@"Bankleitzahl" object:nil]];
		}
		
		// Banknamen aktualisieren
		if ([aNotification object] == tfBankleitzahl) {
			[self bankdatenAktualisieren];
		}
	}
}


- (IBAction)bankMelden:(id)sender
{
	NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:
				 [tfBankleitzahl stringValue], @"bankleitzahl",
				 [tfBankname stringValue], @"bankname",
				 [tfServer stringValue], @"server",
				 nil];
	NSString * url = [NSString stringWithFormat:LIMOIA_BANK_MELDEN_URL,
			  [params webFormEncoded]];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
}


- (IBAction)feedLaden:(id)sender
{
	Konto * konto = [self currentKonto];
	if (konto)
		[[theAppCtrl feedServerController] oeffneFeedFuerKonto:konto];
}


- (IBAction)exportMethodeConfig:(id)sender
{
	Konto * konto = [self currentKonto];
	if (konto) {
		// richtigen Sheet anzeigen
		switch ([[konto exportMethode] intValue]) {
				
				
			// ### QIF-Exports START ###
			case KontoExportiBank:
				[NSApp beginSheet:iBankWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
			case KontoExportMoneywell:
				[NSApp beginSheet:moneywellWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
			case KontoExportiFinance3:
				[NSApp beginSheet:iFinance3WindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
			case KontoExportiFinance3AppStore:
				[NSApp beginSheet:iFinance3WindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
			case KontoExportSquirrel:
				[NSApp beginSheet:squirrelWindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
			case KontoExportChaChing2:
				[NSApp beginSheet:chaChing2WindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
			case KontoExportiBank4:
				[NSApp beginSheet:iBank4WindowSheet_ modalForWindow:[prefWindowCtrl_ window]
				    modalDelegate:nil didEndSelector:nil contextInfo:nil];
				break;
				
			// FIXME: Qif faehige Programme (1)
			// ### QIF-Exports ENDE ###
				
				
			default:break;
			
		}
	}
}



- (IBAction)qifExportZurueckSetzen:(id)sender
{
	Konto * konto = [self currentKonto];
	if (konto) {
		[konto setMoneywellExportVon:nil];
		[konto setMoneywellExportBis:nil];
	}
}



// ### QIF-Exports START ###
- (IBAction)moneywellCloseClicked:(id)sender {
	[moneywellWindowSheet_ orderOut:self];
	[NSApp endSheet:moneywellWindowSheet_];
}
- (IBAction)iFinance3CloseClicked:(id)sender{
	[iFinance3WindowSheet_ orderOut:self];
	[NSApp endSheet:iFinance3WindowSheet_];
}
- (IBAction)squirrelCloseClicked:(id)sender{
	[squirrelWindowSheet_ orderOut:self];
	[NSApp endSheet:squirrelWindowSheet_];
}
- (IBAction)chaChing2CloseClicked:(id)sender{
	[chaChing2WindowSheet_ orderOut:self];
	[NSApp endSheet:chaChing2WindowSheet_];
}
- (IBAction)iBank4CloseClicked:(id)sender{
	[iBank4WindowSheet_ orderOut:self];
	[NSApp endSheet:iBank4WindowSheet_];
}

// FIXME: Qif faehige Programme (2)
// ### QIF-Exports ENDE ###



- (IBAction)iBankExportZurueckSetzen:(id)sender
{
	Konto * konto = [self currentKonto];
	if (konto) {
		[konto setIBankExportVon:nil];
		[konto setIBankExportBis:nil];
	}
}

- (IBAction)iBankKontenAbfragen:(id)sender
{
	// AppleScript ausfuehren, um die Konten zu ermitteln
	NSString * scriptSource = 
	@"tell application \"iBank\"\n"
	"	name of every account of first document\n"
	"end tell";
	NSAppleScript * script = [[[NSAppleScript alloc] initWithSource:scriptSource] autorelease];
	NSDictionary * errorDict = nil;
	NSAppleEventDescriptor * ae = [script executeAndReturnError:&errorDict];
	if (ae == nil) {
		NSRunAlertPanelRelativeToWindow(
			NSLocalizedString(@"iBank", nil),
			NSLocalizedString(@"Could not get the accounts from iBank. Maybe it is not (correctly) installed.", nil),
			NSLocalizedString(@"Ok", nil), nil, nil,
						[[self view] window]);
		NSLog(@"AppleScript-Fehler: %@", errorDict);
		return;
	}
	
	int n = [ae numberOfItems];
	NSLog(@"AppleScript-Antwort: %d items", n);
	[iBankKonten_ removeAllItems];

	// Konten gefunden?
	if (n == 0) {
		NSRunInformationalAlertPanelRelativeToWindow(
					NSLocalizedString(@"iBank", nil),
					NSLocalizedString(@"iBank did not return any account. You can only export if you create one.", nil),
					NSLocalizedString(@"Ok", nil), nil, nil,
							     [[self view] window]);
		return;
	}

	// das (hoffentlich) Kontenarray auswerten
	int i;
	for (i = 0; i < n; ++i) {
		// Listenelement ist der Name, "one-based"
		NSAppleEventDescriptor * nameAe = [ae descriptorAtIndex:1 + i];
		if (!nameAe)
			continue;
		NSString * name = [nameAe stringValue];
		NSLog(@"Found account '%@'", name);

		// In die Combobox eintragen
		[iBankKonten_ addItemWithObjectValue:name];
	}
	
	// Was auswaehlen, wenn nichts gewaehlt ist
	if (n > 0 && ([iBankKonten_ stringValue] == nil 
		      || [[iBankKonten_ stringValue] length] == 0)) {
		[iBankKonten_ setStringValue:[iBankKonten_ itemObjectValueAtIndex:0]];
		[[self currentKonto] setIBankExportAktiv:[NSNumber numberWithBool:YES]];
	}
	[iBankKonten_ performClick:self];
}

- (IBAction)iBankCloseClicked:(id)sender {
	[iBankWindowSheet_ orderOut:self];
	[NSApp endSheet:iBankWindowSheet_];
}



- (IBAction)nachiBankExportieren:(id)sender
{
	if (![[theAppCtrl standardVersion] boolValue])
		[[theAppCtrl ibankExporter] export:[self currentKonto]];
}

- (IBAction)nachQifExportieren:(id)sender
{
	if (![[theAppCtrl standardVersion] boolValue])
		//[[theAppCtrl moneywellExporter] export:[self currentKonto]];
		[[theAppCtrl universalQifExporter] export:[self currentKonto]];
}




- (IBAction)expertenSheetZeigen:(id)sender
{
	[NSApp beginSheet:[expertenKontoCtrl_ window] modalForWindow:[prefWindowCtrl_ window]
	    modalDelegate:nil didEndSelector:nil contextInfo:nil];	
}


- (IBAction)zuruecksetzen:(id)sender
{
	Konto * konto = [self currentKonto];
	if (konto) {
		[konto setBenutzerId:nil];
		[konto setKundenId:nil];
		[konto setHbciVersion:[NSNumber numberWithInt:220]];
		[self bankdatenAktualisieren];
	}	
}


- (IBAction)geheNachHause:(id)sender {
	if ([[tfBankleitzahl stringValue] length] >= [self blzLaengeNachLand]) {
		NSString * blzUrl = [NSString stringWithFormat:@"%@%@", LIMOIA_BANKENWIKI_BLZURL, [tfBankleitzahl stringValue]];
		[[webView_ mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:blzUrl]]];
	}
}


- (IBAction)geheZurOnlineHilfe:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_HILFE_BANKVERBINDUNG_URL]];
}


- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation 
	request:(NSURLRequest *)request frame:(WebFrame *)frame 
	decisionListener:(id < WebPolicyDecisionListener >)listener
{
	NSString * url = [[request URL] absoluteString];
	NSLog(@"Navigating %@", url);
	if ([url isMatchedByRegex:LIMOIA_WIKI_REGEXP])
		[listener use];
	else {
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
}


@end
