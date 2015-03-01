//
//  Konto+AppleScript.m
//  hbci
//
//  Created by Stefan Schimanski on 14.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Konto+AppleScript.h"

#import "AppController.h"
#import "Application.h"
#import "debug.h"


@implementation Buchung (AppleScript)

- (NSString *)identifier
{
	return [self guid];
}


- (NSScriptObjectSpecifier *)objectSpecifier
{
	int index = [[[self konto] buchungenArray] indexOfObject:self];
	if (index != NSNotFound) {
		return [[[NSIndexSpecifier alloc]
			 initWithContainerClassDescription:(NSScriptClassDescription *)[[self konto] classDescription]
			 containerSpecifier:[[self konto] objectSpecifier]
			 key:@"buchungenArray"
			 index:index] autorelease];
	}
	
	return nil;
}

@end



@implementation Konto (AppleScript)

- (NSString *)identifier
{
	return [self guid];
}


- (NSScriptObjectSpecifier *)objectSpecifier
{
	NSArray * konten = [(Application *)NSApp kontenArray];
	int index = [konten indexOfObjectIdenticalTo:self];
	if (index != NSNotFound) {
		return [[[NSIndexSpecifier allocWithZone:[self zone]]
			 initWithContainerClassDescription:(NSScriptClassDescription *)[NSApp classDescription]
			 containerSpecifier:[NSApp objectSpecifier] key:@"kontenArray" index:index] autorelease];
	} else
		return nil;
}


// FIXME: Zugriff per AppleScript optimieren!

@end
