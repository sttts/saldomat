// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//

#define STEnableDeprecatedAssertionMacros
#import <SenTestingKit/SenTestingKit.h>
#import <OmniFoundation/NSScanner-OFExtensions.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFScannerTests.m 92218 2007-10-02 23:36:48Z wiml $");

@interface OFScannerTests : SenTestCase
{
}
@end

@implementation OFScannerTests

- (NSArray *)componentArraysFromString:(NSString *)string;
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
    [scanner setCharactersToBeSkipped:nil];
    NSArray *components;
    NSMutableArray *result = [NSMutableArray array];
    while ([scanner scanLineComponentsSeparatedByString:@"," intoArray:&components])
        [result addObject:components];

    return result;
}

- (void)testScanLineComponentsSeparatedByString;
{
    NSArray *expect = [NSArray arrayWithObjects:[NSArray arrayWithObjects:@"1", @"a", @"", nil],
        [NSArray arrayWithObjects:@"2", @"b", @"", nil],
        nil];
    shouldBeEqual([self componentArraysFromString:@"1,a,\n2,b,"], expect);
    
    expect = [NSArray arrayWithObject:[NSArray arrayWithObjects:@"1", @"2", @"3", nil]];
    shouldBeEqual([self componentArraysFromString:@"1,2,3"], expect);
    
    expect = [NSArray arrayWithObject:[NSArray arrayWithObjects:@"String", @"1", @"Fizzle's", @"I said, \"Hi there\", and ran away.", nil]];
    shouldBeEqual([self componentArraysFromString:@"String,1,\"Fizzle's\",\"I said, \"\"Hi there\"\", and ran away.\""], expect);

    expect = [NSArray arrayWithObject:[NSArray arrayWithObjects:@"\"", @"2", nil]];
    shouldBeEqual([self componentArraysFromString:@"\"\"\"\",2"], expect);
    
    expect = [NSArray array];
    shouldBeEqual([self componentArraysFromString:@"I said,\"\"Hi there\"\".\""], expect);  // "" w/in non-quoted field == bad syntax

    expect = [NSArray arrayWithObject:[NSArray arrayWithObjects:@"I said, \"Hi\nthere\".", @"2", nil]];
    shouldBeEqual([self componentArraysFromString:@"\"I said, \"\"Hi\nthere\"\".\",2"], expect); 

    expect = [NSArray array];
    shouldBeEqual([self componentArraysFromString:@"\""], expect); // one quote does not stand alone

    expect = [NSArray arrayWithObject:[NSArray arrayWithObject:@""]];
    shouldBeEqual([self componentArraysFromString:@"\n"], expect); 

    expect = [NSArray arrayWithObjects:
        [NSArray arrayWithObject:@""],
        [NSArray arrayWithObject:@""],
        nil];
    shouldBeEqual([self componentArraysFromString:@"\n\n"], expect); 

    expect = [NSArray array];
    shouldBeEqual([self componentArraysFromString:@""], expect); 
    
}

@end

@implementation OFScannerTests (DelegatesAndDataSources)

@end

@implementation OFScannerTests (Private)

@end
