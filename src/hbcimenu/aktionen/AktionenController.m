//
//  AktionController.m
//  hbci
//
//  Created by Stefan Schimanski on 03.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "AktionenController.h"

#import "AktionAusfuehrer.h"
#import "Aktion.h"
#import "AppController.h"
#import "AppleScriptAktionAusfuehrer.h"
#import "Buchung.h"
#import "CsvAktionAusfuehrer.h"
#import "GrandtotalAktionAusfuehrer.h"
#import "debug.h"
#import "FarbAktionAusfuehrer.h"
#import "Filter.h"
#import "GrowlAktionAusfuehrer.h"
#import "Konto.h"
#import "QuickenAktionAusfuehrer.h"


@implementation AktionenController

- (void)awakeFromNib
{
	// Ausfuehrer registrieren
	ausfuehrer_ = [NSDictionary dictionaryWithObjectsAndKeys:
		       [[[FarbAktionAusfuehrer alloc] init] autorelease], @"farbe",
		       [[[GrowlAktionAusfuehrer alloc] initWithGrowlController:growl_] autorelease], @"growl",
		       [[[QuickenAktionAusfuehrer alloc] init] autorelease], @"quicken",
		       [[[CsvAktionAusfuehrer alloc] init] autorelease], @"csv",
		       [[[GrandtotalAktionAusfuehrer alloc] init] autorelease], @"grandtotal",
		       [[[AppleScriptAktionAusfuehrer alloc] init] autorelease], @"applescript",
		       nil];
	[ausfuehrer_ retain];
}


- (void)aktionenAusfuehren:(NSArray *)buchungen;
{
	NSMutableDictionary * filterBuchungen = [NSMutableDictionary dictionary];
	SharedFilters * filters = [theAppCtrl sharedFilters];
	
	// alle Buchungen auf Filter anwenden und sortieren
	for (Buchung * buchung in buchungen) {
		// alle Filter durchgehen
		for (Filter * filter in [filters filters]) {
			if (![[filter predicate] evaluateWithObject:buchung])
				continue;
			
			// Buchung passt
			NSLog(@"Buchung %@ erfuellt Filter %@", [buchung effektiverZweck], [filter title]);
			
			// Fuer Filter merken
			NSString * ident = [NSString stringWithFormat:@"%d", filter];
			NSMutableArray * fb = [filterBuchungen objectForKey:ident];
			if (fb == nil) {
				fb = [NSMutableArray array];
				[filterBuchungen setObject:fb forKey:ident];
			}
			[fb addObject:buchung];
		}
	}
	
	// einzelnen Aktionen ausfuehren
	for (Filter * filter in [filters filters]) {
		// Buchungen finden
		NSString * ident = [NSString stringWithFormat:@"%d", filter];
		NSArray * fb = [filterBuchungen objectForKey:ident];
		if (fb == nil)
			continue;
		
		// Aktionen nacheinander ausfuehren
		for (Aktion * aktion in [filter aktionen]) {
			// Aktion aktiv?
			if ([aktion aktiv] == NO)
				continue;
			
			[self aktionAusfuehren:aktion fuerBuchungen:fb];			 
		}
	}
}


- (void)aktionAusfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	// Ausfuehrer suchen
	AktionAusfuehrer * ausfuehrer = [ausfuehrer_ objectForKey:[aktion type]];
	if (ausfuehrer == nil) {
		NSLog(@"Unbekannter AktionAusfuehrer fuer %@", aktion);
		return;
	}
	
	// fuer jede Buchung einzeln?
	if ([aktion einzeln]) {
		for (Buchung * b in buchungen)
			[ausfuehrer ausfuehren:aktion fuerBuchungen:[NSArray arrayWithObject:b]];
	} else
		// fuer alle zusammen Aktion ausfuehren
		[ausfuehrer ausfuehren:aktion fuerBuchungen:buchungen];
	
}


@end
