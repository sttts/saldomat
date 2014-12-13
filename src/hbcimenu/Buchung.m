//
//  Buchung.m
//  hbci
//
//  Created by Stefan Schimanski on 18.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "debug.h"
#import "Buchung.h"

#import "RegexKitLite.h"

#import "NSManagedObject+Clone.h"
#import "NSString+GUID.h"


@interface Buchung (PrimitiveAccess)
- (NSNumber *)primitiveNeu;
- (void)setPrimitiveNeu:(NSNumber *)neu;
@end


@implementation Buchung

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSLog(@"keyPathsForValuesAffectingValueForKey");
	NSSet * s = [super keyPathsForValuesAffectingValueForKey:key];
	if (s == nil)
		s = [NSSet set];
/*
	if ([key isEqualToString:@"effektiverZweckRaw"] 
	    || [key isEqualToString:@"effektiverZweck"])
		return [s setByAddingObjectsFromSet:
			[NSSet setWithObjects:
			 @"zweck", // aendert sich ja praktisch nie 
			 @"konto.zweckFilter",
			 @"konto.zweckFilter.regexp", 
			 @"konto.zweckFilter.zweck", 
			 nil]];
	/*if ([key isEqualToString:@"effektiverAndererName"])
		return [s setByAddingObjectsFromSet:[NSSet setWithObjects:@"zweck", @"andererName", @"konto.zweckFilter", @"konto.zweckFilter.regexp", @"konto.zweckFilter.andererName", nil]];
	if ([key isEqualToString:@"effektiveAndereBank"])
		return [s setByAddingObjectsFromSet:[NSSet setWithObjects:@"zweck", @"andereBank", @"konto.zweckFilter", @"konto.zweckFilter.regexp", @"konto.zweckFilter.andereBank", nil]];
	if ([key isEqualToString:@"effektivesAnderesKonto"])
		return [s setByAddingObjectsFromSet:[NSSet setWithObjects:@"zweck", @"anderesKonto", @"konto.zweckFilter", @"konto.zweckFilter.regexp", @"konto.zweckFilter.anderesKonto", nil]];*/
	if ([key isEqualToString:@"neu"])
		return [s setByAddingObject:@"neueBuchungen"];
	if ([key isEqualToString:@"betrag"])
		return [s setByAddingObject:@"wert"];
	if ([key isEqualToString:@"kontoIdent"])
		return [s setByAddingObject:@"konto"];
	if ([key isEqualToString:@"andererNameUndZweck"])
		return [s setByAddingObjectsFromSet:[NSSet setWithObjects:@"zweck", @"andererName", nil]];
	return s;
}


- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self setPrimitiveValue:[NSNumber numberWithBool:[self neuFuerKonto] != nil] forKey:@"neu"];
}


- (NSNumber *)neu
{
	[self willAccessValueForKey:@"neu"];
	NSNumber * neu = [self primitiveNeu];
	[self didAccessValueForKey:@"neu"];
	BOOL bneu = [self neuFuerKonto] != nil;
	if (neu == nil || bneu != [neu boolValue]) {
		neu = [NSNumber numberWithBool:bneu ? YES : NO];
		[self setPrimitiveNeu:neu];
	}
	return neu;
}


- (void)setNeu:(NSNumber *)neu
{
	[self willChangeValueForKey:@"neu"];
	[self setPrimitiveValue:neu forKey:@"neu"];
	[self didChangeValueForKey:@"neu"];
	[self setNeuFuerKonto:[neu boolValue] ? [self konto] : nil];
}


- (NSDecimalNumber *)betrag
{
	NSDecimalNumber * wert = [self wert];
	if ([wert doubleValue] < 0)
		return [wert decimalNumberByMultiplyingBy:[NSDecimalNumber decimalNumberWithString:@"-1"]];
	else
		return wert;
}


- (void)willSave
{
	[self setPrimitiveValue:[NSNumber numberWithBool:[self neuFuerKonto] != nil] forKey:@"neu"];
	[super willSave];
}


- (NSString *)kontoIdent
{
	Konto * konto = [self konto];
	if (!konto)
		return nil;
	return [konto ident];
}


- (NSString *)guid {
	NSString * ret = [super primitiveValueForKey:@"guid"];
	if (ret == nil) {
		ret = [NSString stringWithNewUUID];
		[self setGuid:ret];
	}
	return ret;
}


- (NSManagedObject *)cloneOfSelf
{
	Buchung * b = (Buchung *)[super cloneOfSelf];
	[b setGuid:[NSString stringWithNewUUID]];
	return b;
}


- (NSString *)andererNameUndZweck
{
	NSString * zweck = [self effektiverZweck];
	NSString * andererName = [self effektiverAndererName];
	
	// Dem Verwendungszweck den anderenNamen aus Konto voranstellen
	if (zweck == nil || [zweck length] == 0)
		return andererName;
	if (andererName == nil || [andererName length] == 0)
		return zweck;
	else
		return [NSString stringWithFormat:@"%@ - %@", andererName, zweck];
}


- (NSString *)effektiverZweckRaw
{
	if ([self zweck] == nil)
		return nil;
	
	// ZweckFilter anwenden
	if ([self konto] && [[self konto] zweckFilter]) {
		// Gruppe selektiert?
		int repl = [[[[self konto] zweckFilter] zweck] intValue];
		if (repl == -1)
			return [self zweck];
		
		// regexp anwenden
		@try {
			NSString * regexp = [[[self konto] zweckFilter] regexp];
			NSString * zweck = [self zweck];
			NSString * ret = nil;
			
			[zweck getCapturesWithRegexAndReferences:regexp,
			 [NSString stringWithFormat:@"$%d", repl], &ret,
			 nil];
			return ret;			
		}
		@catch (NSException * e) {
			NSLog(@"Regexp exception");
		}
	}
	
	return [self zweck];
}


- (NSString *)effektiverZweck
{
//	return [self effektiverZweckRaw];
	return [[self effektiverZweckRaw] stringByReplacingOccurrencesOfRegex:@"  *" withString:@" " ];
}


- (NSString *)effektiverAndererName
{
	// ZweckFilter anwenden
	if ([self konto] && [[self konto] zweckFilter]) {
		// Gruppe selektiert?
		int repl = [[[[self konto] zweckFilter] andererName] intValue];
		if (repl == -1)
			return [self andererName];
		
		// regexp anwenden
		@try {
			NSString * regexp = [[[self konto] zweckFilter] regexp];
			NSString * zweck = [self zweck];
			NSString * ret = nil;
			
			[zweck getCapturesWithRegexAndReferences:regexp,
			 [NSString stringWithFormat:@"$%d", repl], &ret,
			 nil];
			return ret;			
		}
		@catch (NSException * e) {
			NSLog(@"Regexp exception");
		}
	}
	
	return [self andererName];
}


- (NSString *)effektivesAnderesKonto
{
	// ZweckFilter anwenden
	if ([self konto] && [[self konto] zweckFilter]) {
		// Gruppe selektiert?
		int repl = [[[[self konto] zweckFilter] anderesKonto] intValue];
		if (repl == -1)
			return [self anderesKonto];
		
		// regexp anwenden
		@try {
			NSString * regexp = [[[self konto] zweckFilter] regexp];
			NSString * zweck = [self zweck];
			NSString * ret = nil;
			
			[zweck getCapturesWithRegexAndReferences:regexp,
			 [NSString stringWithFormat:@"$%d", repl], &ret,
			 nil];
			return ret;			
		}
		@catch (NSException * e) {
			NSLog(@"Regexp exception");
		}
	}
	
	return [self anderesKonto];
}


- (NSString *)effektiveAndereBank
{
	// ZweckFilter anwenden
	if ([self konto] && [[self konto] zweckFilter]) {
		// Gruppe selektiert?
		int repl = [[[[self konto] zweckFilter] andereBank] intValue];
		if (repl == -1)
			return [self andereBank];
		
		// regexp anwenden
		@try {
			NSString * regexp = [[[self konto] zweckFilter] regexp];
			NSString * zweck = [self zweck];
			NSString * ret = nil;
			
			[zweck getCapturesWithRegexAndReferences:regexp,
			 [NSString stringWithFormat:@"$%d", repl], &ret,
			 nil];
			return ret;			
		}
		@catch (NSException * e) {
			NSLog(@"Regexp exception");
		}
	}
	
	return [self andereBank];
}


@dynamic wert;
@dynamic zweck;
@dynamic konto;
@dynamic neuFuerKonto;
@dynamic art;
@dynamic datum;
@dynamic datumGeladen;
@dynamic datumWertstellung;
@dynamic waehrung;
@dynamic anderesKonto;
@dynamic andereBank;
@dynamic andererName;
@dynamic primaNota;
@dynamic farbe;
@dynamic guid;

@end


@implementation ZweckFilter

- (void)setRegexp:(NSString *)x
{
	[self willChangeValueForKey:@"regexp"];
	[self setPrimitiveValue:x forKey:@"regexp"];
	[self didChangeValueForKey:@"regexp"];
	
	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:ZweckFilterGeaendertNotification object:self]];
}


- (void)setZweck:(NSNumber *)x
{
	[self willChangeValueForKey:@"zweck"];
	[self setPrimitiveValue:x forKey:@"zweck"];
	[self didChangeValueForKey:@"zweck"];
	
	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:ZweckFilterGeaendertNotification object:self]];
}


- (void)setAndererName:(NSNumber *)x
{
	[self willChangeValueForKey:@"andererName"];
	[self setPrimitiveValue:x forKey:@"andererName"];
	[self didChangeValueForKey:@"andererName"];

	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:ZweckFilterGeaendertNotification object:self]];
}


- (void)setAndereBank:(NSNumber *)x
{
	[self willChangeValueForKey:@"andereBank"];
	[self setPrimitiveValue:x forKey:@"andereBank"];
	[self didChangeValueForKey:@"andereBank"];
	
	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:ZweckFilterGeaendertNotification object:self]];
}


- (void)setAnderesKonto:(NSNumber *)x
{
	[self willChangeValueForKey:@"anderesKonto"];
	[self setPrimitiveValue:x forKey:@"anderesKonto"];
	[self didChangeValueForKey:@"anderesKonto"];

	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:ZweckFilterGeaendertNotification object:self]];
}

@dynamic regexp;
@dynamic zweck;
@dynamic andererName;
@dynamic andereBank;
@dynamic anderesKonto;

@end
