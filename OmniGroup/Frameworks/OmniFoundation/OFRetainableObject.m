// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFRetainableObject.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OFRetainableObject.m 93428 2007-10-25 16:36:11Z kc $")

@implementation OFRetainableObject

+ (void) initialize;
{
}

+ alloc;
{
    return [self allocWithZone:NULL];
}

+ allocWithZone:(NSZone *)aZone;
{
    return NSAllocateObject(self, 0, aZone);
}

- (Class)class;
{
    return isa;
}

- (unsigned)retainCount;
{
    return NSExtraRefCount(self) + 1;
}

- (id)retain;
{
    NSIncrementExtraRefCount(self);
    return self;
}

- (void)release;
{
    if (NSDecrementExtraRefCountWasZero(self))
	[self dealloc];
}

- (id)autorelease;
{
    [NSAutoreleasePool addObject:self];
    return self;
}

- (void)dealloc;
{
    NSDeallocateObject((id <NSObject>)self);
}


@end
