//
//  FarbAktionAusfuehrer.m
//  hbci
//
//  Created by Stefan Schimanski on 11.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "FarbAktionAusfuehrer.h"

#import "Aktion.h"
#import "Buchung.h"
#import "debug.h"
#import "Konto.h"


@implementation FarbAktionAusfuehrer

- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	NSString * farbe = [aktion option:@"farbe"];
	for (Buchung * b in buchungen)
		[b setFarbe:farbe];
}

@end
