//
//  RotGruenFormatter.m
//  hbci
//
//  Created by Stefan Schimanski on 20.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "RotGruenFormatter.h"

#import "debug.h"


@implementation RotGruenFormatter

- (id)init
{
	NSLog(@"RotGruenFormatter init");

	self = [super init];

	rot_ = nil;
	gruen_ = nil;
	
	return self;
}


- (void)dealloc
{
	[rot_ release];
	[gruen_ release];
	[super dealloc];
}


- (NSAttributedString *)attributedStringForObjectValue:(id)anObject 
				 withDefaultAttributes:(NSDictionary *)attributes
{
	NSNumber * n = anObject;

	// Attributed String von Superklasse bekommen
	NSMutableAttributedString * s = [NSMutableAttributedString alloc];
	NSAttributedString * superS = [super attributedStringForObjectValue:anObject
						      withDefaultAttributes:attributes];
	if (superS == nil)
		s = [s initWithString:[super stringForObjectValue:n] attributes:attributes];
	else
		s = [s initWithAttributedString:superS];
	[s autorelease];
	
	// Waehrung beruecksichtigen
	[self setCurrencySymbol:@"€"];
	
	// Farbe setzen
	NSColor  * rot = rot_;
	if (!rot)
		rot = [NSColor colorWithDeviceRed:1.0 green:0.7 blue:0.7 alpha:1.0];
	NSColor * gruen = gruen_;
	if (!gruen)
		gruen = [NSColor colorWithDeviceRed:0.7 green:1.0 blue:0.7 alpha:1.0];
	[s addAttribute:NSForegroundColorAttributeName
		  value:([n doubleValue] < 0) ? rot : gruen
		  range:NSMakeRange(0, [s length])];
	
	return s;
}


-(void)setDunkel
{
	[self setRot:[NSColor colorWithDeviceRed:0.5 green:0.0 blue:0.0 alpha:1.0]];
	[self setGruen:[NSColor colorWithDeviceRed:0.0 green:0.5 blue:0.0 alpha:1.0]];
}

-(void)setHell
{
	[self setRot:[NSColor colorWithDeviceRed:1.0 green:0.7 blue:0.7 alpha:1.0]];
	[self setGruen:[NSColor colorWithDeviceRed:0.7 green:1.0 blue:0.7 alpha:1.0]];
}


@synthesize rot = rot_;
@synthesize gruen = gruen_;

@end
