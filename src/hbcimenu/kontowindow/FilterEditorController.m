//
//  FilterEditorController.m
//  hbci
//
//  Created by Stefan Schimanski on 21.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "FilterEditorController.h"

#import "debug.h"
#import "Konto.h"
#import "AppController.h"
#import "SidebarController.h"


@interface NSPredicate (BenutzteKonto)

- (void)benutzteKontoIdentsInSet:(NSMutableSet *)set;

@end


@implementation NSPredicate (BenutzteKonto)

- (void)benutzteKontoIdentsInSet:(NSMutableSet *)set
{
	if ([self isKindOfClass:[NSCompoundPredicate class]]) {
		for (NSPredicate * p in [(NSCompoundPredicate *)self subpredicates])
			[p benutzteKontoIdentsInSet:set];
	} else if ([self isKindOfClass:[NSComparisonPredicate class]]) {
		NSComparisonPredicate * comp = (NSComparisonPredicate *)self;
		
		// linke Seite konto.ident?
		NSExpression * links = [comp leftExpression];
		if ([links expressionType] != NSKeyPathExpressionType)
			return;
		if ([[links keyPath] compare:@"kontoIdent"] != 0)
			return;
		
		// rechte Seite konstanter String?
		NSExpression * rechts = [comp rightExpression];
		if ([rechts expressionType] != NSConstantValueExpressionType)
			return;
		if (![[rechts constantValue] isKindOfClass:[NSString class]])
			return;
		
		// ident registrieren
		[set addObject:[rechts constantValue]];
	}
}

@end


@implementation FilterEditorController

- (id) init
{
	self = [super init];
	lockSetPredicate_ = 0;
	anfangsRowTemplates_ = nil;
	return self;
}


- (void)dealloc
{
	[anfangsRowTemplates_ release];
	[super dealloc];
}


- (void)updateRowTemplatesFuerPraedikat:(NSPredicate *)pred
{
	NSMutableArray * templates = [[anfangsRowTemplates_ mutableCopy] autorelease];
	
	// Verwendete Konten.idents im Praedikat finden
	NSMutableSet * ungueltigeIdents = [NSMutableSet set];
	[pred benutzteKontoIdentsInSet:ungueltigeIdents];
	
	// RowTemplates fuer Konten
	for (Konto * k in [kontenArray_ arrangedObjects]) {
		// Konto-ident ist existent
		[ungueltigeIdents removeObject:[k ident]];
		
		// RowTemplate fuer Konto bauen
		NSPredicateEditorRowTemplate * t = [NSPredicateEditorRowTemplate alloc];
		NSString * ident = [k ident];
		t = [t initWithLeftExpressions:[NSArray arrayWithObject:[NSExpression expressionForKeyPath:@"kontoIdent"]]
			      rightExpressions:[NSArray arrayWithObject:[NSExpression expressionForConstantValue:ident]]
				      modifier:NSDirectPredicateModifier
				     operators:[NSArray arrayWithObjects:
						[NSNumber numberWithInt:NSEqualToPredicateOperatorType],
						[NSNumber numberWithInt:NSNotEqualToPredicateOperatorType],
						nil]
				       options:0];
		[t autorelease];
		NSLog(@"Adding Predicate Editor template for: %@", t);
		
		// Title im linken Popup
		NSArray * views = [t templateViews];
		NSPopUpButton * popup = [views objectAtIndex:0];
		[[popup itemAtIndex:0] setTitle:NSLocalizedString(@"Account", nil)];
	
		// Konto rechts eintragen
		popup = [views objectAtIndex:2];
		[[popup itemAtIndex:0] setTitle:[k bezeichnung]];
		
		// registrieren
		[templates addObject:t];
	}
	
	// Fallback-Praedikate fuer unbekannt Konten
	for (NSString * ident in ungueltigeIdents) {
		// RowTemplate fuer ungueltiges Konto bauen
		NSPredicateEditorRowTemplate * t = [NSPredicateEditorRowTemplate alloc];
		t = [t initWithLeftExpressions:[NSArray arrayWithObject:[NSExpression expressionForKeyPath:@"kontoIdent"]]
			      rightExpressions:[NSArray arrayWithObject:[NSExpression expressionForConstantValue:ident]]
				      modifier:NSDirectPredicateModifier
				     operators:[NSArray arrayWithObjects:
						[NSNumber numberWithInt:NSEqualToPredicateOperatorType],
						[NSNumber numberWithInt:NSNotEqualToPredicateOperatorType],
						nil]
				       options:0];
		[t autorelease];
		NSLog(@"Adding Predicate Editor template for invalid account: %@", t);
		
		// Title im linken Popup
		NSArray * views = [t templateViews];
		NSPopUpButton * popup = [views objectAtIndex:0];
		[[popup itemAtIndex:0] setTitle:NSLocalizedString(@"Account", nil)];
		
		// Konto rechts eintragen
		popup = [views objectAtIndex:2];
		NSString * fmt = NSLocalizedString(@"Invalid account '%@'", nil);
		[[popup itemAtIndex:0] setTitle:[NSString stringWithFormat:fmt, ident]];
		
		// registrieren
		[templates addObject:t];
	}
	
	// neue Templates setzen
	[predEditor_ setRowTemplates:templates];
}


- (void)awakeFromNib
{
	NSLog(@"FileEditorController awakeFromNib");
	
	// Views breiter machen
	for (NSPredicateEditorRowTemplate * t in [predEditor_ rowTemplates]) {
		for (NSView * v in [t templateViews]) {
			if ([v isKindOfClass:[NSTextField class]])
				[v setFrameSize:NSMakeSize(100, [v frame].size.height)];
		}
	}
	
	// Konten-Praedikat anhaengen
	anfangsRowTemplates_ = [[predEditor_ rowTemplates] copy];
	
	// Nach Datum absteigend sortieren
	NSSortDescriptor * nachDatum;
	NSSortDescriptor * nachDatumGeladen;
	nachDatum = [[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:NO] autorelease];
	nachDatumGeladen = [[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:NO] autorelease];
	[table_ setSortDescriptors:[NSArray arrayWithObjects:
				    nachDatum,
				    nachDatumGeladen,
				    nil]];
	
	// Auf Selektion eines Filters warten in der Sidebar
	[sidebarCtrl_ addObserver:self forKeyPath:@"markierterFilter" options:NSKeyValueObservingOptionNew context:@"sidebarCtrl.markierterFilter"];
}


- (IBAction)predicateEditorChanged:(id)sender
{
	NSPredicate * p = [[[predEditor_ predicate] retain] autorelease];
	NSLog(@"predEdChanged to: ", [p predicateFormat]);
		
	// Praedikat im Filter aktualisieren
	lockSetPredicate_++;
	[[sidebarCtrl_ markierterFilter] setPredicate:p];
	lockSetPredicate_--;
	
	// aus irgendwelche Gruenden gibs hier manchmal ne Exception wegen ungueltigem
	// Array-Index in einem Observer.
	@try {
		// Buchungsarray filtern		
		[gefilterteBuchungenArray_ setFilterPredicate:p];
		[theAppCtrl saveUserDefaults];
	}
	@catch (NSException * e) {
		NSLog(@"Exception when setting the BuchungsArray predicate: %@", [e description]);
	}
}


- (NSPredicate *)fixNotPredicate:(NSPredicate *)pred
{
	if (![pred isKindOfClass:[NSCompoundPredicate class]])
		return pred;
	NSCompoundPredicate * cpred = (NSCompoundPredicate *)pred;
	
	NSMutableArray * subpreds = [NSMutableArray array];
	for (NSPredicate * subpred in [cpred subpredicates]) {
		[subpreds addObject:[self fixNotPredicate:subpred]];
	}
	
	// NOT (foo == 42) => NOT(OR(foo == 42))
	if ([cpred compoundPredicateType] == NSNotPredicateType) {
		if ([subpreds count] != 1 
		    || ![[subpreds objectAtIndex:0] isKindOfClass:[NSCompoundPredicate class]]
		    || ![[subpreds objectAtIndex:0] compoundPredicateType] == NSOrPredicateType)
		    return [NSCompoundPredicate notPredicateWithSubpredicate:
				[NSCompoundPredicate orPredicateWithSubpredicates:subpreds]];
		else
			return [NSCompoundPredicate notPredicateWithSubpredicate:
				[subpreds objectAtIndex:0]];
	}
	
	// AND, OR nicht aendern
	if ([cpred compoundPredicateType] == NSAndPredicateType)
		return [NSCompoundPredicate andPredicateWithSubpredicates:subpreds];
	return [NSCompoundPredicate orPredicateWithSubpredicates:subpreds];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	if ([(NSString *)context compare:@"sidebarCtrl.markierterFilter"] == 0) {
		// Filter setzen im Editor
		Filter * filter = [sidebarCtrl_ markierterFilter];
		if (filter) {
			NSPredicate * pred = [self fixNotPredicate:[filter predicate]];
			// Ist ein CompoundPredicate aussen?
			if (![pred isKindOfClass:[NSCompoundPredicate class]])
				// And drumrum bauen
				pred = [NSCompoundPredicate andPredicateWithSubpredicates:
					[NSArray arrayWithObject:pred]];
			[self updateRowTemplatesFuerPraedikat:pred];
			[predEditor_ setObjectValue:pred];
			
			// aus irgendwelche Gruenden gibs hier manchmal ne Exception wegen ungueltigem
			// Array-Index in einem Observer.
			@try {
				// Buchungsarray filtern		
				[gefilterteBuchungenArray_ setFilterPredicate:pred];
			}
			@catch (NSException * e) {
				NSLog(@"Exception when setting the BuchungsArray predicate: %@", [e description]);
			}
		} else
			// Dummy-Praedikat
			[predEditor_ setObjectValue:
			 [NSCompoundPredicate andPredicateWithSubpredicates:
			  [NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"wert > 0"]]]];
	}
}


@synthesize predEditor = predEditor_;

@end

