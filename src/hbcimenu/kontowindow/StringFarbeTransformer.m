//
//  StringFarbeTransformer.m
//  hbci
//
//  Created by Stefan Schimanski on 11.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "StringFarbeTransformer.h"

#import "debug.h"


@implementation NSColor(NSColorHexadecimalValue)
-(NSString *)hexadecimalValueOfAnNSColor
{
	float redFloatValue, greenFloatValue, blueFloatValue;
	int redIntValue, greenIntValue, blueIntValue;
	NSString *redHexValue, *greenHexValue, *blueHexValue;
	
	//Convert the NSColor to the RGB color space before we can access its components
	NSColor *convertedColor=[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	if(convertedColor)
	{
		// Get the red, green, and blue components of the color
		[convertedColor getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
		
		// Convert the components to numbers (unsigned decimal integer) between 0 and 255
		redIntValue=redFloatValue*255.99999f;
		greenIntValue=greenFloatValue*255.99999f;
		blueIntValue=blueFloatValue*255.99999f;
		
		// Convert the numbers to hex strings
		redHexValue=[NSString stringWithFormat:@"%02x", redIntValue];
		greenHexValue=[NSString stringWithFormat:@"%02x", greenIntValue];
		blueHexValue=[NSString stringWithFormat:@"%02x", blueIntValue];
		
		// Concatenate the red, green, and blue components' hex strings together with a "#"
		return [NSString stringWithFormat:@"#%@%@%@", redHexValue, greenHexValue, blueHexValue];
	}
	return nil;
}
@end


@implementation NSString(NSColorHexadecimalValue)

- (int)hexbyte:(NSString *)s
{
	char c1 = [s characterAtIndex:0];
	if (c1 >= 'a' && c1 <= 'f')
		c1 = c1 - 'a' + 10;
	else if (c1 >= 'A' && c1 <= 'F')
		c1 = c1 - 'A' + 10;
	else if (c1 >= '0' && c1 <= '9')
		c1 = c1 - '0';

	char c2 = [s characterAtIndex:1];
	if (c2 >= 'a' && c2 <= 'f')
		c2 = c2 - 'a' + 10;
	else if (c2 >= 'A' && c2 <= 'F')
		c2 = c2 - 'A' + 10;
	else if (c2 >= '0' && c2 <= '9')
		c2 = c2 - '0';
	
	return c1 * 16 + c2;
}


-(NSColor *)colorOfAnHexadecimalColorString
{
	if ([self length] != 7 || [self characterAtIndex:0] != '#')
		return nil;
	int r = [self hexbyte:[self substringWithRange:NSMakeRange(1, 2)]];
	int g = [self hexbyte:[self substringWithRange:NSMakeRange(3, 2)]];
	int b = [self hexbyte:[self substringWithRange:NSMakeRange(5, 2)]];
	return [NSColor colorWithDeviceRed:(r / 255.0) green:(g / 255.0) blue:(b / 255.0) alpha:1.0];
}
@end

@implementation StringFarbeTransformer

+ (void)initialize
{
	// registrieren
	[NSValueTransformer setValueTransformer:[[StringFarbeTransformer new] autorelease]
					forName:@"StringFarbeTransformer"];
}


+ (Class)transformedValueClass
{ 
	return [NSColor class];
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
	NSColor * col = [(NSString *)value colorOfAnHexadecimalColorString];
	NSLog(@"=> %@", col);
	return col;
}


- (id)reverseTransformedValue:(id)value
{
	NSLog(@"reverseTransformedValue:%@", value);
	if (value == nil)
		return nil;		
	NSString * col = [(NSColor *)value hexadecimalValueOfAnNSColor];
	NSLog(@"=> %@", col);
	return col;
}

@end
