//
//  NSNumber+CurrentLocaleDescription.m
//  hbci
//
//  Created by Stefan Schimanski on 10.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "NSNumber+CurrentLocaleDescription.h"


@implementation NSNumber(CurrentLocaleDescription)

- (NSString *)descriptionWithLocale
{
	return [self descriptionWithLocale:[NSLocale currentLocale]];
}


- (NSString *)geldBetrag
{
	NSNumberFormatter * formatter = [[NSNumberFormatter new] autorelease];
	[formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[formatter setFormat:@"0.00;0.00;-0.00"];
	[formatter setDecimalSeparator:@","];
	return [formatter stringFromNumber:self];
}

@end
