// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#define STEnableDeprecatedAssertionMacros
#import <SenTestingKit/SenTestingKit.h>
#import <OmniFoundation/CFArray-OFExtensions.h>
#import <OmniFoundation/NSString-OFExtensions.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/CFArrayExtensionsTests.m 93428 2007-10-25 16:36:11Z kc $");

@interface CFArrayExtensionsTests :  SenTestCase
@end

@implementation CFArrayExtensionsTests

- (void)testPointerArray;
{
    NSMutableArray *array = OFCreateNonOwnedPointerArray();
    [array addObject:(id)0xdeadbeef];
    should([array count] == 1);
    should([array objectAtIndex:0] == (id)0xdeadbeef);
    should([array indexOfObject:(id)0xdeadbeef] == 0);
    
    // This crashes; -[NSArray description] isn't the same, apparently
    //NSString *description = [array description];
    NSString *description = [(id)CFCopyDescription(array) autorelease];
    
    should([description containsString:@"0xdeadbeef"]);
}

- (void)testIntegerArray;
{
    NSMutableArray *array = OFCreateIntegerArray();
    [array addObject:(id)6060842];
    should([array count] == 1);
    should([array objectAtIndex:0] == (id)6060842);
    should([array indexOfObject:(id)6060842] == 0);

    // This crashes; -[NSArray description] isn't the same, apparently
    //NSString *description = [array description];
    NSString *description = [(id)CFCopyDescription(array) autorelease];
    
    should([description containsString:@"6060842"]);
}

@end
