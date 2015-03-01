//
//  CocoaBankingGui.m
//  hbcipref
//
//  Created by Stefan Schimanski on 03.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "CocoaBankingGui.h"

#import "CocoaBanking.h"
#import "debug.h"
#import "InputWindowController.h"
#import "Konto.h"

#include <gwenhywfar/gui.h>
#include <gwenhywfar/cgui.h>
#include <gwenhywfar/inherit.h>


@interface CocoaBankingGui (CocoaBankingGuiPrivate)

- (void)log:(NSString *)s;

@end

/*****************************************************************/


GWEN_INHERIT(GWEN_GUI, CocoaBankingGui);

typedef int (*GWEN_GUI_PROGRESS_LOG_FN)(GWEN_GUI *gui, 
					uint32_t id,
					GWEN_LOGGER_LEVEL level,
					const char *text);
GWEN_GUI_PROGRESS_LOG_FN cguiProgressLog;


NSString * dropHtml(const char * text) {
	const char *p=0;
	
	if (text==NULL)
		return [[NSString new] autorelease];
	
	/* find begin of HTML area */
	p=text;
	while ((p=strchr(p, '<'))) {
		const char *t;
		
		t=p;
		t++;
		if (toupper(*t)=='H') {
			t++;
			if (toupper(*t)=='T') {
				t++;
				if (toupper(*t)=='M') {
					t++;
					if (toupper(*t)=='L') {
						t++;
						if (toupper(*t)=='>') {
							break;
						}
					}
				}
			}
		}
		p++;
	} /* while */
	
	if (p == NULL)
		return [NSString stringWithUTF8String:text];
	else
		return [[NSString stringWithUTF8String:text] substringToIndex:p - text - 1];
}


NSAttributedString * extractHtml(const char * text, double scaleFactor)
{
	const char *p=0;
	const char *p2=0;
	
	if (text==NULL)
		return [[NSString new] autorelease];
	
	/* find begin of HTML area */
	p=text;
	while ((p=strchr(p, '<'))) {
		const char *t;
		
		t=p;
		t++;
		if (toupper(*t)=='H') {
			t++;
			if (toupper(*t)=='T') {
				t++;
				if (toupper(*t)=='M') {
					t++;
					if (toupper(*t)=='L') {
						t++;
						if (toupper(*t)=='>') {
							break;
						}
					}
				}
			}
		}
		p++;
	} /* while */
	
	/* find end of HTML area */
	if (p) {
		p2=p + 6;
		while ((p2=strchr(p2, '<'))) {
			const char *t;
			
			t=p2;
			t++;
			if (toupper(*t)=='/') {
				t++;
				if (toupper(*t)=='H') {
					t++;
					if (toupper(*t)=='T') {
						t++;
						if (toupper(*t)=='M') {
							t++;
							if (toupper(*t)=='L') {
								t++;
								if (toupper(*t)=='>') {
									p2 = t + 1;
									break;
								}
							}
						}
					}
				}
			}
			p2++;
		} /* while */
	}
	
	if (p && p2) {
		NSData * htmlData = [NSData dataWithBytes:p length:(p2 -p)];
		NSMutableDictionary * options = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
						 [NSNumber numberWithInt:NSUTF8StringEncoding], NSCharacterEncodingDocumentOption,
						 [NSNumber numberWithFloat:scaleFactor], NSTextSizeMultiplierDocumentOption, nil];
		[options autorelease];
		return [[NSAttributedString alloc] initWithHTML:htmlData options:options documentAttributes:nil];
	}
	
	return [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:text]];
}


/*
void setCreatorToSaldomat(SecKeychainItemRef itemRef) {
	// Attribute kopieren
	SecKeychainAttributeInfo info = {0, NULL, NULL};
	SecKeychainAttributeList * attrList = NULL;
	UInt32 length = 0;
	OSStatus oss = SecKeychainItemCopyAttributesAndData(
		itemRef, &info, NULL, &attrList, &length, NULL);
	if (oss) {
		NSLog(@"SecKeychainItemCopyAttributesAndData failed");
		return;
	}
	
	// Speicher freigeben
	oss = SecKeychainItemFreeAttributesAndData(attrList, NULL);
	
	SecKeychainAttributeInfo attrs;
	attrs.count = 1;
	attrs.
	OSStatus oss = SecKeychainItemCopyAttributesAndData (
		itemRef,
		&info,
		NULL, // item class
		&attrs
						       SecKeychainAttributeList **attrList,
						       UInt32 *length,
						       void **outData
	);
}
*/


int cocoaInputBox(GWEN_GUI * gui, uint32_t flags,
		  const char * title, const char * text, char * buffer,
		  int minLen, int maxLen, uint32_t guiid) {
	CocoaBankingGui * cgui = GWEN_INHERIT_GETDATA(GWEN_GUI, CocoaBankingGui, gui);
	
	// Passwort/PIN oder normal?
	if (flags && GWEN_GUI_INPUT_FLAGS_SHOW) {
		// kein Passwort-Dialog
		NormalInputWindowController * winCtrl = [NormalInputWindowController new];
		if (!winCtrl)
			return GWEN_ERROR_INVALID;
		NSWindow * win = [winCtrl window];
		[win setTitle:[NSString stringWithUTF8String:title]];
		NSAttributedString * html = extractHtml(text, 1.1);
		[winCtrl setDescription:html];
		
		// Formatter konfigurieren
		if (flags & GWEN_GUI_INPUT_FLAGS_NUMERIC) {
			// FIXME: set numeric formater
		}
		
		// Dialog zeigen
		[[[cgui cocoaBanking] delegate] willOpenWindow];
		[NSApp activateIgnoringOtherApps:YES];
		int ret = [NSApp runModalForWindow:win];
		[win orderOut:nil];
		[[[cgui cocoaBanking] delegate] closedWindow];
		if (ret != 0) {
			[winCtrl release];
			return GWEN_ERROR_USER_ABORTED;
		}
		
		// Eingabe auslesen
		NSString * value = [winCtrl input];
		int len = [value length];
		if (len < minLen || len > maxLen) {
			[winCtrl release];
			return GWEN_ERROR_INVALID;
		}
		strcpy(buffer, [value UTF8String]);
		
		[winCtrl release];
		return 0;
	}
	
	// Schluesselbund fragen nach Passwort
	const char * password;
        UInt32 passwordLength;
        SecKeychainItemRef item = NULL;
	Konto * konto = [cgui currentKonto];
	NSString * account = [cgui keychainAccount:konto];
	NSString * service = [cgui keychainService:konto];
	NSString * oldService = [cgui oldKeychainService:konto];
	OSStatus result = errSecNoSuchKeychain;
	SecKeychainRef keychain = [[cgui cocoaBanking] keychain];
	if (keychain != 0) {
		result = SecKeychainFindGenericPassword(
							 keychain,
							 [service length],
							 [service UTF8String],
							 [account length],
							 [account UTF8String],
							 &passwordLength,
							 (void **) &password,
							 &item
							 );
		if (result != 0) {
			// mit "Bankomat"-Praefix probieren
			result = SecKeychainFindGenericPassword(
								keychain,
								[oldService length],
								[oldService UTF8String],
								[account length],
								[account UTF8String],
								&passwordLength,
								(void **) &password,
								&item
								);
		}
	}
	
	// PIN gefunden?
	if (result == 0 && passwordLength >= minLen && passwordLength <= maxLen) {
		memcpy(buffer, password, passwordLength);
		buffer[passwordLength] = 0; // Passwort hat kein 0 am Ende
	} else {
		PinWindowController * pinWinCtrl
		= [[PinWindowController alloc] initWithCocoaBanking:[cgui cocoaBanking]];
		if (!pinWinCtrl)
			return GWEN_ERROR_INVALID;
		
		NSWindow * win = [pinWinCtrl window];
		[win setTitle:[NSString stringWithUTF8String:title]];
		
		// FIXME: Frage im PIN-Dialog
		//NSAttributedString * html = extractHtml(text, 1.1);
		//[pinWinCtrl setDescription:html];
		NSString * pinString = [NSString stringWithFormat:
					NSLocalizedString(@"Please enter the PIN for %@", nil),
					[konto bezeichnung]];
		[pinWinCtrl setDescriptionWith:pinString];
		
		// Formatter konfigurieren
		if (flags & GWEN_GUI_INPUT_FLAGS_NUMERIC) {
			// FIXME: set numeric formater
		}
		
		// PIN-Dialog zeigen
		[[[cgui cocoaBanking] delegate] willOpenWindow];
		[NSApp activateIgnoringOtherApps:YES];
		int ret = [NSApp runModalForWindow:win];
		[win orderOut:nil];
		[[[cgui cocoaBanking] delegate] closedWindow];
		
		if (ret != 0) {
			[cgui setCanceled:YES];
			[pinWinCtrl release];
			return GWEN_ERROR_USER_ABORTED;
		}
		
		// PIN auslesen
		NSString * value = [pinWinCtrl readPinAndClear];
		passwordLength = [value length];
		if (passwordLength < minLen || passwordLength > maxLen) {
			memset((char*)[value UTF8String], 0, passwordLength);
			[pinWinCtrl release];
			[cgui setCanceled:YES];
			return GWEN_ERROR_INVALID;
		}
		
		// PIN speichern in der Keychain?
		if ([pinWinCtrl shouldSavePin]) {
			result = errSecNoSuchKeychain;
			if (keychain != 0)
				result = SecKeychainAddGenericPassword(
					keychain,
					[service length],
					[service UTF8String],
					[account length],
					[account UTF8String],
					passwordLength,
					[value UTF8String],
					&item
				);
			if (result != 0) {
				NSLog(@"Couldn't store PIN in keychain");
			}
		}
		
		// PIN uebertragen
		strcpy(buffer, [value UTF8String]);
		memset((char*)[value UTF8String], 0, passwordLength);
		
		[pinWinCtrl release];
	}
	
	return 0;	
}


int cocoaMessageBox(GWEN_GUI * gui, uint32_t flags, const char * title, const char * text,
		    const char * b1, const char * b2, const char * b3,
		    uint32_t guiid) {
	CocoaBankingGui * cgui = GWEN_INHERIT_GETDATA(GWEN_GUI, CocoaBankingGui, gui);
	
	// Spezialfall: Error executing backend’s queue. What shall we do?
	NSString * asciiTitle = dropHtml(text);
	if ([asciiTitle rangeOfString:@"Error executing backend's queue."].location != NSNotFound
	    && [asciiTitle rangeOfString:@"What shall we do?"].location != NSNotFound) {
		[cgui log:NSLocalizedString(@"Server closed the connection.", nil)];
		return 1;
	}
	
	// Frage stellen
	int rv = [[cgui messageBoxController] runModalMessage:extractHtml(text, 1.0)
							title:[NSString stringWithUTF8String:title]
						      button1:(b1 ? [NSString stringWithUTF8String:b1] : nil)
						      button2:(b2 ? [NSString stringWithUTF8String:b2] : nil)
						      button3:(b3 ? [NSString stringWithUTF8String:b3] : nil)
						   bankingGui:cgui];
	return rv;
}


int cocoaProgressLog(GWEN_GUI *gui,
			      uint32_t id,
			      GWEN_LOGGER_LEVEL level,
			      const char *text) {
	CocoaBankingGui * cgui = GWEN_INHERIT_GETDATA(GWEN_GUI, CocoaBankingGui, gui);	
	
	if (text)
		[cgui log:[NSString stringWithCString:text encoding:NSUTF8StringEncoding]];
	
#ifdef DEBUG
	// Meldung auch ins Log ausgeben, wenn man das hbcitool alleine laufen laesst
	NSArray * args = [[NSProcessInfo processInfo] arguments];
	if ([args indexOfObject:@"--debug"] != NSNotFound)
		NSLog([NSString stringWithCString:text encoding:NSUTF8StringEncoding]);
#endif
	
	return (*cguiProgressLog)(gui, id, level, text);
}


@implementation CocoaBankingGui

- (id)init
{
	self = [super init];
	
	// set the gui to ours
	gui_ = GWEN_Gui_CGui_new();
	GWEN_Gui_SetInputBoxFn(gui_, cocoaInputBox);
	GWEN_Gui_SetMessageBoxFn(gui_, cocoaMessageBox);
	cguiProgressLog = (GWEN_GUI_PROGRESS_LOG_FN)GWEN_Gui_SetProgressLogFn(gui_, cocoaProgressLog);
	GWEN_INHERIT_SETDATA(GWEN_GUI, CocoaBankingGui, gui_, self, 0);
	GWEN_Gui_SetGui(gui_);
	
	konto_ = nil;
	log_ = nil;
	canceled_ = NO;

	return self;
}


- (void)dealloc
{
	[konto_ release];
	GWEN_INHERIT_UNLINK(GWEN_GUI, CocoaBankingGui, gui_)
	GWEN_Gui_free(gui_);
	[log_ release];
	[super dealloc];
}


- (void)setCurrentKonto:(Konto *)konto
{
	[konto_ autorelease];
	konto_ = [konto retain];
}


- (Konto *)currentKonto
{
	return konto_;
}


- (CocoaBanking *)cocoaBanking
{
	return cocoaBanking_;
}


- (MessageBoxController *)messageBoxController
{
	return msgBoxCtrl_;
}


- (void)startLog
{
	[log_ release];
	log_ = [NSMutableArray new];
}


- (NSArray *)stopLog
{
	NSArray * ret = [log_ autorelease];
	log_ = nil;
	return ret;
}


- (void)log:(NSString *)s
{
	if (log_)
		[log_ addObject:s];
}


- (NSString *)keychainAccount:(Konto *)konto
{
	NSString * kontonummer = [konto kennung];
	if ([konto unterkonto])
		kontonummer = [[konto unterkonto] kontonummer];
	return [NSString stringWithFormat:@"%@:%@:%@:%@:%@",
		[konto server],
		[konto bankleitzahl],
		[konto kennung],
		kontonummer,
		nil];
}


- (NSString *)keychainService:(Konto *)konto
{
#ifdef DEBUG
	return [NSString stringWithFormat:@"Saldomat-debug HBCI-PIN %@:%@", 
		[konto bankleitzahl], [konto kennung]];
#else
	return [NSString stringWithFormat:@"Saldomat HBCI-PIN %@:%@", 
		[konto bankleitzahl], [konto kennung]];
#endif
}


- (NSString *)oldKeychainService:(Konto *)konto
{
#ifdef DEBUG
	return [NSString stringWithFormat:@"Bankomat-debug HBCI-PIN %@:%@", 
		[konto bankleitzahl], [konto kennung]];
#else
	return [NSString stringWithFormat:@"Bankomat HBCI-PIN %@:%@", 
		[konto bankleitzahl], [konto kennung]];
#endif
}


@synthesize canceled = canceled_;

@end
