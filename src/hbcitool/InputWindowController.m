//
//  PinWindowController.m
//  hbcipref
//
//  Created by Stefan Schimanski on 30.03.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "InputWindowController.h"

#import "CocoaBanking.h"
#import "debug.h"


@implementation InputWindowController

- (id)initWithWindowNibName:(NSString *)nib
{
	self = [super initWithWindowNibName:nib];
	[[self window] setDelegate:self];
	return self;
}


- (void)setDescription:(NSAttributedString *)description
{
	[description_ setStringValue:[description string]];
	//[description_ setAttributedStringValue:description];
}


- (void)setDescriptionWith:(NSString *)string
{
	[description_ setStringValue:string];
	//[description_ setAttributedStringValue:description];
}

- (IBAction)cancelClicked:(id)sender
{
	[NSApp stopModalWithCode:1];
}


- (IBAction)okClicked:(id)sender
{
	[NSApp stopModalWithCode:0];
}


- (void)windowWillClose:(NSNotification *)notification
{
	NSLog(@"windowWillClose");
	[self cancelClicked:self];
}

@end


@implementation NormalInputWindowController


- (id)init
{
	self = [super initWithWindowNibName:@"InputWindow"];
	return self;
}

	
- (NSString *)input
{
	return [input_ stringValue];
}

@end


@implementation PinWindowController


- (id) initWithCocoaBanking:(CocoaBanking *)banking
{
	banking_ = banking;
	self = [super initWithWindowNibName:@"PinWindow"];
	return self;
}



- (void)awakeFromNib
{
	// Wenn wir keinen Zugriff auf die Keychain haben...
	[savePin_ setEnabled:[banking_ keychain] != 0];
}


- (NSString *)readPinAndClear
{
	NSString * value = [pin_ stringValue];
	[pin_ setStringValue:[[NSString new] autorelease]];
	return value;
}


- (BOOL)shouldSavePin
{
	return [savePin_ state] == NSOnState;
}


- (IBAction)okClicked:(id)sender
{
	if ([savePin_ state] == NSOnState) {
		// Sicherheitshinweis-Sheet anzeigen
		ichHabeEsGelesen = NO;
		[NSApp beginSheet:sicherheitsWindowSheet_ modalForWindow:[self window]
		    modalDelegate:nil didEndSelector:nil contextInfo:nil];
		return;
	}
	
	[super okClicked:self];
}


- (IBAction)sheetSchliessen:(id)sender
{
	// Sheet entfernen
	[sicherheitsWindowSheet_ orderOut:self];
	[NSApp endSheet:sicherheitsWindowSheet_];
	
	// Dialog schliessen oder Checkbox auf Off setzen
	if (sender == abbrechenButton_) {
		[savePin_ setState:NSOffState];
		return;
	} else
		[super okClicked:self];
}

@end
