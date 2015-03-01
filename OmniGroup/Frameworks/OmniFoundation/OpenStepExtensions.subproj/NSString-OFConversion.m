// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSString-OFConversion.h>

#import <OmniFoundation/OFStringDecoder.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSString-OFConversion.m 98560 2008-03-12 17:28:00Z bungi $");

@implementation NSString (OFConversion)

+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
{
    return [[[self alloc] initWithData:data encoding:encoding] autorelease];
}

- (BOOL)boolValue;
{
    // Should maybe later add a configurable dictionary that contains the valid YES and NO values
    if (([self caseInsensitiveCompare:@"YES"] == NSOrderedSame) || ([self caseInsensitiveCompare:@"Y"]  == NSOrderedSame) || [self isEqualToString:@"1"] || ([self caseInsensitiveCompare:@"true"] == NSOrderedSame))
        return YES;
    else
        return NO;
}

- (long long int)longLongValue;
{
    return strtoll([self UTF8String], NULL, 10);
}

- (unsigned long long int)unsignedLongLongValue;
{
    return strtoull([self UTF8String], NULL, 10);
}

- (unsigned int)unsignedIntValue;
{
    return strtoul([self UTF8String], NULL, 10);
}

- (NSDecimal)decimalValue;
{
    return [[NSDecimalNumber decimalNumberWithString:self] decimalValue];
}

- (NSDecimalNumber *)decimalNumberValue;
{
    return [NSDecimalNumber decimalNumberWithString:self];
}

- (NSNumber *)numberValue;
{
    return [NSNumber numberWithInt:[self intValue]];
}

- (NSArray *)arrayValue;
{
    return [NSArray arrayWithObject:self];
}

- (NSDictionary *)dictionaryValue;
{
    return (NSDictionary *)[self propertyList];
}

- (NSData *)dataValue;
{
    return [self dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
}

// This is a terrible idea.
#if 0
- (NSCalendarDate *)dateValue;
{
    return [NSCalendarDate dateWithNaturalLanguageString:self];
}
#endif

#define MAX_HEX_TEXT_LENGTH 40

static inline unsigned int parseHexString(NSString *hexString, unsigned long long int *parsedHexValue)
{
    unsigned int hexLength;
    unichar hexText[MAX_HEX_TEXT_LENGTH];
    unichar hexDigit;
    unsigned int textIndex;
    unsigned long long int hexValue;
    unsigned int hexDigitsFound;
    
    hexLength = [hexString length];
    if (hexLength > MAX_HEX_TEXT_LENGTH)
        hexLength = MAX_HEX_TEXT_LENGTH;
    [hexString getCharacters:hexText range:NSMakeRange(0, hexLength)];
    
    textIndex = 0;
    hexValue = 0;
    hexDigitsFound = 0;
    
    while (textIndex < hexLength && isspace(hexText[textIndex])) {
        // Skip leading whitespace
        textIndex++;
    }
    
    if (hexText[textIndex] == '0' && hexText[textIndex + 1] == 'x') {
        // Skip leading "0x"
        textIndex += 2;
    }
    
    while (textIndex < hexLength) {
        hexDigit = hexText[textIndex++];
        
        if (hexDigit >= '0' && hexDigit <= '9') {
            hexDigit = hexDigit - '0';
        } else if (hexDigit >= 'A' && hexDigit <= 'F') {
            hexDigit = hexDigit - 'A' + 10;
        } else if (hexDigit >= 'a' && hexDigit <= 'f') {
            hexDigit = hexDigit - 'a' + 10;
        } else if (isspace(hexDigit)) {
            continue;
        } else {
            hexDigitsFound = 0;
            break;
        }
        hexDigitsFound++;
        hexValue <<= 4;
        hexValue |= hexDigit;
    }
    
    *parsedHexValue = hexValue;
    return hexDigitsFound;
}

- (unsigned int)hexValue;
{
    unsigned int hexDigitsParsed;
    unsigned long long int hexValue;
    
    hexDigitsParsed = parseHexString(self, &hexValue);
    if (hexDigitsParsed > 0) {
        // More than one hex digit parsed
        // Since we return a long and we just parsed a long long, let's be explicit about throwing away the high bits.
        return (unsigned int)(hexValue & 0xffffffff);
    } else {
        // No hex digits, use the default return value
        return 0;
    }
}

- (NSData *)dataUsingCFEncoding:(CFStringEncoding)anEncoding;
{
    CFDataRef result;
    
    result = OFCreateDataFromStringWithDeferredEncoding((CFStringRef)self, (CFRange){location: 0, length:[self length]}, anEncoding, (char)0);
    
    return [(NSData *)result autorelease];
}

- (NSData *)dataUsingCFEncoding:(CFStringEncoding)anEncoding allowLossyConversion:(BOOL)lossy;
{
    CFDataRef result;
    
    result = OFCreateDataFromStringWithDeferredEncoding((CFStringRef)self, (CFRange){location: 0, length:[self length]}, anEncoding, lossy?'?':0);
    
    return [(NSData *)result autorelease];
}

@end
