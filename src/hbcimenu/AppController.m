//
//  AppController.m
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "AppController.h"

#import "../Sparkle.framework/Headers/Sparkle.h"
#import "../Sparkle.framework/Headers/SUConstants.h"

#import "AktionenController.h"
#import "AppDelegate.h"
#import "Buchung.h"
#import "CodeChecker.h"
#import "debug.h"
#import "DebugWindowController.h"
#import "DockIconController.h"
#import "ErrorWindowController.h"
#import "GrowlController.h"
#import "iBankExporter.h"
#import "UniversalQifExporter.h"
#import "IconController.h"
#import "Konto.h"
#import "LogWindowController.h"
#import "MenuIconView.h"
#import "NSString-Levenshtein.h"
#import "PrefWindowController.h"
#import "svnrevision.h"
#import "Version.h"
#import "urls.h"

#import "UKCrashReporter.h"


AppController * theAppCtrl = nil;


@interface Konto (AddrIdent)
- (NSString *)addrIdent;
@end
@implementation Konto (AddrIdent)
- (NSString *)addrIdent
{
	return [NSString stringWithFormat:@"%d", self]; 
}
@end


@implementation AppController

+ (void)initialize {	
	// Warum wird die Methode mehrfach aufgerufen?
	static BOOL erstesMal = YES;
	if (!erstesMal)
		return;
	erstesMal = NO;
	
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSLog(@"foobar");
	
	// Standard-Konfiguration setzen. Dies muss passieren, bevor irgendein
	// Dialog geladen ist aus den Nibs.
	NSDictionary * appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
				      [NSNumber numberWithInt:NO], @"startedBefore",
				      [NSNumber numberWithInt:YES], @"autoload",
				      [NSNumber numberWithInt:2], @"interval",
				      [NSNumber numberWithInt:12], @"deleteAfterMonth",
				      [NSNumber numberWithInt:86400], SUScheduledCheckIntervalKey,
				      [NSNumber numberWithBool:YES], SUEnableAutomaticChecksKey,
				      [NSNumber numberWithBool:YES], @"alwaysShowSubmenuForAccounts",
				      [NSNumber numberWithDouble:3.0], @"gelesenMarkierenNach",
				      [NSNumber numberWithBool:NO], @"gelesenMarkieren",
				      [NSNumber numberWithInt:1], @"FontMenuKontenView",
				      [NSNumber numberWithBool:NO], @"startFeedServer",
				      [NSNumber numberWithInt:0], @"feedLadenVerhalten",
				      [NSNumber numberWithBool:YES], @"sendStatisticInfo",
				      [NSNumber numberWithInt:0], @"saldoInMenuFontSize",
				      [NSNumber numberWithBool:YES], @"showTransactionCounters",
				      [NSNumber numberWithBool:NO], @"betaLadenAnzeigen",
				      [NSNumber numberWithBool:NO], @"automatischSperren",
				      [NSNumber numberWithBool:NO], @"sperrenBeimStart",
				      [NSNumber numberWithBool:YES], @"pseudoOffen",
				      [NSNumber numberWithDouble:3.0], @"sperrenNach",
				      [NSMutableArray array], @"filters",
				      [NSNumber numberWithBool:YES], @"playLockSound",
				      [NSNumber numberWithInt:0], @"hbciCrashCount",
				      [NSDate date], @"hbciCrashLast",
				      nil];
	[defaults registerDefaults:appDefaults];
	
	// Alte Logs und Messages wegraeumen
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", @"find ~/Library/Application\\ Support/Saldomat-*/ \\( -name '*.log' -or -name '*.msg' \\) -exec rm {} +", nil]];
#ifdef DEBUG
	NSLog(@"Deleting old logs");
	[task setStandardOutput:[NSPipe pipe]];
#endif
	//The magic line that keeps your log where it belongs
	[task setStandardInput:[NSPipe pipe]];
	[task launch];
	
	// Daten umkopieren in neues 1.4er-Verzeichnis
#ifdef DEBUG
	NSString * dpath10 = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/Saldomat-debug"];
	NSString * format = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/Saldomat-%d.%d-debug"];
#else
	NSString * dpath10 = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/Saldomat"];
	NSString * format = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/Saldomat-%d.%d"];
#endif
	
	NSFileManager * fm = [NSFileManager defaultManager];
	NSString * appDir = [AppDelegate applicationSupportFolder];
	if (![fm fileExistsAtPath:appDir]) {
		// neueste Config-Version suchen...
		NSString * dpath = nil;
		NSString * oldVersion = nil;
		int maj = VERSION_MAJOR;
		int min = VERSION_MINOR - 1;
		for (; maj > 0; maj--) {
			for (; min >= 0; min--) {
				NSString * maj_min_path = [NSString stringWithFormat:format, maj, min, nil];
				if ([fm fileExistsAtPath:maj_min_path]) {
					dpath = maj_min_path;
					oldVersion = [NSString stringWithFormat:@"%d.%d", maj, min, nil];
					break;
				}
			}
			min = 9;
		}
		
		// 1.0er-Version hatte noch keine Version im Verzeichnisnamen
		if (oldVersion == nil && [fm fileExistsAtPath:dpath10]) {
			dpath = dpath10;
			oldVersion = @"1.0";
		}
		
		if (oldVersion) {
			NSRunAlertPanel(
				[NSString stringWithFormat:NSLocalizedString(@"Saldomat %@ Update", nil),
				 VERSION_MAJORMINOR],
				[NSString stringWithFormat:NSLocalizedString(@"Your database will now be copied and "
						  "converted for Saldomat %@. The old database files will "
						  "not be touched. If you experience problems with the new version, "
						  "you can always go back to %@.", nil), VERSION_MAJORMINOR, oldVersion],
				NSLocalizedString(@"Ok", nil),
				nil, nil);
		
			NSLog(@"Kopiere Konfiguration von %@ nach %@", dpath, appDir);
			[fm createDirectoryAtPath:appDir attributes:nil];
			for (NSString * fname in [fm directoryContentsAtPath:dpath]) {
				if (![fname isEqualTo:@"backends"]) {
					NSLog(@"Kopiere %@", fname);
					[fm copyPath:[dpath stringByAppendingPathComponent:fname]
					      toPath:[appDir stringByAppendingPathComponent:fname]
					     handler:nil];
				}
			}
		}
	}
	
	
	[super initialize];
}


- (id)init
{
	self = [super init];
	theAppCtrl = self;
	filters_ = [SharedFilters new];
	debugWindowCtrl_ = nil;
	ibankExporter_ = [iBankExporter new];
	universalQifExporter_ = [UniversalQifExporter new];
	proVersion_ = [NSNumber numberWithBool:YES];
	standardVersion_ = [NSNumber numberWithBool:NO];
#ifdef DEBUG
	debugMenu_ = YES;
#else
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	debugMenu_ = [defaults boolForKey:@"debugMenu"];
#endif
	automatischGestarteteKontoauszuege_ = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(applicationDidFinishLaunching:)
						     name:NSApplicationDidFinishLaunchingNotification
						   object:nil];
	return self;
}


- (void)awakeFromNib
{
	NSLog(@"AppController awakeFromNib");
	
	// Crash-logs suchen
	UKCrashReporterCheckForCrash(@"Saldomat");
	UKCrashReporterCheckForCrash(@"Saldomat hbcitool");

	// Kontoverwaltung
	wartendeKonten_ = [NSMutableArray new];
	laufenderKontoauszug_ = nil;
	errorWindowCtrls_ = [NSMutableDictionary new];
	[konten_ fetchWithRequest:nil merge:NO error:nil];

	// Betalogo?
	if (!VERSIONBETA)
		[betaView_ setHidden:YES];
	
	// Sortieren nach "order"
	[konten_ setSortDescriptors:
	 [NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES] autorelease]]];
	
	// Sortierung setzen, falls sie es nicht schon ist
	int i;
	for (i = 0; i < [[konten_ arrangedObjects] count]; ++i) {
		Konto * k = [[konten_ arrangedObjects] objectAtIndex:i];
		[k setOrder:[NSNumber numberWithInt:i]];
	}
	
	// Keychain schon mal oeffnen
#if 0
	HbciToolLoader * hbcitoolLoader = 0;
	@try {
		hbcitoolLoader = [[HbciToolLoader alloc] init];

		// CocoaBanking-Objekt bekommen
		[hbcitoolLoader banking];
	}
	@catch (NSException * e) {
		NSLog(@"Could not start hbcitool for first keychain access");
		// FIXME: Fehler-GUI bauen
	}
	@finally {
		[hbcitoolLoader unload];
		[hbcitoolLoader release];
	}
#endif

	// Updates nach Versionen machen
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults integerForKey:@"letzteVersion"] < 1208) {
		// Semantik vom "Beim Gesamt-Saldo mitzaehlen" hat sich geaendert. Neben
		// dem Euro-Symbol ist jetzt normalerweise aus
		for (Konto * konto in [konten_ arrangedObjects]) {
			[konto setSaldoImMenu:[NSNumber numberWithBool:YES]];
		}
		[defaults setInteger:0 forKey:@"saldoInMenuFontSize"];
	}
	
	// Version merken in Config
	[defaults setObject:[NSNumber numberWithInt:NUMSVNREVISION] forKey:@"letzteVersion"];
	
	// Aufraeumen von alten Buchungen, die keinem Konto gehoeren
/*	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	NSFetchRequest * fetch = [[[NSFetchRequest alloc] init] autorelease];
	fetch.entity = [NSEntityDescription entityForName:@"Buchung" inManagedObjectContext:ctx];
	fetch.predicate = [NSPredicate predicateWithFormat:@"konto == nil"];
	NSArray * ungueltigeBuchungen = [ctx executeFetchRequest:fetch error:nil];
	if (ungueltigeBuchungen && [ungueltigeBuchungen count] > 0) {
		NSLog(@"Deleting %d zombie transactions.", [ungueltigeBuchungen count]);
		for (Buchung * b in ungueltigeBuchungen)
			[ctx deleteObject:b];
		[(AppDelegate *)[NSApp delegate] saveAction:self];
	}
*/
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Dialog fuer ersten Start
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	NSNumber * startedbefore = [defaults objectForKey:@"startedBefore"];
	if (startedbefore == nil || [startedbefore boolValue] == NO) {
		[defaults setBool:YES forKey:@"startedBefore"];
		[defaults setBool:YES forKey:@"autoload"];
		
		// Pref-Fenster zeigen
		NSLog(@"Zeige Start-Fenster");
		[NSApp activateIgnoringOtherApps:YES];
		[ersterStartWindow_ orderFront:self];
		
		// Growl-Installation fragen
		//[growlController_ aufGrowlInstallationPruefen];
	}
}


- (void)saveUserDefaults
{
	// UserDefaults speichern
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults synchronize]) {
		NSLog(@"UserDefaults konnten nicht gespeichert werden.");
	}
}


- (void)dealloc {
	NSLog(@"AppController dealloc");
	
	[wartendeKonten_ release];
	[laufenderKontoauszug_ release];
	[errorWindowCtrls_ release];
	[filters_ release];
	[ibankExporter_ release];
	[moneywellExporter_ release];
	[universalQifExporter_ release];
	[standardVersion_ release];
	[proVersion_ release];
	
	[self saveUserDefaults];
	[super dealloc];
}


- (Kontoauszug *)laufenderKontoauszug
{
	return laufenderKontoauszug_;
}


- (void)setLaufenderKontoauszug:(Kontoauszug *)kontoauszug
{
	[laufenderKontoauszug_ autorelease];
	[laufenderKontoauszug_ cancel];
	laufenderKontoauszug_ = [kontoauszug retain];
}


- (IBAction)showPreferences:(id)sender
{
	//[prefWindowCtrl_ clickAllgemein:self];
	[NSApp activateIgnoringOtherApps:YES];
	[[prefWindowCtrl_ window] makeKeyAndOrderFront:self];
}


- (IBAction)showKontoPreferences:(id)sender
{
	[prefWindowCtrl_ clickKonten:self];
	[NSApp activateIgnoringOtherApps:YES];
	[[prefWindowCtrl_ window] makeKeyAndOrderFront:self];
	if ([[konten_ arrangedObjects] count] == 0) {
		[prefWindowCtrl_ neuesKonto:self];
	}
}


- (IBAction)showFeedPreferences:(id)sender
{
	[prefWindowCtrl_ clickFeed:self];
	[NSApp activateIgnoringOtherApps:YES];
	[[prefWindowCtrl_ window] makeKeyAndOrderFront:self];
	if ([[konten_ arrangedObjects] count] == 0) {
		[prefWindowCtrl_ neuesKonto:self];
	}
}


- (IBAction)showAbout:(id)sender
{
	[prefWindowCtrl_ clickAbout:self];
	[NSApp activateIgnoringOtherApps:YES];
	[[prefWindowCtrl_ window] makeKeyAndOrderFront:self];
}


- (IBAction)geheZurHomepage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_PRODUKT_URL]];
}


- (IBAction)geheZurOnlineHilfe:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_HILFE_URL]];
}


- (IBAction)verbesserungsVorschlag:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_IDEE_URL]];
}


- (IBAction)ersterStartWindowKontoAnlegen:(id)sender
{
	[ersterStartWindow_ orderOut:self];
	[[iconCtrl_ iconView] mouseDown:nil];
//	[self showKontoPreferences:self];
}


- (BOOL)starteKontoauszugFuerKonto:(Konto *)konto
{
	NSLog(@"Starting getTransactions for %@", [konto bezeichnung]);
	
	BOOL laufend = [[self laufenderKontoauszug] konto] == konto;
	BOOL wartend = [wartendeKonten_ indexOfObject:konto] != NSNotFound;
	
	// laeuft schon?
	if (laufend || wartend)
		return NO;
	
	// Auf Wartestellung, wenn schon was laeuft
	if ([self laufenderKontoauszug])
		[wartendeKonten_ addObject:konto];
	else {
		// Kontoauszug starten
		Kontoauszug * kontoauszug = [[[Kontoauszug alloc] initWithKonto:konto
							   automatischGestartet:automatischGestarteteKontoauszuege_]
					     autorelease];
		[kontoauszug setDelegate:self];
		[self leereLogView];
		[self setLaufenderKontoauszug:kontoauszug];
		BOOL ok = [kontoauszug start];
		
		// Gestartet?
		if (!ok) {
			[self setLaufenderKontoauszug:nil];
			return NO;
		}
	}
	
	return YES;
}


- (void)naechsterKontoauszugAusWarteschlange
{
	if (laufenderKontoauszug_)
		return;
	if ([wartendeKonten_ count] == 0)
		return;
	
	// Ersten wartenden Kontoauszug starten
	Konto * konto = [[wartendeKonten_ objectAtIndex:0] retain];
	[wartendeKonten_ removeObjectAtIndex:0];
	BOOL ok = [self starteKontoauszugFuerKonto:konto];
	[konto release];
	
	// Erfolgreich? Sonst mit dem naechsten versuchen
	if (!ok)
		[self naechsterKontoauszugAusWarteschlange];
}


- (void)stopKontoauszugFuerKonto:(Konto *)konto
{
	BOOL laufend = [[self laufenderKontoauszug] konto] == konto;
	BOOL wartend = [wartendeKonten_ indexOfObject:konto] != NSNotFound;
	
	// abschiessen?
	if (laufend) {
		[[self laufenderKontoauszug] cancel]; 
		// dabei wird eine der finish*-Methoden aufgerufen, die
		// laufenderKontoauszug_ auf nil setzt
		[self naechsterKontoauszugAusWarteschlange];
		return;
	}
	
	// aus Warteschlange entfernen?
	if (wartend)
		[wartendeKonten_ removeObject:konto];
}


- (IBAction)holeKontoauszugFuer:(Konto *)konto
{	
	// manueller Modus => alle Fehlermeldungen
	automatischGestarteteKontoauszuege_ = NO;
	
	[self starteKontoauszugFuerKonto:konto];
}


- (IBAction)holeAlleKontoauszuege:(id)sender
{
	// manueller Modus => alle Fehlermeldungen
	automatischGestarteteKontoauszuege_ = NO;

	for (Konto * konto in [konten_ arrangedObjects]) {
		BOOL laufend = [[self laufenderKontoauszug] konto] == konto;
		BOOL wartend = [wartendeKonten_ indexOfObject:konto] != NSNotFound;
		if (!laufend && !wartend)
			if ([[konto automatisch] boolValue]) {
				[wartendeKonten_ addObject:konto];
			}
	}
	
	[self naechsterKontoauszugAusWarteschlange];
}


- (void)starteKontoauszuegePerSync
{
	// wenn nichts laeuft, in automatischen Modus gehen, d.h. Fehlermeldungen werden
	// unterdrueckt, wenn der letzte Erfolgreiche Auszug nicht lange zurueck lag.
	if ([wartendeKonten_ count] == 0 && laufenderKontoauszug_ == nil)
		automatischGestarteteKontoauszuege_ = YES;
	
	// Kontoauszuege starten bzw. in Warteschlange, wenn sie es noch nicht sind
	for (Konto * konto in [konten_ arrangedObjects]) {
		BOOL laufend = [[self laufenderKontoauszug] konto] == konto;
		BOOL wartend = [wartendeKonten_ indexOfObject:konto] != NSNotFound;
		if (!laufend && !wartend && [[konto automatisch] boolValue])
			[wartendeKonten_ addObject:konto];
	}
	
	[self naechsterKontoauszugAusWarteschlange];
}


- (void)finishedKontoauszug:(Kontoauszug *)kontoauszug
{
	NSLog(@"Finished getTransactions for %@", [[kontoauszug konto] bezeichnung]);
	Konto * konto = [kontoauszug konto];

	// um ein neues Ueberschreiten zu erkennen. Siehe unten.
	BOOL vorherSaldoWarnung = [konto warnSaldoUnterschritten];
	
	// neue Buchungen finden
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	NSEntityDescription * buchungEntity = [NSEntityDescription entityForName:@"Buchung" inManagedObjectContext:ctx];
	NSArray * buchungen = [kontoauszug buchungen];
	NSMutableArray * neueBuchungen = [NSMutableArray array];
	
	for (Buchung * b in buchungen) {
		// Praedikat, das alle Buchungen filtert, die b entsprechen
		NSPredicate *predicate =
		[NSPredicate predicateWithFormat:@"(konto == %@) "
			"AND (primaNota == %@) "
			"AND (wert == %@) "
			"AND (waehrung == %@) "
			"AND (datum == %@) "
			"AND (anderesKonto == %@) "
			"AND (andereBank == %@)",
			konto,
			[b primaNota],
			[b wert],
			[b waehrung],
			[b datum],
			[b anderesKonto],
			[b andereBank]
		];
		// FIXME: Wertstellung noch unberuecksichtigt, da nicht alle Buchungen darueber verfuegen.
		
		NSFetchRequest * fetch = [[[NSFetchRequest alloc] init] autorelease];
		fetch.entity = buchungEntity;
		fetch.predicate = predicate;
		
		// Buchungen bekommen, die b entsprechen
		NSArray * gleicheBuchungen = [ctx executeFetchRequest:fetch error:nil];
		BOOL neu = NO;
		NSString * strippedZweck = [[[b zweck] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] 
					    stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@".-_#* "]];
		if ([gleicheBuchungen count] == 0)
			neu = YES;
		else {
			neu = YES;
			//int aehnliche = 0;
			//Buchung * aehnlicheBuchung = nil;
			for (Buchung * b2 in gleicheBuchungen) {
				//NSLog(@"String1 vor Strip: %@",[b2 zweck]);
				NSString * strippedZweck2 = [[[b2 zweck] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
							     stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@".-_#* "]];
				//NSLog(@"strippedString1: %@",strippedZweck);
				//NSLog(@"strippedString2: %@",strippedZweck2);
				if ([strippedZweck isEqualToString:strippedZweck2]) {
					neu = NO;
					//aehnlicheBuchung = b2;
					//aehnliche++;
				}
			}
			
			// nur eine Buchung aehnlich? Dann ueberschreiben wir einige Felder
			//if (aehnliche == 1) 
			//	[aehnlicheBuchung setZweck:[b zweck]];
		}
			
			
		/*else if ([b primaNota] != nil && [[b primaNota] length] > 0) {
			neu = YES;
			int aehnliche = 0;
			Buchung * aehnlicheBuchung = nil;
			for (Buchung * b2 in gleicheBuchungen) {
				// Levenshtein (editing-) distance ausrechnen zwischen der neuen
				// und allen gefundenen
				NSString * strippedZweck2 = [[b2 zweck] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				float dist = [strippedZweck compareWithString:strippedZweck2];
				if (dist != 0)
					NSLog(@"dist(\"%@\", \"%@\") = %f", [b zweck], [b2 zweck], dist);
				if (dist <= 3) {
					NSLog(@"dist(\"%@\", \"%@\") = %f", [b zweck], [b2 zweck], dist);
					neu = NO;
					aehnlicheBuchung = b2;
					aehnliche++;
				}
			}
			
			// nur eine Buchung aehnlich? Dann ueberschreiben wir einige Felder
			if (aehnliche == 1) 
				[aehnlicheBuchung setZweck:[b zweck]];
		} else {
			// wenn wir keine Primanota haben:
			// => nur neu, wenn Zweck auch verschieden ist
			neu = YES;
			for (Buchung * b2 in gleicheBuchungen) {
				NSString * strippedZweck2 = [[b2 zweck] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				if ([strippedZweck isEqualToString:strippedZweck2]) {
					neu = NO;
					break;
				}
			}
		}*/
		
		// hinzufuegen oder loeschen
		if (neu) {
			NSLog(@"Neue Buchung: zweck=\"%@\" datum = %@ wert = %@ waehrung = %@", 
			      [b zweck], [b datum], [b wert], [b waehrung]);
			
			// Leerzeichen am Anfang und Ende entfernen
			[b setZweck:strippedZweck];
			
			// Buchung ist neu, also eintragen.
			[ctx assignObject:b toPersistentStore:globalStore];
			[b setKonto:konto]; // das fuegt die Buchung auch in Konto.buchungen ein
			[konto addNeueBuchungenObject:b];
			
			[neueBuchungen addObject:b];
		} else
			NSLog(@"Alte Buchung: zweck=\"%@\" datum = %@ wert = %@ waehrung = %@", 
			      [b zweck], [b datum], [b wert], [b waehrung]);
	}
	
	// Alte Buchungen loeschen
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	int loeschenNach = [[defaults objectForKey:@"deleteAfterMonth"] intValue];
	if (loeschenNach > 0) {
		// Todeslinie bestimmen
		float sekProMonat = 365.0*24.0*3600.0/12.0;
		NSDate * deadline = [NSDate dateWithTimeIntervalSinceNow:- sekProMonat * loeschenNach];
		NSLog(@"Wir loeschen Buchungen vor %@", deadline);
		
		// Buchungen sammeln, die alt genug sind
		NSPredicate *predicate = [NSPredicate predicateWithFormat:
		 @"(konto == %@) AND ((datum == NIL) OR (datum < %@))", konto, deadline];
		NSFetchRequest * fetch = [[[NSFetchRequest alloc] init] autorelease];
		fetch.entity = buchungEntity;
		fetch.predicate = predicate;
		NSArray * alteBuchungen = [ctx executeFetchRequest:fetch error:nil];
		NSLog(@"%d alte Buchungen gefunden", [alteBuchungen count]);
		
		// Growl melden
		[growlController_ meldeZuLoeschendeBuchungen:alteBuchungen fuerKonto:konto];
		
		// alte Buchungen loeschen
		if (alteBuchungen != nil) {
			for (Buchung * b in alteBuchungen) {
				NSLog(@"Deleting %@ because it's old: %@", [b zweck], [b datum]);
				[konto removeBuchungenObject:b];
				[konto removeNeueBuchungenObject:b];
				[b setKonto:nil];
				[ctx deleteObject:b];
			}
		}
		
		// Nun kennen wir nur noch Buchungen nach der Deadline.
		[konto setBuchungenVon:deadline];
	}
	
	// Saldo eintragen
	double neuerSaldo = [kontoauszug kontostand];
	if (isnan(neuerSaldo)) {
		if ([neueBuchungen count] > 0)
			[konto setSaldo:nil];
	} else {
		// Als letzten Kontostand speichern
		[konto setSaldo:[NSNumber numberWithDouble:neuerSaldo]];
		
		// # Saldo aufnehmen #
		NSMutableSet * saldos = [konto mutableSetValueForKey:@"saldos"];
		NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
		id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
		Saldo * s = [NSEntityDescription insertNewObjectForEntityForName:@"Saldo"
						inManagedObjectContext:ctx];
		[ctx assignObject:s toPersistentStore:globalStore];
		NSDecimalNumber * decSaldo = [NSDecimalNumber decimalNumberWithDecimal:[[NSNumber numberWithDouble:neuerSaldo] decimalValue]];
		[s setWert:decSaldo];
		[s setDatum:[NSDate date]];
		[s setWaehrung:@"EUR"];
		[saldos addObject:s];
	}

	// Zeitraum der Buchungen anpassen
	if ([buchungen count] > 0) {
		[konto setBuchungenBis:[NSDate date]];
		NSDate * von = [kontoauszug buchungenVon];
		if (von != nil) {
			NSDate * altVon = [konto buchungenVon];
			if (altVon != nil)
				von = [altVon earlierDate:von];
			[konto setBuchungenVon:von];
		}
	}
	NSLog(@"Kontoauszuege bekannt von %@ bis %@", [konto buchungenVon], [konto buchungenBis]);
	
	// Neue Buchungen per Growl melden
	[growlController_ meldeNeueBuchungen:neueBuchungen fuerKonto:konto];
	
	// Filter und deren Aktionen anwenden
	if (![[self standardVersion] boolValue])
		[aktionenController_ aktionenAusfuehren:neueBuchungen];
	
	// Neue Saldowarnung?
	BOOL saldoWarnung = [konto warnSaldoUnterschritten];
	if (saldoWarnung && !vorherSaldoWarnung)
		[growlController_ meldeSaldoWarnungFuerKonto:konto];
	
	// Etwaigen Konto-Fehler entfernen
	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:[konto addrIdent]];
	if (errorWindowCtrl) {
		[[errorWindowCtrl window] orderOut:self];
		[errorWindowCtrls_ removeObjectForKey:[konto addrIdent]];
	}
	
	// Warteschlange aktualisieren
	[self setLaufenderKontoauszug:nil];
	[self naechsterKontoauszugAusWarteschlange];
}


- (void)canceledKontoauszug:(Kontoauszug *)kontoauszug
{
	NSLog(@"Canceled getTransactions for %@", [[kontoauszug konto] bezeichnung]);
	[self setLaufenderKontoauszug:nil];
	[self naechsterKontoauszugAusWarteschlange];
}


- (void)finishedKontoauszug:(Kontoauszug *)kontoauszug withError:(NSError *)error
{
	NSLog(@"Finished getTransactions with error for %@", [[kontoauszug konto] bezeichnung]);
	[self setLaufenderKontoauszug:nil];
	
	NSData * data = [logWindowCtrl_ RFTDData];
	
	// ErrorWindow fuer Konto erzeugen. Wir speichern je eins in
	// errorWindowCtrls_. Es gibt also maximal ein solches Fenster pro
	// Konto auf dem Bildschirm.
	Konto * konto = [kontoauszug konto];
	NSString * kontoAddrIdent = [NSString stringWithFormat:@"%d", [kontoauszug konto]]; 
	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:kontoAddrIdent];
	if (errorWindowCtrl == nil) {
		errorWindowCtrl = [[[ErrorWindowController alloc] initWithError:error
								       forKonto:konto
								withLogRTFDData:data] autorelease];
		[errorWindowCtrls_ setObject:errorWindowCtrl forKey:kontoAddrIdent];
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(errorWindowWillClose:)
							     name:NSWindowWillCloseNotification
							   object:[errorWindowCtrl window]];
	} else
		[errorWindowCtrl updateError:error
				    forKonto:konto
			     withLogRTFDData:data];
	
	// kritischer Fehler (fuer die wird das ! neben dem Euro im Menu angezeigt
	BOOL kritisch = YES;
	if ([kontoauszug automatischGestartet] && [konto buchungenBis] != nil) {
		// Fehler, die vor dem Ablauf des eingestellten Intervalls*2 auftreten sind nicht
		// kritisch.
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		int interval = [defaults integerForKey:@"interval"] * 3600;
		int seitLetztemKontoauszug = [[NSDate date] timeIntervalSinceDate:[konto buchungenBis]];
		if (seitLetztemKontoauszug < interval * 2)
			kritisch = NO;
	}
	[errorWindowCtrl setKritischerFehler:kritisch];
		
	// Icon im Menue aktualisieren
	[iconCtrl_ updateIcon:self];

	// Growl
	if (kritisch)
		[growlController_ meldeKontoauszugFehler:kontoauszug fehlerMeldung:error];
	
	[self naechsterKontoauszugAusWarteschlange];
}


- (NSTextView *)logView
{
	return [logWindowCtrl_ logView];
}


- (void)leereLogView
{
	NSRange r;
	r.location = 0;
	r.length = [[[logWindowCtrl_ logView] textStorage] length];
	[[logWindowCtrl_ logView] replaceCharactersInRange:r withString:@""];
}


- (IBAction)showLog:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[[logWindowCtrl_ window] makeKeyAndOrderFront:sender];
}


- (NSArray *)wartendeKonten;
{
	return wartendeKonten_;
}


- (BOOL)kontoHatteFehler:(Konto *)konto
{
	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:[konto addrIdent]];
	return errorWindowCtrl != nil;
}


- (BOOL)kontoHatteKritischenFehler:(Konto *)konto
{
	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:[konto addrIdent]];
	return errorWindowCtrl != nil && [errorWindowCtrl kritischerFehler];
}


- (NSString *)kontoFehler:(Konto *)konto
{
	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:[konto addrIdent]];
	return [errorWindowCtrl fehlerMeldung];
}


- (IBAction)zeigeFehler:(Konto *)konto
{
	if ([[self authController] verschlossen])
		return;

	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:[konto addrIdent]];
	if (errorWindowCtrl) {
		[NSApp activateIgnoringOtherApps:YES];
		[[errorWindowCtrl window] orderFront:self];
	}
}


- (IBAction)versteckeFehler:(id)sender
{
	for (NSString * ident in errorWindowCtrls_) {
		ErrorWindowController * ewc = [errorWindowCtrls_ objectForKey:ident];
		[[ewc window] orderOut:self];
	}
}


- (IBAction)fehlerGesehen:(Konto *)konto
{
	ErrorWindowController * errorWindowCtrl = [errorWindowCtrls_ objectForKey:[konto addrIdent]];
	if (errorWindowCtrl) {
		[[errorWindowCtrl window] orderOut:self];
		[errorWindowCtrls_ removeObjectForKey:[konto addrIdent]];
		[iconCtrl_ updateIcon:self];
	}
}


- (void)errorWindowWillClose:(NSNotification *)notification
{
	// Wenn das ErrorWindow geschlossen wurde, ErrorWindowController entfernen
	NSWindow * win = [notification object];
	for (NSString * ident in errorWindowCtrls_) {
		ErrorWindowController * ewc = [errorWindowCtrls_ objectForKey:ident];
		if ([ewc window] == win) {
			[errorWindowCtrls_ removeObjectForKey:ident];
			[iconCtrl_ updateIcon:self];
			break;
		}
	}
}


- (void)zeigeBuchungsFensterMitKonto:(Konto *)konto
{
	[kontoWindowCtrl_ showWithKonto:konto];
}


- (void)zeigeBuchungsFensterMitBuchung:(Buchung *)buchung
{
	[kontoWindowCtrl_ showWithBuchung:buchung];
}


- (IBAction)kontoFensterAnzeigen:(id)sender
{
	[kontoWindowCtrl_ showWithKonto:nil];
}


- (IBAction)zeigeDebugWindow:(id)sender
{
	if (!debugWindowCtrl_)
		debugWindowCtrl_ = [[DebugWindowController alloc] initWithWindowNibName:@"DebugWindow"];
	[[debugWindowCtrl_ window] makeKeyAndOrderFront:self];
	[NSApp activateIgnoringOtherApps:YES];
}



- (NSArray *)konten
{
	return [konten_ arrangedObjects];
}


@synthesize sharedFilters = filters_;
@synthesize growlController = growlController_;
@synthesize aktionenController = aktionenController_;
@synthesize feedServerController = feedServerController_;
@synthesize updateController = updateController_;
@synthesize ibankExporter = ibankExporter_;
@synthesize moneywellExporter = moneywellExporter_;
@synthesize universalQifExporter = universalQifExporter_;
@synthesize dockIconController = dockIconController_;
@synthesize standardVersion = standardVersion_;
@synthesize proVersion = proVersion_;
@synthesize debugMenu = debugMenu_;
@synthesize authController = authController_;
@synthesize kontoWindowController = kontoWindowCtrl_;

@end
