//
//  Aktion.m
//  hbci
//
//  Created by Stefan Schimanski on 04.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Aktion.h"

#import "debug.h"


@implementation Aktion

- (id)initWithType:(NSString *)type
{
	self = [super init];
	options_ = [NSMutableDictionary new];
	[self setAktiv:YES];
	[self setEinzeln:NO];
	[options_ setObject:type forKey:@"type"];
	
	if ([type isEqualToString:@"growl"]) {
		[self setName:NSLocalizedString(@"Growl message", nil)];
		[self setOption:@"growl_titel" toValue:NSLocalizedString(@"Filter triggered", nil)];
		[self setOption:@"growl_nachricht" toValue:NSLocalizedString(@"New transactions matched.", nil)];
	} else if ([type isEqualToString:@"quicken"]) {
		[self setName:NSLocalizedString(@"QIF export", nil)];
		[self setOption:@"quicken_datei" toValue:@"Saldomat.qif"];
		[self setOption:@"quicken_pfad" toValue:NSHomeDirectory()];
		[self setOption:@"quicken_append" toValue:[NSNumber numberWithBool:YES]];
		[self setOption:@"quicken_komma" toValue:[NSNumber numberWithInt:0]];
		[self setOption:@"quicken_datumsformat" toValue:[NSNumber numberWithInt:4]];
		[self setOption:@"quicken_kategorien" toValue:[NSNumber numberWithBool:NO]];
	} else if ([type isEqualToString:@"csv"]) {
		[self setName:NSLocalizedString(@"CSV export", nil)];
		[self setOption:@"csv_datei" toValue:@"Saldomat.csv"];
		[self setOption:@"csv_pfad" toValue:NSHomeDirectory()];
		[self setOption:@"csv_append" toValue:[NSNumber numberWithBool:YES]];
		[self setOption:@"csv_komma" toValue:[NSNumber numberWithInt:0]];
		[self setOption:@"csv_datumsformat" toValue:[NSNumber numberWithInt:0]];
		[self setOption:@"csv_format" toValue:@"\"$d\",\"$v\",\"$c\",\"$p\",\"$r\""];
	} else if ([type isEqualToString:@"grandtotal"]) { // #### GrandTotal ####
		[self setName:NSLocalizedString(@"GrandTotal Export", nil)];
		[self setOption:@"grandtotal_append" toValue:[NSNumber numberWithBool:YES]];
		[self setOption:@"grandtotal_starten" toValue:[NSNumber numberWithBool:NO]];
	} else if ([type isEqualToString:@"farbe"]) {
		[self setName:NSLocalizedString(@"Color transactions", nil)];
		[self setOption:@"farbe" toValue:@"#000000"];
	} else if ([type isEqualToString:@"applescript"]) {
		[self setName:NSLocalizedString(@"AppleScript", nil)];
		[self setOption:@"applescript_pfad" toValue:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Scripts"]];
	}
	
	return self;
}


- (id)initWithDictionary:(NSDictionary *)dict
{
	self = [self initWithType:[dict objectForKey:@"type"]];
	for (NSString * option in dict)
		[self setOption:option toValue:[dict objectForKey:option]];
	return self;
}


- (void) dealloc
{
	[options_ release];
	[super dealloc];
}


- (BOOL)aktiv
{
	return [[options_ objectForKey:@"aktiv"] boolValue];
}


- (void)setAktiv:(BOOL)aktiv
{
	[options_ setObject:[NSNumber numberWithBool:aktiv] forKey:@"aktiv"];
}


- (BOOL)einzeln
{
	return [[options_ objectForKey:@"einzeln"] boolValue];
}


- (void)setEinzeln:(BOOL)einzeln
{
	[options_ setObject:[NSNumber numberWithBool:einzeln] forKey:@"einzeln"];
}


- (NSString *)type
{
	return [options_ objectForKey:@"type"];
}


- (NSString *)name
{
	return [options_ objectForKey:@"name"];
}


- (void)setName:(NSString *)name
{
	[options_ setObject:name forKey:@"name"];
}


- (void)setOption:(NSString *)option toValue:(id)value
{
	[options_ setObject:value forKey:option]; 
}	 	 


- (id)option:(NSString *)option
{
	return [options_ objectForKey:option];
}


- (NSMutableDictionary *)options
{
	return options_;
}

@end
