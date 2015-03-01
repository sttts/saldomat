//
//  Kontoauszug.m
//  hbci
//
//  Created by Stefan Schimanski on 09.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Kontoauszug.h"

#import "AppDelegate.h"
#import "Buchung.h"
#import "CInvocationGrabber.h"
#import "debug.h"
#import "UKCrashReporter.h"


@implementation Kontoauszug

- (NSError *)error:(NSString *)desc
{
	NSDictionary * details = 
	[NSMutableDictionary dictionaryWithObject:NSLocalizedString(desc, nil)
					   forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:@"KontenController" code:1 userInfo:details];
}


- (id)initWithKonto:(Konto *)konto automatischGestartet:(BOOL)automatisch
{
	self = [super init];
	
	konto_ = [konto retain];
	hbcitoolLoader_ = nil;
	buchungen_ = [NSMutableArray new];
	kontostand_ = 0.0;
	kontostandWaehrung_ = @"EUR";
	wirdGeholt_ = NO;
	canceled_ = NO;
	buchungenVon_ = nil;
	automatischGestartet_ = automatisch;
	
	return self;
}


- (BOOL)bankIstHASPA:(Konto *)konto
{
	if ([[konto bankleitzahl] isEqualToString:@"20050550"]) {
		return YES;
	} else {
		return NO;
	}

	return NO;
}


- (void)setDelegate:(id<KontoauszugDelegate>)delegate
{
	delegate_ = delegate;
}


- (void)cancel
{
	if (hbcitoolLoader_) {
		canceled_ = YES;
		
		[hbcitoolLoader_ unload];
		[hbcitoolLoader_ release];
		hbcitoolLoader_ = nil;
	}
}


- (void)dealloc
{
	[self cancel];
	[kontostandWaehrung_ release];
	[buchungen_ release];
	[konto_ release];
	[buchungenVon_ release];
	[super dealloc];
}


- (BOOL)start
{
	if ([self wirdGeholt])
		return NO;
	
	canceled_ = NO;
	
	// hbcitool laden
	hbcitoolLoader_ = [[HbciToolLoader alloc] init];
	[hbcitoolLoader_ addLogView:[delegate_ logView]];

	// CocoaBanking-Objekt bekommen
	NSProxy<CocoaBankingProtocol> * banking = [hbcitoolLoader_ banking];
	if (banking == nil) {
		NSLog(@"hbcitool could not be started");
		[NSApp activateIgnoringOtherApps:YES];
		NSRunCriticalAlertPanel(NSLocalizedString(@"Initialisation Error", nil),
					NSLocalizedString(@"Could not start hbcitool.", nil),
					nil, nil, nil);
		[self cancel];
		return NO;
	}
	
	// alte Buchungen loeschen
	[buchungen_ removeAllObjects];
	[kontostandWaehrung_ autorelease];
	kontostandWaehrung_ = nil;	
	[buchungenVon_ release];
	buchungenVon_ = nil;
	
	// Eigentlichen hbcitool-Aufruf im Thread durchfuehren, damit die GUI aktiv bleibt.
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	[NSThread detachNewThreadSelector:@selector(holeKontoauszugThread:) toTarget:self withObject:banking];
	return YES;
}


- (void)holeKontoauszugEnde:(NSError *)error mitBuchungen:(NSArray *)rawBuchungen
{
	if (rawBuchungen) {
		NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
		for (NSDictionary * b in rawBuchungen) {
			// Werte von hbcitool entkoppeln
			NSDecimalNumber * wert = [[[b objectForKey:@"wert"] copy] autorelease];
			NSString * waehrung = [[[b objectForKey:@"waehrung"] copy] autorelease];
			NSString * zweck = [[[b objectForKey:@"zweck"] copy] autorelease];
			NSDate * datum = [[[b objectForKey:@"datum"] copy] autorelease];
			NSDate * datumGeladen = [[[b objectForKey:@"datumGeladen"] copy] autorelease];
			NSDate * datumWertstellung = [[[b objectForKey:@"datumWertstellung"] copy] autorelease];
			NSString * andereBank = [[[b objectForKey:@"anderebank"] copy] autorelease];
			NSString * anderesKonto = [[[b objectForKey:@"andereskonto"] copy] autorelease];
			NSString * andererName = [[[b objectForKey:@"anderername"] copy] autorelease];
			NSString * primanota = [[[b objectForKey:@"primanota"] copy] autorelease];
			NSString * art = [[[b objectForKey:@"art"] copy] autorelease];
			
			// Buchung erstellen
			Buchung * buchung = [NSEntityDescription insertNewObjectForEntityForName:@"Buchung" inManagedObjectContext:ctx];
			[buchung setWert:wert];
			[buchung setWaehrung:waehrung];
			[buchung setZweck:zweck];
			[buchung setDatum:datum];
			[buchung setDatumGeladen:datumGeladen];
			[buchung setDatumWertstellung:datumWertstellung];
			[buchung setArt:art];
			[buchung setPrimaNota:primanota];
			[buchung setAndererName:andererName];
			if (andereBank && [andereBank length] > 0)
				[buchung setAndereBank:andereBank];
			if (anderesKonto && [anderesKonto length] > 0)
				[buchung setAnderesKonto:anderesKonto];
			[buchungen_ addObject:buchung];
		}
		
		/*#ifdef DEBUG
		// ### kuenstliche doppelte Buchung ###
		Buchung * buchung2 = [NSEntityDescription insertNewObjectForEntityForName:@"Buchung" inManagedObjectContext:ctx];				
		[buchung2 setWert:[NSDecimalNumber decimalNumberWithString:@"42.00"]];
		[buchung2 setWaehrung:[NSString stringWithString:@"EUR"]];
		[buchung2 setZweck:[NSString stringWithString:@"FOOBAR24235346"]];
		[buchung2 setDatum:[NSDate dateWithString:@"2009-12-31 10:00:00 +0600"]];
		[buchung2 setDatumGeladen:[NSDate dateWithString:@"2009-12-31 10:00:00 +0600"]];
		[buchung2 setArt:[NSString stringWithString:@"FOO"]];
		[buchung2 setPrimaNota:[NSString stringWithString:@"100000"]];
		[buchung2 setAndererName:[NSString stringWithString:@"Max Musterfrau"]];
		[buchung2 setAndereBank:[NSString stringWithString:@"90000000"]];
		[buchung2 setAnderesKonto:[NSString stringWithString:@"1234567890"]];
		[buchungen_ addObject:buchung2];
		
		// ### kuenstliche doppelte Buchung ###
		Buchung * buchung3 = [NSEntityDescription insertNewObjectForEntityForName:@"Buchung" inManagedObjectContext:ctx];				
		[buchung3 setWert:[NSDecimalNumber decimalNumberWithString:@"42.00"]];
		[buchung3 setWaehrung:[NSString stringWithString:@"EUR"]];
		[buchung3 setZweck:[NSString stringWithString:@"FOOBAR24235346."]];
		[buchung3 setDatum:[NSDate dateWithString:@"2009-12-31 10:00:00 +0600"]];
		[buchung3 setDatumGeladen:[NSDate dateWithString:@"2009-12-31 10:00:00 +0600"]];
		[buchung3 setArt:[NSString stringWithString:@"FOO"]];
		[buchung3 setPrimaNota:[NSString stringWithString:@"100000"]];
		[buchung3 setAndererName:[NSString stringWithString:@"Max Musterfrau"]];
		[buchung3 setAndereBank:[NSString stringWithString:@"90000000"]];
		[buchung3 setAnderesKonto:[NSString stringWithString:@"1234567891"]];
		[buchungen_ addObject:buchung3];
		#endif*/
		
	}
	
	// erst der Fehlerfall
	if (error != nil) {
		if (canceled_)
			[delegate_ canceledKontoauszug:self];
		else {
			[konto_ setStatFehler:[NSNumber numberWithInt:[[konto_ statFehler] intValue] + 1]];
			[delegate_ finishedKontoauszug:self withError:error];
			
			// vorher mal gecrasht?
			UKCrashReporterCheckForCrash(@"Saldomat hbcitool");
		}
		return;
	}
	
	// Transaktionen anzeigen
	[konto_ setStatErfolgreich:[NSNumber numberWithInt:[[konto_ statErfolgreich] intValue] + 1]];
	[delegate_ finishedKontoauszug:self];
	
	// aufraeumen, insbesondere die Buchungen, die kein Konto gesetzt haben,
	// wieder loeschen
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	for (Buchung * b in buchungen_) {
		if ([b konto] == nil)
			[ctx deleteObject:b];
	}
	[buchungen_ removeAllObjects];
	
	// Datensicherung
	[(AppDelegate *)[NSApp delegate] saveAction:self];
}


- (void)holeKontoauszugThread:(NSProxy<CocoaBankingProtocol> *)banking
{	
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	NSError * error = nil;
	wirdGeholt_ = YES;
	
	// Thread CoreData-Context erstellen
	NSManagedObjectContext * ctx = [[[NSManagedObjectContext alloc] init] autorelease];
	[ctx setPersistentStoreCoordinator:[[NSApp delegate] persistentStoreCoordinator]];
	[ctx setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
	
	// Konto-Objekt im Thread-Context erstellen
	Konto * konto = (Konto *)[ctx objectWithID:[konto_ objectID]];
	
	// Kontoauszug vom hbcitool bekommen
	NSArray * rawBuchungen = nil;
	@try {	
		// Von wann sollen Buchungen geholt werden?
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		int deleteAfterMonth = [defaults integerForKey:@"deleteAfterMonth"];
		if (deleteAfterMonth < 0)
			deleteAfterMonth = 12;
			//FIXME: deleteAfterMonth = 100; // sehr lange - Manche Banken moegen das nicht! -> <1Jahr!
		
		float sekProMonat = 365.0*24.0*3600.0/12.0;
		NSDate * loeschGrenze = [NSDate dateWithTimeIntervalSinceNow:(-deleteAfterMonth * sekProMonat)];
		
		// Hamburger Sparkasse ? => Im Webinterface einstellbar 10/30/60/90-Tage
		if ([self bankIstHASPA:konto]) {
			float sekProTag = 24.0*3600.0;
			loeschGrenze = [NSDate dateWithTimeIntervalSinceNow:(-90 * sekProTag)];
			NSLog(@"Hamburger Sparkasse (HASPA) => es werden nur die letzten 90 Tage werden abgerufen.");
		}

		buchungenVon_ = [konto buchungenBis];
		if (buchungenVon_ != nil) {
			NSLog(@"Letzter Auszug war vom %@", buchungenVon_);
			      
			// 2 Wochen Ueberlappung, um nichts zu verpassen
			buchungenVon_ = [[NSDate date] initWithTimeInterval:-14*24*3600
								  sinceDate:buchungenVon_];
			
			// Sind genug alte Buchungen vorhanden? Wenn man die deleteAfterMonth-
			// Einstellung aendert, muessen wir evtl. mehr Kontoauszuege laden.
			NSDate * altesBuchungenVon = [konto buchungenVon];
			if (altesBuchungenVon == nil
			    || [altesBuchungenVon earlierDate:loeschGrenze] == loeschGrenze) {
				NSLog(@"Start des bekannten Buchungenzeitraums "
				      "liegt nicht weit genug in der Vergangenheit");
				buchungenVon_ = loeschGrenze;
			}
		} else {
			NSLog(@"Erster Kontoauszug");
			// Noch keine Buchungen empfangen. Also gehen wir so
			// weit zurueck wie moeglich bzw. wie wir eh nicht loeschen.
			buchungenVon_ = loeschGrenze;
		}
		[buchungenVon_ retain];
		
		NSLog(@"Kontoauszug ab %@", buchungenVon_);
		
		// Buchungen vom hbcitool bekommen
		rawBuchungen = [banking getTransactions:konto 
						   from:buchungenVon_
					      balanceTo:&kontostand_ 
				      balanceCurrencyTo:&kontostandWaehrung_
						  error:&error];
		[kontostandWaehrung_ retain];
	}
	@catch (NSException * e) {
		error = [self error:[e description]];
	}
	wirdGeholt_ = NO;
	
	// Thread-Ende an Hauptthread melden
	[(AppDelegate *)[NSApp delegate] saveAction:self];
	CInvocationGrabber * endeMethod = [CInvocationGrabber invocationGrabber];
	[(Kontoauszug *)[endeMethod prepareWithInvocationTarget:self]
	 holeKontoauszugEnde:error mitBuchungen:rawBuchungen];
	[[endeMethod invocation] performSelectorOnMainThread:@selector(invoke) 
				     withObject:nil 
				  waitUntilDone:YES];
	[pool release];
}


- (BOOL)wirdGeholt
{
	return wirdGeholt_;
}


- (Konto *)konto
{
	return konto_;
}


- (NSArray *)buchungen
{
	return buchungen_;
}


- (BOOL)isEqual:(id)anObject
{
	return self == anObject;
}


- (double)kontostand
{
	return kontostand_;
}


- (NSString *)kontostandWaehrung
{
	return kontostandWaehrung_;
}


- (NSDate *)buchungenVon
{
	return buchungenVon_;
}

@synthesize automatischGestartet = automatischGestartet_;

@end
