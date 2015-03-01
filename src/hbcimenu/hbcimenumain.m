//
//  hbcimenumain.m
//  hbcimenu
//
//  Created by Stefan Schimanski on 06.04.08.
//  Copyright 1stein.org 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <sys/ptrace.h>
#include <stdio.h>

#import "NSFileManager+AuthorizedMove.h"
#import "UKLoginItemRegistry.h"


int main(int argc, char *argv[])
{
#ifndef DEBUG
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif
	srand(time(0));
	
	// Bankomat -> Saldomat portierien
	char from[256] = "";
	char to[256] = "";
	strcat(from, getenv("HOME"));
	strcat(to, getenv("HOME"));
#ifdef DEBUG
	strcat(from, "/Library/Application Support/Bankomat-debug");
	strcat(to, "/Library/Application Support/Saldomat-debug");
#else
	strcat(from, "/Library/Application Support/Bankomat");
	strcat(to, "/Library/Application Support/Saldomat");
#endif
	if (access(from, F_OK) == 0 && access(to, F_OK) != 0)
		rename(from, to);

	strcpy(from, getenv("HOME"));
	strcpy(to, getenv("HOME"));
#ifdef DEBUG
	strcat(from, "/Library/Preferences/com.limoia.bankomat-debug.plist");
	strcat(to, "/Library/Preferences/com.limoia.saldomat-debug.plist");
#else
	strcat(from, "/Library/Preferences/com.limoia.bankomat.plist");
	strcat(to, "/Library/Preferences/com.limoia.saldomat.plist");
#endif
	if (access(from, F_OK) == 0 && access(to, F_OK) != 0)
		rename(from, to);
	
	strcpy(from, getenv("HOME"));
	strcpy(to, getenv("HOME"));
#ifdef DEBUG
	strcat(from, "/Library/Application Support/Saldomat-debug/license.bankomatlicense");
	strcat(to, "/Library/Application Support/Saldomat-debug/license.saldomatlicense");
#else
	strcat(from, "/Library/Application Support/Saldomat/license.bankomatlicense");
	strcat(to, "/Library/Application Support/Saldomat/license.saldomatlicense");
#endif
	if (access(from, F_OK) == 0 && access(to, F_OK) != 0)
		rename(from, to);	
	
	// Cocoa ab hier
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	
	// Bundle umbenennen
	if ([[[[NSBundle mainBundle] bundlePath] lastPathComponent] isEqualToString:@"Bankomat.app"]) {
		NSString * alt = [[NSBundle mainBundle] bundlePath];
#ifdef DEBUG
		NSString * neu = [[alt stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Saldomat-debug.app"];
#else
		NSString * neu = [[alt stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Saldomat.app"];
#endif
	
		// alten loginitem-Index merken
		int idx = [UKLoginItemRegistry indexForLoginItemWithPath:alt];
	
		// neuer Name frei?
		if (![[NSFileManager defaultManager] fileExistsAtPath:neu]) {		
			// Bundle umbenennen
			BOOL ok = [[NSFileManager defaultManager] authorizedMovePath:alt toPath:neu];
			if (ok) {
				// Autostart an? Umschreiben
				if (idx > 0) {
					[UKLoginItemRegistry removeLoginItemAtIndex:idx];
					[UKLoginItemRegistry addLoginItemWithPath:neu hideIt:YES];
				}
				
				// neustarten
				[[NSWorkspace sharedWorkspace] openFile:neu];
				exit(0);
			}
		}
	}
	
	[pool release];
	
	return NSApplicationMain(argc,  (const char **) argv);
}
