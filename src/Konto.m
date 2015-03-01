//
//  Konto.m
//  hbci
//
//  Created by Stefan Schimanski on 21.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Konto.h"

#import "NSManagedObject+Clone.h"
#import "NSString+GUID.h"

#import "Buchung.h"


@implementation Saldo

+ (void)initialize
{
	//[Saldo setKeys:[NSArray arrayWithObjects:@"wert", @"waehrung", @"konto", @"datum", nil] triggerChangeNotificationsForDependentKey:@""];
	[super initialize];
}

@dynamic wert;
@dynamic waehrung;
@dynamic konto;
@dynamic datum;

@end


@implementation TanMethode

+ (void)initialize
{
	[TanMethode setKeys:[NSArray arrayWithObjects:@"id_name", @"name", @"funktion",nil] triggerChangeNotificationsForDependentKey:@"bezeichnung"];
	[super initialize];
}

- (NSString *)bezeichnung
{
	if ([[self name] isEqualToString:[self id_name]])
		return [self name];
	//return [NSString stringWithFormat:@"%@ (%@)", [self name], [self id_name]];
	return [NSString stringWithFormat:@"%@ (%d)", [self name], [[self funktion] intValue]];
}

@dynamic funktion;
@dynamic konto;
@dynamic id_name;
@dynamic name;
@dynamic tanMethodeFuerKonto;

@end


@implementation Unterkonto

+ (void)initialize
{
	[Unterkonto setKeys:[NSArray arrayWithObjects:@"name", @"kontonummer", nil] triggerChangeNotificationsForDependentKey:@"bezeichnung"];
	[super initialize];
}


- (NSString *)bezeichnung
{
	if ([[self name] isEqualToString:[self kontonummer]])
		return [self name];
	return [NSString stringWithFormat:@"%@ (%@)", [self name], [self kontonummer]];	
}

@dynamic konto;
@dynamic kontonummer;
@dynamic name;
@dynamic unterkontoFuerKonto;
@dynamic bankleitzahl;

@end


@implementation Konto

+ (void)initialize
{
	[Konto setKeys:[NSArray arrayWithObjects:@"bankleitzahl", @"kennung", @"unterkonto", nil]
		triggerChangeNotificationsForDependentKey:@"ident"];
	[Konto setKeys:[NSArray arrayWithObjects:@"saldo", @"warnSaldo", nil]
		triggerChangeNotificationsForDependentKey:@"warnSaldoUnterschritten"];
	[super initialize];
}


- (id) init
{
	self = [super init];
	buchungenArray_ = nil;
	neueBuchungenArray_ = nil;
	versteckt_ = NO;
	return self;
}


- (void) dealloc
{
	[buchungenArray_ release];
	[neueBuchungenArray_ release];
	[super dealloc];
}


- (void)encodeWithCoder:(NSCoder *)encoder
{
	// als URI speichern
	NSManagedObjectID * oid = [self objectID];
	NSURL * uri = [oid URIRepresentation];
	[encoder encodeObject:uri forKey:@"uri"];
	
	// Und zum wiederfinden, wenn die Datenbank weg ist:
	[encoder encodeInt:[[self bezeichnung] hash] forKey:@"bezeichnung"];
	[encoder encodeInt:[[self kennung] hash] forKey:@"kennung"];
	[encoder encodeInt:[[self bankleitzahl] hash] forKey:@"bankleitzahl"];
}


- (id)initWithCoder:(NSCoder *)decoder
{
	NSURL * uri = [decoder decodeObjectForKey:@"uri"];
	[decoder decodeIntForKey:@"bezeichnung"];
	[decoder decodeIntForKey:@"kennung"];
	[decoder decodeIntForKey:@"bankleitzahl"];
	id obj = nil;
	if (uri != 0 && [uri isKindOfClass:[NSURL class]]) {
		// Objekt aus der Datenbank bekommen
		NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
		obj = [[ctx persistentStoreCoordinator] managedObjectIDForURIRepresentation:uri];
	}
	if (obj == nil) {
		// FIXME: Konto hier suchen. Wir sollten genug Daten haben
	}
	
	[self release];
	return [obj retain];
}


- (NSString *)ident
{
	NSString * kennung = [self kennung] ? [self kennung] : @"";
	NSString * blz = [self bankleitzahl] ? [self bankleitzahl] : @"";
	Unterkonto * uk = [self unterkonto];
	NSString * uks = (uk && [[uk kontonummer] length]) ? [uk kontonummer] : kennung;
	return [NSString stringWithFormat:@"%@:%@:%@", blz, kennung, uks];
}


- (NSString *)randomString:(int)length
{
	char s[length + 1];
	s[length] = 0;
	int i;
	for (i = 0; i < length; ++i) {
		char c = rand() % (10 + 26);
		if (c < 10)
			s[i] = c + '0';
		else
			s[i] = c - 10 + 'A';
	}
	return [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
}


- (NSString *)feedGeheimnis
{
	NSString * feedGeheimnis = [super primitiveValueForKey:@"feedGeheimnis"];
	if (!feedGeheimnis) {
		feedGeheimnis = [self randomString:32];
		[self setFeedGeheimnis:feedGeheimnis];
	}
	
	return feedGeheimnis;
}


- (BOOL)warnSaldoUnterschritten
{
	NSNumber * limit = [self warnSaldo];
	NSNumber * saldo = [self saldo];
	return limit && saldo && [saldo doubleValue] < [limit doubleValue];
}


#define GUID_PREFIX @"3242"


- (NSString *)guid {
	// Aktuelles Datum in der guid kodieren. So erkennen wir, wie lange jemand
	// den Saldomat schon benutzt.
	NSString * ret = [self primitiveValueForKey:@"guid"];
	if (ret == nil || ![[ret substringToIndex:4] isEqualToString:GUID_PREFIX]) {
		// Unixzeit als 8 hex-Werte
		unsigned secs = (unsigned)[[NSDate date] timeIntervalSince1970] & 0xffffffff;
		secs = secs ^ 0x12345678;
		ret = [NSString stringWithFormat:@"%@-%08X-%@", GUID_PREFIX, secs, [NSString stringWithNewUUID]];
		[self setGuid:ret];
	}
	return ret;
}


- (NSManagedObject *)cloneOfSelf
{
	Konto * k = (Konto *)[NSEntityDescription insertNewObjectForEntityForName:[[self entity] name]
							   inManagedObjectContext:[self managedObjectContext]];
	[k setBezeichnung:[self bezeichnung]];
	[k setAutomatisch:[self automatisch]];
	[k setServer:[self server]];
	[k setWarnSaldo:[self warnSaldo]];
	[k setBankleitzahl:[self bankleitzahl]];
	[k setBankname:[self bankname]];
	[k setHbciVersion:[self hbciVersion]];
	[k setBenutzerId:[self benutzerId]];
	[k setKundenId:[self kundenId]];
	[k setLand:[self land]];
	[k setKennung:[self kennung]];
	[k setSSL3:[self SSL3]];
	[k setOrder:[self order]];
	[k setIBankKonto:[self iBankKonto]];
	[k setIBankExportAktiv:[self iBankExportAktiv]];
	
	
	// ### QIF-Exports START ###
	[k setMoneywellExportAktiv:[self moneywellExportAktiv]];
	[k setMoneywellExportKategorien:[self moneywellExportKategorien]];
	[k setIFinance3ExportAktiv:[self iFinance3ExportAktiv]];
	[k setIFinance3AppStoreExportAktiv:[self iFinance3AppStoreExportAktiv]];
	[k setIFinance3ExportKategorien:[self iFinance3ExportKategorien]];
	[k setSquirrelExportAktiv:[self squirrelExportAktiv]];
	[k setSquirrelExportKategorien:[self squirrelExportKategorien]];
	[k setChaChing2ExportAktiv:[self chaChing2ExportAktiv]];
	[k setChaChing2ExportKategorien:[self chaChing2ExportKategorien]];
	[k setIBank4ExportAktiv:[self iBank4ExportAktiv]];
	[k setIBank4ExportKategorien:[self iBank4ExportKategorien]];
	
	// FIXME: Qif faehige Programme (1)
	// ### QIF-Exports ENDE ###
	
	
	[k setStatFehler:[NSNumber numberWithInt:0]];
	[k setStatErfolgreich:[NSNumber numberWithInt:0]];
	[k setSaldoImMenu:[self saldoImMenu]];
	[k setZweckFilter:[self zweckFilter]];
	// FIXME: [k setTanMethod:[self tanMethod]];
	
	for (TanMethode * tm in [self tanMethoden]) {
		TanMethode * neueTanMethode = (TanMethode *)[tm cloneOfSelf];
		[neueTanMethode setKonto:k];
		if ([self tanMethode] == tm)
			[k setTanMethode:neueTanMethode];
	}
	
	for (Unterkonto * uk in [self unterkonten]) {
		Unterkonto * neuesUk = (Unterkonto *)[uk cloneOfSelf];
		[neuesUk setKonto:k];
		if ([self unterkonto] == uk)
			[k setUnterkonto:neuesUk];
	}
	
	return k;
}


- (NSArray *)buchungenArray
{
	// ArrayController aufsetzen
	if (buchungenArray_ == nil) {
		buchungenArray_ = [NSArrayController new];
		[buchungenArray_ setSortDescriptors:[NSArray arrayWithObjects:
						[[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:YES] autorelease],
						[[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:YES] autorelease],
						[[[NSSortDescriptor alloc] initWithKey:@"primaNota" ascending:YES] autorelease],
						nil]];
		//[buchungenArray_ setObjectClass:[Buchung class]];
		[buchungenArray_ setEntityName:@"Buchung"];
		[buchungenArray_ setManagedObjectContext:[[NSApp delegate] managedObjectContext]];
		[buchungenArray_ bind:@"contentSet" toObject:self withKeyPath:@"buchungen" options:nil];
	}
	
	return [buchungenArray_ arrangedObjects];
}


- (NSArray *)neueBuchungenArray
{
	// ArrayController aufsetzen
	if (neueBuchungenArray_ == nil) {
		neueBuchungenArray_ = [NSArrayController new];
		[neueBuchungenArray_ setSortDescriptors:[NSArray arrayWithObjects:
						     [[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:YES] autorelease],
						     [[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:YES] autorelease],
						     [[[NSSortDescriptor alloc] initWithKey:@"primaNota" ascending:YES] autorelease],
						     nil]];
		//[neueBuchungenArray_ setObjectClass:[Buchung class]];
		[neueBuchungenArray_ setEntityName:@"Buchung"];
		[neueBuchungenArray_ setManagedObjectContext:[[NSApp delegate] managedObjectContext]];
		[neueBuchungenArray_ bind:@"contentSet" toObject:self withKeyPath:@"neueBuchungen" options:nil];
	}
	
	return [neueBuchungenArray_ arrangedObjects];
}


- (NSNumber *)exportMethode
{
	if ([[self iBankExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportiBank];
	if ([[self moneywellExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportMoneywell];
	if ([[self iFinance3ExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportiFinance3];
	if ([[self iFinance3AppStoreExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportiFinance3AppStore];
	if ([[self squirrelExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportSquirrel];
	if ([[self chaChing2ExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportChaChing2];
	if ([[self iBank4ExportAktiv] boolValue])
		return [NSNumber numberWithInt:KontoExportiBank4];

	// FIXME: Qif faehige Programme (2)
	return [NSNumber numberWithInt:KontoExportKeine];
}


- (void)setExportMethode:(NSNumber *)methode
{
	BOOL iBank = NO;
	BOOL moneywell = NO;
	BOOL iFinance3 = NO;
	BOOL iFinance3AppStore = NO;
	BOOL squirrel = NO;
	BOOL chaChing2 = NO;
	BOOL iBank4 = NO;
	// FIXME: Qif faehige Programme (3)
	
	switch ([methode intValue]) {
		case KontoExportiBank: iBank = YES; break;
		case KontoExportMoneywell: moneywell = YES; break;
		case KontoExportiFinance3: iFinance3 = YES; break;
		case KontoExportiFinance3AppStore: iFinance3AppStore = YES; break;
		case KontoExportSquirrel: squirrel = YES; break;
		case KontoExportChaChing2: chaChing2 = YES; break;
		case KontoExportiBank4: iBank4 = YES; break;
		// FIXME: Qif faehige Programme (4)
		default: break;
	}
	
	[self setIBankExportAktiv:[NSNumber numberWithBool:iBank]];
	[self setMoneywellExportAktiv:[NSNumber numberWithBool:moneywell]];
	[self setIFinance3ExportAktiv:[NSNumber numberWithBool:iFinance3]];
	[self setIFinance3AppStoreExportAktiv:[NSNumber numberWithBool:iFinance3AppStore]];
	[self setSquirrelExportAktiv:[NSNumber numberWithBool:squirrel]];
	[self setChaChing2ExportAktiv:[NSNumber numberWithBool:chaChing2]];
	[self setIBank4ExportAktiv:[NSNumber numberWithBool:iBank4]];
	// FIXME: Qif faehige Programme (5)
}


- (void)setZweckFilter:(ZweckFilter *)x
{
	[self willChangeValueForKey:@"zweckFilter"];
	[self setPrimitiveValue:x forKey:@"zweckFilter"];
	[self didChangeValueForKey:@"zweckFilter"];

	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:ZweckFilterGeaendertNotification object:self]];
}

@dynamic bezeichnung;
@dynamic automatisch;
@dynamic server;
@dynamic zweckFilter;
@dynamic saldo;
@dynamic saldos;
@dynamic warnSaldo;
@dynamic bankleitzahl;
@dynamic bankname;
@dynamic land;
@dynamic unterkonto;
@dynamic kennung;
@dynamic unterkonten;
@dynamic tanMethode;
@dynamic tanMethoden;
@dynamic buchungen;
@dynamic neueBuchungen;
@dynamic benutzerId;
@dynamic kundenId;
@dynamic hbciVersion;
@dynamic tanMethod;
@dynamic SSL3;
@dynamic buchungenVon;
@dynamic buchungenBis;
@dynamic feedGeheimnis;
@dynamic iBankExportVon;
@dynamic iBankExportBis;
@dynamic iBankExportAktiv;
@dynamic iBankKonto;


// ### QIF-Exports START ###
@dynamic moneywellExportVon; // Global fuer Konto
@dynamic moneywellExportBis; // Global fuer Konto

@dynamic moneywellExportAktiv;
@dynamic moneywellExportKategorien;
@dynamic iFinance3ExportAktiv;
@dynamic iFinance3AppStoreExportAktiv;
@dynamic iFinance3ExportKategorien;
@dynamic squirrelExportAktiv;
@dynamic squirrelExportKategorien;
@dynamic chaChing2ExportAktiv;
@dynamic chaChing2ExportKategorien;
@dynamic iBank4ExportAktiv;
@dynamic iBank4ExportKategorien;
// FIXME: QIF faehige Programme (6)

// ### QIF-Exports ENDE ###


@dynamic guid;
@dynamic order;
@dynamic statFehler;
@dynamic statErfolgreich;
@dynamic saldoImMenu;
@synthesize versteckt = versteckt_;

@end
