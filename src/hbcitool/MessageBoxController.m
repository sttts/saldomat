//
//  MessageBoxController.m
//  hbci
//
//  Created by Stefan Schimanski on 17.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "MessageBoxController.h"

#import "CocoaBanking.h"
#import "CocoaBankingGui.h"
#import "debug.h"


@implementation MessageBoxController

- (void)awakeFromNib
{
	[[self window] setDelegate:self];
}


- (int)runModalMessage:(NSAttributedString *)msg title:(NSString *)title
	       button1:(NSString *)b1 button2:(NSString *)b2 button3:(NSString *)b3
		 bankingGui:(CocoaBankingGui *)gui
{
	// Antwort gespeichert?
	const char * value;
	UInt32 valueLength;
	SecKeychainItemRef item = NULL;
	Konto * konto = [gui currentKonto];
	NSString * account = [msg string];
#ifdef DEBUG
	NSString * service = [NSString stringWithFormat:@"Saldomat-debug HBCI-Server-Zertifikat %@:%@", [konto bankleitzahl], [konto kennung]];
	NSString * oldService = [NSString stringWithFormat:@"Bankomat-debug HBCI-Server-Zertifikat %@:%@", [konto bankleitzahl], [konto kennung]];
#else
	NSString * service = [NSString stringWithFormat:@"Saldomat HBCI-Server-Zertifikat %@:%@", [konto bankleitzahl], [konto kennung]];
	NSString * oldService = [NSString stringWithFormat:@"Bankomat HBCI-Server-Zertifikat %@:%@", [konto bankleitzahl], [konto kennung]];
#endif
	OSStatus result  = errSecNoSuchKeychain;
	SecKeychainRef keychain = [[gui cocoaBanking] keychain];
	if (keychain != 0) {
		result = SecKeychainFindGenericPassword(
			keychain,
			[service length],
			[service UTF8String],
			[account length],
			[account UTF8String],
			&valueLength,
			(void **) &value,
			&item
		);
		if (result != 0) {
			// alte Bankomateintraege finden
			result = SecKeychainFindGenericPassword(
								keychain,
								[oldService length],
								[oldService UTF8String],
								[account length],
								[account UTF8String],
								&valueLength,
								(void **) &value,
								&item
								);
		}
	}
	if (result == 0) {
		if (value[0] == '1')
			return 1;
		if (value[0] == '3')
			return 3;
		return 2;
	}
	
	// Buttons und Titel setzen
	[button1_ setHidden:(b1 == nil)];
	[button2_ setHidden:(b2 == nil)];
	[button3_ setHidden:(b3 == nil)];
	if (b1)
		[button1_ setTitle:b1];
	if (b2)
		[button2_ setTitle:b2];
	if (b3)
		[button3_ setTitle:b3];
	[[self window] setTitle:title];
	
	// Nachricht setzen
	NSRange r;
	r.location = 0;
	r.length = [[message_ textStorage] length];
	[[message_ textStorage] replaceCharactersInRange:r withAttributedString:msg];
	
	// Bild auswaehlen
	if ([title rangeOfString:@"Zertifikat"].location == NSNotFound) {
		[euroBild_ setHidden:NO];
		[zertifikatsBild_ setHidden:YES];
	} else {
		[euroBild_ setHidden:YES];
		[zertifikatsBild_ setHidden:NO];
	}
	
	// Checkbox
	[antwortMerken_ setEnabled:[banking_ keychain] != 0];
	[antwortMerken_ setState:NSOffState];
	[antwortMerken_ setHidden:(b2 == nil && b3 == nil)];
	
	// Fenster modal ausfuehren
	[[[gui cocoaBanking] delegate] willOpenWindow];
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] orderFront:self];
	int ret = [NSApp runModalForWindow:[self window]];
	[[self window] orderOut:self];
	[[[gui cocoaBanking] delegate] closedWindow];
	
	// Antwort merken?
	if ([antwortMerken_ state] == NSOnState) {
		// Wir erstellen ein Generic-Password. Nicht wirklich das richtige
		// fuer ein Zertifikat :-/
		// PIN speichern in der Keychain?
		char newValue[2];
		newValue[0] = ret + '0';
		newValue[1] = 0;
		result = errSecNoSuchKeychain;
		if (keychain != 0)
			result = SecKeychainAddGenericPassword(
				keychain,
				[service length],
				[service UTF8String],
				[account length],
				[account UTF8String],
				1,
				newValue,
				&item);
		if (result != 0) {
			NSLog(@"Couldn't store answer in keychain");
		}
	}
	
	return ret;
}


- (IBAction)buttonClicked:(id)sender
{
	if (sender == button1_)
		[NSApp stopModalWithCode:1];
	else if (sender == button2_)
		[NSApp stopModalWithCode:2];
	else if (sender == button3_)
		[NSApp stopModalWithCode:3];
	else
		assert(false);
}


- (void)windowWillClose:(NSNotification *)notification
{
	NSLog(@"windowWillClose");
	[NSApp stopModalWithCode:2];
}


@end
