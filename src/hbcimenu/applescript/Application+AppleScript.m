//
//  Application+AppleScript.m
//  hbci
//
//  Created by Stefan Schimanski on 15.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Application+AppleScript.h"

#import "AppController.h"
#import "debug.h"

@implementation Application (AppleScript)

- (id)scriptSyncAll:(NSScriptCommand *)command
{
	[theAppCtrl holeAlleKontoauszuege:self];
	return nil;
}


- (id)scriptSyncKonto:(NSScriptCommand *)command
{
	NSDictionary * args = [command evaluatedArguments];
	Konto * konto = [args objectForKey:@"konto"];
	[theAppCtrl holeKontoauszugFuer:konto];
	return nil;
}

@end
