// Copyright 2000-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#define STEnableDeprecatedAssertionMacros
#import <SenTestingKit/SenTestingKit.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFNumberFormatterTest.m 93428 2007-10-25 16:36:11Z kc $")

@interface OFNumberFormatterTest : SenTestCase
{
}

@end

@implementation OFNumberFormatterTest

- (void)testNegativeDecimalString;
{
    NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_0]; // When linking 10.5, this will default to the 10.4 behavior, but we are testing the 10.4 behavior.
    [numberFormatter setFormat:@"###;$0.00;(0.00000)"];

    NSDecimalNumber *originalValue = [NSDecimalNumber decimalNumberWithString:@"-1.01234"];
    NSString *str = [numberFormatter stringForObjectValue:originalValue];
    shouldBeEqual(str, @"(1.01234)");

    id objectValue;
    NSString *error = (id)0xdeadbeef; // make sure this doesn't get written
    BOOL result = [numberFormatter getObjectValue:&objectValue forString:str errorDescription:&error];
    should(error == (id)0xdeadbeef);
    should(result);
    shouldBeEqual(objectValue, originalValue);
}

@end
