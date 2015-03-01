//
//  LangTagTransformer.m
//  hbci
//
//  Created by Stefan Schimanski on 20.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "LangTagTransformer.h"

#import "debug.h"


NSMutableDictionary * lang2tag;
NSArray * tag2lang;

@implementation LangTagTransformer

+ (void)initialize
{
	// Abbildungen
	tag2lang = [[NSArray arrayWithObjects:@"ca", @"de", @"at", @"ch", @"us", nil] retain];
	lang2tag = [[NSMutableDictionary dictionary] retain];
	int i;
	for (i = 0; i < [tag2lang count]; ++i)
		[lang2tag setObject:[NSNumber numberWithInt:i] forKey:[tag2lang objectAtIndex:i]];	

	// registrieren
	[NSValueTransformer setValueTransformer:[[LangTagTransformer new] autorelease]
					forName:@"LangTagTransformer"];
}


+ (Class)transformedValueClass
{ 
	return [NSNumber class];
}


+ (BOOL)allowsReverseTransformation 
{ 
	return YES;
}


- (id)transformedValue:(id)value 
{
	NSLog(@"transformedValue:%@", value);
	if (value == nil)
		return nil;		
	return [lang2tag objectForKey:value];
}


- (id)reverseTransformedValue:(id)value
{
	NSLog(@"reverseTransformedValue:%@", value);
	if (value == nil)
		return nil;		
	return [tag2lang objectAtIndex:[value intValue]];
}

@end
