//
//  AppleScriptAktionAusfuehrer.m
//  hbci
//
//  Created by Stefan Schimanski on 15.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "AppleScriptAktionAusfuehrer.h"

#import <Carbon/Carbon.h>

#import "Aktion.h"
#import "Buchung.h"
#import "debug.h"
#import "Konto.h"


@implementation AppleScriptAktionAusfuehrer

- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	// Datei-URL berechnen
	NSString * pfad = [aktion option:@"applescript_pfad"];
	NSString * datei = [aktion option:@"applescript_datei"];
	NSURL * url = [NSURL fileURLWithPath:[pfad  stringByAppendingPathComponent:datei] isDirectory:NO];
	
	// AppleScript laden
	NSDictionary * error = nil;
	NSAppleScript * script = [[[NSAppleScript alloc] initWithContentsOfURL:url error:&error] autorelease];
	if (script == nil) {
		NSRunAlertPanel(NSLocalizedString(@"AppleScript error", nil),
				NSLocalizedString(@"Error loading AppleScript '%@' of action '%@':\n\n", nil),
				NSLocalizedString(@"Ok", nil),
				nil,
				nil,
				[error objectForKey:NSAppleScriptErrorMessage],
				[aktion name]);
		return;
	}
	
	// Kompilieren
	error = nil;
	[script compileAndReturnError:&error];
	if (error) {
		NSRunAlertPanel(NSLocalizedString(@"AppleScript error", nil),
				NSLocalizedString(@"Error compiling AppleScript '%@' of action '%@':\n\n", nil),
				NSLocalizedString(@"Ok", nil),
				nil,
				nil,
				[error objectForKey:NSAppleScriptErrorMessage],
				[aktion name]);
		return;
	}
	
	// Parameter aus Buchungen bauen
	NSAppleEventDescriptor * transactions = [NSAppleEventDescriptor listDescriptor];
	int i;
	for (i = 0; i < [buchungen count]; ++i) {
		Buchung * b = [buchungen objectAtIndex:i];
		[transactions insertDescriptor:[[b objectSpecifier] descriptor] atIndex:i + 1];
	}
	
	// Ausfuehren
	NSAppleEventDescriptor *parameters = [NSAppleEventDescriptor listDescriptor];
	[parameters insertDescriptor:transactions atIndex:1];

	ProcessSerialNumber psn = { 0, kCurrentProcess };
	NSAppleEventDescriptor * target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber
		 bytes:&psn length:sizeof(ProcessSerialNumber)];
	NSAppleEventDescriptor * handler = [NSAppleEventDescriptor descriptorWithString:[@"handle_new_transactions" lowercaseString]];
	NSAppleEventDescriptor * event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
		  eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID
		transactionID:kAnyTransactionID];
	[event setParamDescriptor:handler forKeyword:keyASSubroutineName];
	[event setParamDescriptor:parameters forKeyword:keyDirectObject];

	NSAppleEventDescriptor * ae = [script executeAppleEvent:event error:&error];
	if (ae == nil) {
		NSRunAlertPanel(NSLocalizedString(@"AppleScript error", nil),
				NSLocalizedString(@"Error executing AppleScript '%@' of action '%@':\n\n", nil),
				NSLocalizedString(@"Ok", nil),
				nil,
				nil,
				[error objectForKey:NSAppleScriptErrorMessage],
				[aktion name]);
		return;
	}
}

@end
