// Copyright 2002-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSDate-OFExtensions.h>

#define STEnableDeprecatedAssertionMacros
#import <SenTestingKit/SenTestingKit.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFDateXMLTests.m 92218 2007-10-02 23:36:48Z wiml $")

@interface OFDateXMLTestCase : SenTestCase
@end


@implementation OFDateXMLTestCase

- (void)testUTCTimeZone;
{
    NSTimeZone *tz = [NSDate UTCTimeZone];
    should(tz != nil);
    should([tz secondsFromGMT] == 0);
    shouldBeEqual([tz abbreviation], @"UTC");
}

- (void)testGregorianUTCCalendar;
{
    NSCalendar *cal = [NSDate gregorianUTCCalendar];
    should(cal != nil);
    shouldBeEqual([cal calendarIdentifier], NSGregorianCalendar);
    shouldBeEqual([cal timeZone], [NSDate UTCTimeZone]);
}

- (void)testXMLDateParsing;
{
    NSDate *date = [[[NSDate alloc] initWithXMLString:@"2004-06-07T14:15:34.987Z"] autorelease];
    
    NSDateComponents *components = [[NSDate gregorianUTCCalendar] components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit fromDate:date];
    
    should([components year] == 2004);
    should([components month] == 6);
    should([components day] == 7);
    should([components hour] == 14);
    should([components minute] == 15);
    should([components second] == 34); // Not float (Radar 4867971).  Choice of floating portion ensures we are checking that they truncate.
    
    NSTimeInterval interval = [date timeIntervalSinceReferenceDate];
    NSTimeInterval milliseconds = interval - floor(interval);
    should(fabs(milliseconds - 0.987) < 0.0001);
}

#define ROUND_TRIP(inputString) do { \
    NSDate *date = [[[NSDate alloc] initWithXMLString:inputString] autorelease]; \
    NSString *outputString = [date xmlString]; \
    shouldBeEqual(inputString, outputString); \
} while(0)

- (void)testXMLDateParsingRoundTrip;
{
    // This case had a rounding problem such that converting the date back to an XML string would end up with .139Z instead of .140Z.
    ROUND_TRIP(@"2006-12-15T21:38:04.140Z");

    // This was going to a NSDate of "2007-12-30 21:00:00 -0800" and then to an XML string of "2008-12-31T05:00:00.000Z"
    ROUND_TRIP(@"2007-12-31T05:00:00.000Z");
}

@end
