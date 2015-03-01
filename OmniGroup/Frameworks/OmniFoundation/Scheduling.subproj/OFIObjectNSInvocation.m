// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFIObjectNSInvocation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectNSInvocation.m 98770 2008-03-17 22:25:33Z kc $")

@implementation OFIObjectNSInvocation;

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id)anObject nsInvocation:(NSInvocation *)anInvocation;
{
    [super initForObject:anObject];
    nsInvocation = [anInvocation retain];
    return self;
}

- (void)dealloc;
{
    [nsInvocation release];
    [super dealloc];
}

- (void)invoke;
{
    [nsInvocation invokeWithTarget:object];
}

- (unsigned int)hash;
{
    return (unsigned int)object + [nsInvocation hash];
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectNSInvocation *otherInvocation;

    otherInvocation = anObject;
    if (otherInvocation->isa != myClass)
	return NO;
    return object == otherInvocation->object && [nsInvocation isEqual:otherInvocation->nsInvocation];
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
	[debugDictionary setObject:object forKey:@"object"];
    if (nsInvocation)
	[debugDictionary setObject:nsInvocation forKey:@"nsInvocation"];
    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@%d]", OBShortObjectDescription(object), [nsInvocation description]];
}

@end
