// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFInvocation.h>

#import <OmniFoundation/OFMessageQueuePriorityProtocol.h>
#import <OmniFoundation/OFTemporaryPlaceholderInvocation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFInvocation.m 98770 2008-03-17 22:25:33Z kc $")

@implementation OFInvocation

OFTemporaryPlaceholderInvocation *temporaryPlaceholderInvocation;

+ (void)initialize;
{
    OBINITIALIZE;
    temporaryPlaceholderInvocation = [OFTemporaryPlaceholderInvocation alloc];
}


+ alloc;
{
    return temporaryPlaceholderInvocation;
}

+ allocWithZone:(NSZone *)aZone;
{
    // If I really cared about zones, I'd return a different placeholder for each zone.
    return temporaryPlaceholderInvocation;
}

- (id <NSObject>)object;
{
    return nil;
}

- (SEL)selector;
{
    OBRequestConcreteImplementation(self, _cmd);
    return (SEL)0;
}

- (void)invoke;
{
    OBRequestConcreteImplementation(self, _cmd);
}

- (OFMessageQueueSchedulingInfo)messageQueueSchedulingInfo;
{
    OBRequestConcreteImplementation(self, _cmd);
}

@end
