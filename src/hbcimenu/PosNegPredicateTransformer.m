//
//  PosNegPredicateTransformer.m
//  hbci
//
//  Created by Stefan Schimanski on 09.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "PosNegPredicateTransformer.h"

#import "debug.h"


@implementation PositivePredicateTransformer

+ (void)initialize
{
	// registrieren
	[NSValueTransformer setValueTransformer:[[PositivePredicateTransformer new] autorelease]
					forName:@"PositivePredicateTransformer"];
}


+ (Class)transformedValueClass
{ 
	return [NSNumber class];
}


+ (BOOL)allowsReverseTransformation 
{ 
	return NO;
}


- (id)transformedValue:(id)value 
{
	if (value == nil)
		return [NSNumber numberWithBool:NO];		
	return [NSNumber numberWithBool:[value doubleValue] > 0];
}

@end


@implementation NotPositivePredicateTransformer

+ (void)initialize
{
	// registrieren
	[NSValueTransformer setValueTransformer:[[NotPositivePredicateTransformer new] autorelease]
					forName:@"NotPositivePredicateTransformer"];
}


+ (Class)transformedValueClass
{ 
	return [NSNumber class];
}


+ (BOOL)allowsReverseTransformation 
{ 
	return NO;
}


- (id)transformedValue:(id)value 
{
	if (value == nil)
		return [NSNumber numberWithBool:YES];		
	return [NSNumber numberWithBool:[value doubleValue] <= 0];
}

@end


@implementation NegativePredicateTransformer

+ (void)initialize
{
	// registrieren
	[NSValueTransformer setValueTransformer:[[NegativePredicateTransformer new] autorelease]
					forName:@"NegativePredicateTransformer"];
}


+ (Class)transformedValueClass
{ 
	return [NSNumber class];
}


+ (BOOL)allowsReverseTransformation 
{ 
	return NO;
}


- (id)transformedValue:(id)value 
{
	if (value == nil)
		return [NSNumber numberWithBool:YES];		
	return [NSNumber numberWithBool:[value doubleValue] < 0];
}

@end


@implementation NotNegativePredicateTransformer

+ (void)initialize
{
	// registrieren
	[NSValueTransformer setValueTransformer:[[NotNegativePredicateTransformer new] autorelease]
					forName:@"NotNegativePredicateTransformer"];
}


+ (Class)transformedValueClass
{ 
	return [NSNumber class];
}


+ (BOOL)allowsReverseTransformation 
{ 
	return NO;
}


- (id)transformedValue:(id)value 
{
	if (value == nil)
		return [NSNumber numberWithBool:NO];		
	return [NSNumber numberWithBool:[value doubleValue] >= 0];
}

@end