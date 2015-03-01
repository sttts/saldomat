//
//  AutomatikController.m
//  hbci
//
//  Created by Stefan Schimanski on 13.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#include <SystemConfiguration/SystemConfiguration.h>

#import "AutomatikController.h"
#import "AppController.h"
#import "debug.h"


@implementation AutomatikController

- (void)awakeFromNib
{
	timer_ = [NSTimer timerWithTimeInterval:1800
					 target:self
				       selector:@selector(kontoauszuegeStarten:)
				       userInfo:nil
					repeats:YES];
	
	// Timer auch laufen lassen waehrend des Menues und waehrend modaler Fenster
	[[NSRunLoop currentRunLoop] addTimer:timer_ forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:timer_ forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:timer_ forMode:NSModalPanelRunLoopMode];
}


- (BOOL)internetOnline
{
	// kopiert von: http://www.cocoabuilder.com/archive/message/cocoa/2003/3/15/79076
	SCNetworkConnectionFlags status;
	Boolean success = SCNetworkCheckReachabilityByName("www.apple.com", &status);
	BOOL okay = success 
		&& (status & kSCNetworkFlagsReachable) 
		&& !(status & kSCNetworkFlagsConnectionRequired);
	if (!okay) {
		success = SCNetworkCheckReachabilityByName("www.w3.org", &status);
		okay = success
			&& (status & kSCNetworkFlagsReachable) 
			&& !(status & kSCNetworkFlagsConnectionRequired);
	}
	
	if (!okay)
		NSLog(@"We are not online.");
	
	return okay;
}
	 
- (void)kontoauszuegeStarten:(id)userInfo
{
	// ist der letzte Sync lange genug her?
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	int interval = [defaults integerForKey:@"interval"];
	if (interval == -1)
		return;
	int letztesMal = [defaults integerForKey:@"lastsync"];
	time_t now = time(0);
	if ((letztesMal == 0 || now - letztesMal > interval * 3600)
		&& [self internetOnline]) {
		// sync starten
		[appController_ starteKontoauszuegePerSync];
		[defaults setInteger:now forKey:@"lastsync"];
	}
}

@end
