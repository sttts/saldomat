// Copyright 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//

#import <OmniFoundation/NSIndexSet-OFExtensions.h>
#import <OmniFoundation/NSMutableString-OFExtensions.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSIndexSet-OFExtensions.m 98846 2008-03-19 21:42:15Z wiml $")

@implementation NSIndexSet (OFExtensions)

- (NSString *)rangeString;
{
    switch([self count]) {
        case 0:
            return @"";
        case 1:
            return [NSString stringWithFormat:@"%u", [self firstIndex]];
    }
    
    NSMutableString *buf = [NSMutableString string];
    BOOL first = YES;
    NSUInteger cursor = [self firstIndex];
    for(;;) {
        NSRange span = [self rangeGreaterThanOrEqualToIndex:cursor];
        if (span.length == 0)
            break;
        if (!first)
            [buf appendCharacter:','];
        if (span.length == 1)
            [buf appendFormat:@"%u", span.location];
        else
            [buf appendFormat:@"%u-%u", span.location, span.location + (span.length - 1)];
        cursor = span.location + span.length;
        first = NO;
    }
    
    return buf;
}

static NSRange rangeFromString(NSString *aString, NSIndexSet *errSelf, SEL errCmd)
{
    if ([NSString isEmptyString:aString]) {
        return (NSRange){ 0, 0 };
    }

    // For correctness, we really need an -unsignedIntegerValue on NSString which returns an NSUInteger. However, because Apple uses NSNotFound (== NSInteger's max value) as a special marker value for both NSIntegers and NSUIntegers, the useful range of an NSUInteger is actually not any larger than NSUIntegers. Good work, Apple.
    
    NSRange dashRange = [aString rangeOfString:@"-"];
    if (dashRange.length == 0) {
        NSInteger ix = [aString integerValue];
        return (NSRange){ ix, 1 };
    } else {
        NSString *left = [aString substringToIndex:dashRange.location];
        NSString *right = [aString substringFromIndex:dashRange.location + dashRange.length];
        
        if ([NSString isEmptyString:left] || [NSString isEmptyString:right]) {
            OBRejectInvalidCall(errSelf, errCmd, @"Cannot parse open-ended range \"%@\"", aString);
        }
        
        NSInteger leftValue = [left integerValue];
        NSInteger rightValue = [right integerValue];
        
        if (rightValue < leftValue)
            OBRejectInvalidCall(errSelf, errCmd, @"Index range \"%@\" is backwards", aString);

        return (NSRange){ leftValue, 1 + (rightValue - leftValue) };
    }
}

- initWithRangeString:(NSString *)aString
{
    if ([NSString isEmptyString:aString])
        return [self init];
    
    NSArray *ranges = [aString componentsSeparatedByString:@","];
    if ([ranges count] == 1)
        return [self initWithIndexesInRange:rangeFromString([ranges objectAtIndex:0], self, _cmd)];

    if ([self isKindOfClass:[NSMutableIndexSet class]]) {
        NSMutableIndexSet *mutableSelf;
        self = mutableSelf = [self init];
        for(NSString *rangeString in ranges)
            [mutableSelf addIndexesInRange:rangeFromString(rangeString, self, _cmd)];
    } else {
        NSMutableIndexSet *temporarySet = [[NSMutableIndexSet alloc] init];
        for(NSString *rangeString in ranges)
            [temporarySet addIndexesInRange:rangeFromString(rangeString, self, _cmd)];
        self = [self initWithIndexSet:temporarySet];
        [temporarySet release];
    }
    
    return self;
}

+ indexSetWithRangeString:(NSString *)aString;
{
    return [[[self alloc] initWithRangeString:aString] autorelease];
}

- (NSRange)rangeGreaterThanOrEqualToIndex:(NSUInteger)fromIndex;
{
    fromIndex = [self indexGreaterThanOrEqualToIndex:fromIndex];
    
    if (fromIndex == NSNotFound) {
        return (NSRange){NSNotFound, 0};
    }
    
    // There isn't a direct way to extract the next contiguous range, even though NSIndexSet's internal representation is a sorted list of ranges --- so we do a binary search for the end of this range.
    
    NSRange result;
    result.location = fromIndex;
    result.length = 1;
    NSUInteger step = 1;
    
    while ([self containsIndexesInRange:(NSRange){ result.location, result.length + step }]) {
        result.length += step;
        step <<= 1;
    }
    // At this point, we know that we contain the indices in the 'result' range, but somewhere in the next 'step' indices there's one missing.
    // So we can do a normal binary search within that range.
    
    while(step > 1) {
        step >>= 1;
        BOOL afterFirstHalf = [self containsIndexesInRange:(NSRange){ result.location, result.length + step }];
        if (afterFirstHalf)
            result.length += step;
    }
    
    return result;
}

@end
