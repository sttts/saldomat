//
//  Filter.m
//  hbci
//
//  Created by Stefan Schimanski on 23.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Filter.h"

#import "Aktion.h"
#import "debug.h"


@implementation Filter

- (id) init
{
	self = [super init];
	predicate_ = [[NSCompoundPredicate andPredicateWithSubpredicates:
		       [NSArray arrayWithObject:
			[NSPredicate predicateWithFormat:@"wert > 10"]]]
		      retain];
	title_ = [NSLocalizedString(@"New filter", nil) retain];
	aktionen_ = [[NSMutableArray array] retain];
	aktiverView_ = FilterKeinAktiverView;
	return self;
}


- (void)dealloc
{
	[predicate_ release];
	[title_ release];
	[aktionen_ release];
	[super dealloc];
}


- (NSArray *)aktionen
{
	return aktionen_;
}


- (int)countOfAktionen
{
	return [aktionen_ count];
}


- (NSDictionary *)objectInAktionenAtIndex:(int)i
{
	return [aktionen_ objectAtIndex:i];
}


- (void)insertObject:(Aktion *)aktion inAktionenAtIndex:(int)i
{
	[aktionen_ insertObject:aktion atIndex:i];
}


- (void)removeObjectFromAktionenAtIndex:(int)i
{
	[aktionen_ removeObjectAtIndex:i];
}


@synthesize predicate = predicate_;
@synthesize title = title_;
@synthesize aktiverView = aktiverView_;

@end


@implementation SharedFilters

- (void)saveAllFilters
{
	NSLog(@"Storing filters");
	NSMutableArray * codedFilters = [NSMutableArray array];
	for (Filter * f in filters_) {
		NSMutableDictionary * dict = [NSMutableDictionary dictionary];
		[dict setValue:[f title] forKey:@"title"];
		[dict setValue:[[f predicate] predicateFormat] forKey:@"predicate"];
		
		// Aktionen als Dictionaries speichern
		NSMutableArray * rawAktionen = [NSMutableArray array];
		for (Aktion * aktion in [f aktionen])
			[rawAktionen addObject:[aktion options]];
		[dict setValue:rawAktionen forKey:@"aktionen"];
		
		[codedFilters addObject:dict];
	}
	[[NSUserDefaults standardUserDefaults] setValue:codedFilters forKey:@"filters"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


- (id) init
{
	self = [super init];
	filters_ = [[NSMutableArray array] retain];
	
	// Filter aus Benutzereinstellungen laden
	NSArray * codedFilters = [[NSUserDefaults standardUserDefaults] objectForKey:@"filters"];
	for (NSDictionary * f in codedFilters) {
		// alles im Try/Catch, falls jemand die Daten manipuliert hat
		Filter * filter = [[Filter new] autorelease];
		@try {
			NSString * s = [[f objectForKey:@"predicate"] stringByReplacingOccurrencesOfString:@"konto.ident" withString:@"kontoIdent"];
			[filter setPredicate:[NSPredicate predicateWithFormat:s]];
			[filter setTitle:[f objectForKey:@"title"]];
			
			// Aktionen erstellen von Dictionaries
			NSArray * aktionen = [f objectForKey:@"aktionen"];
			for (NSDictionary * rawAktion in aktionen) {
				Aktion * aktion = [[Aktion alloc] initWithDictionary:rawAktion];
				[filter insertObject:aktion inAktionenAtIndex:[[filter aktionen] count]];
				[aktion release];
			}
	
			// Filter hinzufuegen
			[filters_ addObject:filter];
		}
		@catch (NSException * e) {
			NSLog(@"Invalid filter found in config: ", [e description]);
		}
	}
	
	// Darauf warten, dass die App terminiert
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:NSApplicationWillTerminateNotification
						   object:nil];
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[filters_ release];
	[super dealloc];
}


- (void)willTerminate:(NSNotification *)notification
{
	[self saveAllFilters];
}


- (int)countOfFilters
{
	return [filters_ count];
}


- (Filter *)objectInFiltersAtIndex:(int)i
{
	return [filters_ objectAtIndex:i];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	[self saveAllFilters];
}


- (void)insertObject:(Filter *)filter inFiltersAtIndex:(int)i
{
	[filters_ insertObject:filter atIndex:i];
	[self saveAllFilters];
}


- (void)removeObjectFromFiltersAtIndex:(int)i
{
	Filter * filter = [filters_ objectAtIndex:i];
	if (filter) {
		[filter retain];
		[filters_ removeObjectAtIndex:i];
		[filter release];
		[self saveAllFilters];
	}
}


- (NSArray *)filters
{
	return [[filters_ retain] autorelease];
}

@end
