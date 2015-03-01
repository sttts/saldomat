// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSDate-OFExtensions.h>

#import <OmniFoundation/NSString-OFSimpleMatching.h>
#import <OmniFoundation/OFNull.h>

#import <Foundation/NSDateFormatter.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSDate-OFExtensions.m 98560 2008-03-12 17:28:00Z bungi $")

@implementation NSDate (OFExtensions)

#if 0 // -descriptionWithCalendarFormat:timeZone:locale: isn't available on Aspen.  Should rewrite this using a more modern API if we still use it.
- (NSString *)descriptionWithHTTPFormat; // rfc1123 format with TZ forced to GMT
{
    // see rfc2616 [3.3.1]
    return [self descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S %Z" timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"] locale:nil];
}
#endif

- (void)sleepUntilDate;
{
    NSTimeInterval timeIntervalSinceNow;

    timeIntervalSinceNow = [self timeIntervalSinceNow];
    if (timeIntervalSinceNow < 0)
	return;
    [NSThread sleepUntilDate:self];
}

- (BOOL)isAfterDate:(NSDate *)otherDate
{
    return [self compare:otherDate] == NSOrderedDescending;
}

- (BOOL)isBeforeDate:(NSDate *)otherDate
{
    return [self compare:otherDate] == NSOrderedAscending;
}

#pragma mark -
#pragma mark XML Schema / ISO 8601 support

+ (NSTimeZone *)UTCTimeZone;
{
    static NSTimeZone *tz = nil;
    
    if (!tz) {
        tz = [[NSTimeZone timeZoneWithAbbreviation:@"UTC"] retain];
        OBASSERT(tz);
        if (!tz) // another approach...
            tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
        OBASSERT(tz);
    }
    return tz;
}

+ (NSCalendar *)gregorianUTCCalendar;
{
    static NSCalendar *cal = nil;
    
    if (!cal) {
        cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        OBASSERT(cal);
        
        [cal setTimeZone:[self UTCTimeZone]];
    }
    return cal;
}

#if 0 && defined(DEBUG)
    #define DEBUG_XML_STRING(format, ...) NSLog((format), ## __VA_ARGS__)

    static void _appendUnit(NSDateComponents *self, NSMutableString *str, NSString *name, int value) {
        if (value != NSUndefinedDateComponent)
            [str appendFormat:@" %@:%d", name, value];
    }
#define APPEND(x) _appendUnit(self, desc, @#x, [self x])
    static NSString *_comp(NSDateComponents *self) {
        NSMutableString *desc = [NSMutableString stringWithString:@"<components:"];
        
        APPEND(era);
        APPEND(year);
        APPEND(month);
        APPEND(day);
        APPEND(hour);
        APPEND(minute);
        APPEND(second);
        APPEND(week);
        APPEND(weekday);
        APPEND(weekdayOrdinal);
#undef APPEND
        
        [desc appendString:@">"];
        return desc;
    }
#else
    #define DEBUG_XML_STRING(format, ...)
#endif

// Expects a string in the XML Schema / ISO 8601 format: YYYY-MM-ddTHH:mm:ss.SSSSZ.  This doesn't attempts to be very forgiving in parsing; the goal should be to feed in either nil/empty or a conforming string.
- initWithXMLString:(NSString *)xmlString;
{
    if ([NSString isEmptyString:xmlString]) {
        [self release];
        return nil;
    }
    
    // Split on the 'T'.
    CFRange tRange = CFStringFind((CFStringRef)xmlString, CFSTR("T"), 0);
    if (tRange.length == 0) {
        OBASSERT(tRange.length == 1);
        [self release];
        return nil;
    }

    DEBUG_XML_STRING(@"-initWithXMLString: -- input: %@", xmlString);

    CFStringRef datePortion = CFStringCreateWithSubstring(kCFAllocatorDefault, (CFStringRef)xmlString, CFRangeMake(0, tRange.location));
    DEBUG_XML_STRING(@"date portion: %@", datePortion);
    
    CFStringRef timePortion = CFStringCreateWithSubstring(kCFAllocatorDefault, (CFStringRef)xmlString, CFRangeMake(tRange.location + tRange.length, CFStringGetLength((CFStringRef)xmlString) - (tRange.location + tRange.length)));
    DEBUG_XML_STRING(@"time portion: %@", timePortion);
    
    CFArrayRef dateComponents = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, datePortion, CFSTR("-"));
    CFRelease(datePortion);
    DEBUG_XML_STRING(@"date components: %@", dateComponents);

    CFArrayRef timeComponents = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, timePortion, CFSTR(":"));
    CFRelease(timePortion);
    DEBUG_XML_STRING(@"time components: %@", timeComponents);
    
    if ((CFArrayGetCount(dateComponents) != 3) || (CFArrayGetCount(timeComponents) != 3)) {
        OBASSERT(CFArrayGetCount(dateComponents) == 3);
        OBASSERT(CFArrayGetCount(timeComponents) == 3);
        CFRelease(dateComponents);
        CFRelease(timeComponents);
        [self release];
        return nil;
    }
    
    // NOTE: NSDateComponents has busted API since -second returns an integer instead of a floating point (Radar 4867971).  To work around that, we build a date without considering the seconds, get its time interval and then build another date by adding in the seconds.
    NSDateComponents *components = [[NSDateComponents alloc] init];
    
    [components setYear:[(id)CFArrayGetValueAtIndex(dateComponents, 0) intValue]];
    [components setMonth:[(id)CFArrayGetValueAtIndex(dateComponents, 1) intValue]];
    [components setDay:[(id)CFArrayGetValueAtIndex(dateComponents, 2) intValue]];
    
    [components setHour:[(id)CFArrayGetValueAtIndex(timeComponents, 0) intValue]];
    [components setMinute:[(id)CFArrayGetValueAtIndex(timeComponents, 1) intValue]];
    [components setSecond:0];
    DEBUG_XML_STRING(@"components: %@", _comp(components));

    NSTimeInterval seconds = [(id)CFArrayGetValueAtIndex(timeComponents, 2) doubleValue]; // This presumes that -doubleValue will ignore the trailing 'Z'
    DEBUG_XML_STRING(@"seconds: %f", seconds);

    CFRelease(dateComponents);
    CFRelease(timeComponents);

    OBASSERT([[NSDate gregorianUTCCalendar] timeZone] == [NSDate UTCTimeZone]); // Should have been set in the creation.
    NSDate *date = [[NSDate gregorianUTCCalendar] dateFromComponents:components];
    [components release];
    DEBUG_XML_STRING(@"date: %@", date);

    NSTimeInterval interval = [date timeIntervalSinceReferenceDate] + seconds;
    
    NSDate *result = [self initWithTimeIntervalSinceReferenceDate:interval];
    DEBUG_XML_STRING(@"result: %@ %f", result, [result timeIntervalSinceReferenceDate]);

    OBPOSTCONDITION(OFISEQUAL([result xmlString], xmlString));
    return result;
}

// The setup of this formatter cannot be changed willy-nilly.  This is used in XML archiving, and our file formats need to be stable.  Luckily this is a nicely defined format.
static NSDateFormatter *formatterWithoutMilliseconds(void)
{
    static NSDateFormatter *DateFormatter = nil;
    
    if (!DateFormatter) {
        DateFormatter = [[NSDateFormatter alloc] init];
        [DateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        OBASSERT([DateFormatter formatterBehavior] == NSDateFormatterBehavior10_4);
        
        NSCalendar *cal = [NSDate gregorianUTCCalendar];
        if (!cal)
            OBASSERT_NOT_REACHED("Built-in calendar missing");
        else {
            OBASSERT([cal timeZone] == [NSDate UTCTimeZone]); // Should have been set in the creation.
            
            [DateFormatter setCalendar:cal];
            
            NSTimeZone *tz = [NSDate UTCTimeZone];
            if (!tz)
                OBASSERT_NOT_REACHED("Can't find UTC time zone");
            else {
                // NOTE: NSDateComponents has busted API since -second returns an integer instead of a floating point (Radar 4867971).  Otherwise, we could conceivably implement our formatting by getting the components for the date and then using NSString formatting directly.
                // Asking the date formatter to do the seconds doesn't work either -- Radar 4886510; NSDateFormatter/ICU is truncating the milliseconds instead of rounding it.
                // So, we format up to the milliseconds and -xmlString does the rest.  Sigh.
                [DateFormatter setTimeZone:tz];
                [DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'."];
            }
        }
    }
    
    OBPOSTCONDITION([DateFormatter formatterBehavior] == NSDateFormatterBehavior10_4);
    return DateFormatter;
}

// The setup of this formatter cannot be changed willy-nilly.  This is used in XML archiving, and our file formats need to be stable.  Luckily this is a nicely defined format.
static NSDateFormatter *formatterWithoutTime(void)
{
    static NSDateFormatter *DateFormatter = nil;
    
    if (!DateFormatter) {
        DateFormatter = [[NSDateFormatter alloc] init];
        [DateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[DateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
        OBASSERT([DateFormatter formatterBehavior] == NSDateFormatterBehavior10_4);
        
        NSCalendar *cal = [NSDate gregorianUTCCalendar];
        if (!cal)
            OBASSERT_NOT_REACHED("Built-in calendar missing");
        else {
            OBASSERT([cal timeZone] == [NSDate UTCTimeZone]); // Should have been set in the creation.
            
            [DateFormatter setCalendar:cal];
            
            NSTimeZone *tz = [NSDate UTCTimeZone];
            if (!tz)
                OBASSERT_NOT_REACHED("Can't find UTC time zone");
            else {
                [DateFormatter setTimeZone:tz];
                [DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'"];
            }
        }
    }
    
    OBPOSTCONDITION([DateFormatter formatterBehavior] == NSDateFormatterBehavior10_4);
    return DateFormatter;
}

// date
- (NSString *)xmlDateString;
{
    DEBUG_XML_STRING(@"-xmlString -- input: %@ %f", self, [self timeIntervalSinceReferenceDate]);
    
    NSString *result = [formatterWithoutTime() stringFromDate:self];
    
    DEBUG_XML_STRING(@"result: %@", result);
    
    return result;
}

// dateTime
- (NSString *)xmlString;
{
    DEBUG_XML_STRING(@"-xmlString -- input: %@ %f", self, [self timeIntervalSinceReferenceDate]);

    // Convert ourselves to date components and back, which drops the milliseconds.
    NSCalendar *calendar = [NSDate gregorianUTCCalendar];
    NSDateComponents *components = [calendar components:NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit fromDate:self];
    DEBUG_XML_STRING(@"components: %@", _comp(components));

    NSDate *truncated = [calendar dateFromComponents:components];

    DEBUG_XML_STRING(@"truncated: %@", truncated);

    // Figure out the milliseconds that got dropped
    NSTimeInterval milliseconds = [self timeIntervalSinceReferenceDate] - [truncated timeIntervalSinceReferenceDate];
    
    DEBUG_XML_STRING(@"milliseconds: %f", milliseconds);

    // Append the milliseconds, using rounding.
    NSString *formattedString = [formatterWithoutMilliseconds() stringFromDate:self];
    DEBUG_XML_STRING(@"formattedString: %@", formattedString);
    
    NSString *result = [formattedString stringByAppendingFormat:@"%03dZ", (int)rint(milliseconds * 1000.0)];
    DEBUG_XML_STRING(@"result: %@", result);
    
    return result;
}

@end

// 10.4 has a bug where -copyWithZone: apparently calls [self allocWithZone:] instead of [[self class] allocWithZone:].
#if defined(MAC_OS_X_VERSION_10_4) && MAC_OS_X_VERSION_MIN_ALLOWED <= MAC_OS_X_VERSION_10_4
#import <Foundation/NSCalendar.h>
@interface NSDateComponents (OFTigerFixes)
@end
@implementation NSDateComponents (OFTigerFixes)
- (id)allocWithZone:(NSZone *)zone;
{
    return [[self class] allocWithZone:zone];
}
@end
#endif
