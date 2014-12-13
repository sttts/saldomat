//
//  ExpertenKontoController.m
//  hbci
//
//  Created by Stefan Schimanski on 18.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "ExpertenKontoController.h"

#import "RegexKitLite.h"

#import "Buchung.h"
#import "debug.h"
#import "Konto.h"

@implementation ExpertenKontoController

- (id) init
{
	self = [super initWithWindowNibName:@"ExpertenKontoWindow"];
	return self;
}


- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(tabelleNeuladen:)
						     name:ZweckFilterGeaendertNotification
						   object:nil];
}


- (NSManagedObjectContext *)managedObjectContext
{
	return [[NSApp delegate] managedObjectContext];
}


- (void)tabelleNeuladen:(NSNotification *)n
{
	[buchungen_ rearrangeObjects];
}


- (IBAction)sheetSchliessen:(id)sender
{
	[[self window] orderOut:self];
	[NSApp endSheet:[self window]];
}


- (IBAction)filternClicked:(id)sender
{
	[regexp_ insertNewline:self];
}


- (IBAction)neuerZweckFilter:(id)sender
{
	// neuen ZweckFilter erstellen
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	id globalStore = [[[ctx persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	ZweckFilter * zweckFilter = [NSEntityDescription insertNewObjectForEntityForName:@"ZweckFilter"
						      inManagedObjectContext:ctx];
	[ctx assignObject:zweckFilter toPersistentStore:globalStore];
	
	// und dem Konto zuweisen
	Konto * k = [[konten_ selectedObjects] objectAtIndex:0];
	[k setZweckFilter:zweckFilter];
	[[self window] makeFirstResponder:bezeichnung_];
}


- (IBAction)zweckFilterLoeschen:(id)sender
{
	Konto * k = [[konten_ selectedObjects] objectAtIndex:0];
	ZweckFilter * zf = [k zweckFilter];
	[k setZweckFilter:nil];
	[zweckFilter_ removeObject:zf];
}


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	// pruefen, dass der regulaere Ausdruck ok ist. Sonst rot faerben
	if (control == regexp_) {
		BOOL ok = [[regexp_ stringValue] isRegexValid];
		if (!ok)
			[regexp_ setTextColor:[NSColor redColor]];
		else
			[regexp_ setTextColor:[NSColor textColor]];
		return ok;
	}
	
	return YES;
}


- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Bei Escape regexp zuruecksetzen
	if (control == regexp_) {
		if (command == @selector(cancelOperation:)) {
			[regexp_ setStringValue:
			 [[[[konten_ selectedObjects] objectAtIndex:0] zweckFilter] regexp]];
			[regexp_ setTextColor:[NSColor textColor]];
			return YES;
		}
	}
	
	return NO;
}


@synthesize konten = konten_;

@end
