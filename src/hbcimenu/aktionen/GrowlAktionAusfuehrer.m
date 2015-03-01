//
//  GrowlAktion.m
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "GrowlAktionAusfuehrer.h"

#import "Aktion.h"
#import "Buchung.h"
#import "debug.h"
#import "Filter.h"

@implementation GrowlAktionAusfuehrer

- (id)initWithGrowlController:(GrowlController *)growl
{
	self = [super init];
	growl_ = [growl retain];
	return self;
}


- (void) dealloc
{
	[growl_ release];
	[super dealloc];
}


- (NSString *)ersetzen:(NSString *)s fuerBuchungen:(NSArray *)buchungen
{
	NSString * k = @"";
	NSString * knr = @"";
	NSString * blz = @"";
	NSString * saldo = @"";
	NSString * k2 = @"";
	NSString * knr2 = @"";
	NSString * blz2 = @"";
	if ([buchungen count] > 0) {
		Buchung * b = [buchungen objectAtIndex:0];
		Konto * konto = [b konto];
		k = [konto bezeichnung];
		knr = [konto unterkonto] ? [[konto unterkonto] kontonummer] : [konto kennung];
		if ([konto bankleitzahl])
			blz = [konto bankleitzahl];
		if ([b effektiverAndererName])
			k2 = [b effektiverAndererName];
		if ([b effektivesAnderesKonto])
			knr2 = [b effektivesAnderesKonto];
		if ([b effektiveAndereBank])
			blz2 = [b effektiveAndereBank];
		saldo = [[konto saldo] description];
	}
	
	// Wert ausrechnen
	NSDecimalNumber * wert = [NSDecimalNumber decimalNumberWithString:@"0.00"];
	for (Buchung * b in buchungen) {
		wert = [wert decimalNumberByAdding:[b wert]];
	}

	s = [s stringByReplacingOccurrencesOfString:@"$n" withString:[[NSNumber numberWithInt:[buchungen count]] description]];
	s = [s stringByReplacingOccurrencesOfString:@"$saldo" withString:saldo];
	s = [s stringByReplacingOccurrencesOfString:@"$wert" withString:[wert description]];
	s = [s stringByReplacingOccurrencesOfString:@"$k2" withString:k2];
	s = [s stringByReplacingOccurrencesOfString:@"$knr2" withString:knr2];
	s = [s stringByReplacingOccurrencesOfString:@"$blz2" withString:blz2];
	s = [s stringByReplacingOccurrencesOfString:@"$k" withString:k];
	s = [s stringByReplacingOccurrencesOfString:@"$knr" withString:knr];
	s = [s stringByReplacingOccurrencesOfString:@"$blz" withString:blz];
	return s;
}


- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	NSString * titel = [self ersetzen:[aktion option:@"growl_titel"] fuerBuchungen:buchungen];
	NSString * nachricht = [self ersetzen:[aktion option:@"growl_nachricht"] fuerBuchungen:buchungen];
	[growl_ meldeAktionFilter:titel
		     mitNachricht:nachricht
			   sticky:[[aktion option:@"growl_sticky"] boolValue]
		   hohePrioritaet:[[aktion option:@"growl_prioritaet"] boolValue]];
}

@end
