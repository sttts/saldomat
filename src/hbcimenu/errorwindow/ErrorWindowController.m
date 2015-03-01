//
//  ErrorWindowController.m
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "ErrorWindowController.h"

#import "AppController.h"
#import "debug.h"
#import "Konto.h"

@implementation ErrorWindowController

- (id)initWithError:(NSError *)error forKonto:(Konto *)konto withLogRTFDData:(NSData *)data
{
	self = [super initWithWindowNibName:@"ErrorWindow"];
	
	error_ = [error retain];
	konto_ = [konto retain];
	data_ = [data retain];
	kritisch_ = YES;
	
	return self;
}


- (void)dealloc
{
	[error_ release];
	[konto_ release];
	[data_ release];
	
	[super dealloc];
}


- (void)awakeFromNib
{
	NSLog(@"ErrorWindowController awakeFromNib");
	[self updateError:error_ forKonto:konto_ withLogRTFDData:data_];
}


- (void)updateError:(NSError *)error forKonto:(Konto *)konto withLogRTFDData:(NSData *)data
{
	[error_  autorelease];
	[konto_ autorelease];
	[data_ autorelease];
	error_ = [error retain];
	konto_ = [konto retain];
	data_ = [data retain];
	
	// Fehler-Meldung einsetzen
	NSRange errorRange;
	errorRange.location = 0;
	errorRange.length = [[errorMessageText_ textStorage] length];
	[errorMessageText_ replaceCharactersInRange:errorRange withString:[error localizedDescription]];

	// Log-Meldungen einsetzen
	NSRange r;
	r.location = 0;
	r.length = [[errorLogText_ textStorage] length];
	[errorLogText_ replaceCharactersInRange:r withRTFD:data];
	
	// nach unten scrollen
	r.location = [[errorLogText_ textStorage] length];
	r.length = 0;
	[errorLogText_ scrollRangeToVisible:r];
	
	// Titel setzen
	[[self window] setTitle:[NSString localizedStringWithFormat:NSLocalizedString(@"HBCI error \"%@\" - %@", nil),
				 [konto bezeichnung], [NSDate date]]];
}


- (IBAction)closeClicked:(id)sender
{
	if ([NSApp modalWindow] == [self window])
		[NSApp stopModal];
	[[self window] close];
}


- (IBAction)showPrefClicked:(id)sender
{
	if ([NSApp modalWindow] == [self window])
		[NSApp stopModal];
	[[self window] close];
	[theAppCtrl showPreferences:sender];
}


- (IBAction)errorWindow_protokollausfahren:(id)sender
{
	if ([sender state] == NSOnState) {
		[[self window] setFrame:NSMakeRect ([[self window] frame].origin.x,
							[[self window] frame].origin.y-[errorLogView_ frame].size.height,
							[[self window] frame].size.width,
							[[self window] frame].size.height+[errorLogView_ frame].size.height)
				    display:YES animate:YES];
	}
	
	if ([sender state] == NSOffState) {
		[[self window] setFrame:NSMakeRect ([[self window] frame].origin.x,
							[[self window] frame].origin.y+[errorLogView_ frame].size.height,
							[[self window] frame].size.width,
							[[self window] frame].size.height-[errorLogView_ frame].size.height)
				    display:YES animate:YES];
	}
}


- (NSString *)fehlerMeldung
{
	return [error_ localizedDescription];
}


@synthesize kritischerFehler = kritisch_;

@end
