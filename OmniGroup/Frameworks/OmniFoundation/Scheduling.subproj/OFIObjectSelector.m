// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFIObjectSelector.h>

#import <objc/objc-class.h>

#import <OmniFoundation/OFMessageQueuePriorityProtocol.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelector.m 98770 2008-03-17 22:25:33Z kc $")

@implementation OFIObjectSelector

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id)anObject;
{
    OBRejectUnusedImplementation(self, _cmd);
    return nil;
}

- initForObject:(id)anObject selector:(SEL)aSelector;
{
    OBPRECONDITION([anObject respondsToSelector:aSelector]);

    [super initForObject:anObject];

    selector = aSelector;
    if ([anObject respondsToSelector:@selector(fixedPriorityForSelector:)])
        [self setPriorityLevel:[anObject fixedPriorityForSelector:aSelector]];

    return self;
}

- (void)invoke;
{
    Class cls = object_getClass(object);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        [NSException raise:NSInvalidArgumentException format:@"%s(0x%x) does not respond to the selector %@", class_getName(cls), (unsigned)object, NSStringFromSelector(selector)];

    method_getImplementation(method)(object, selector);
}

- (SEL)selector;
{
    return selector;
}

- (unsigned int)hash;
{
    return (unsigned int)object + (unsigned int)(void *)selector;
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelector *otherObject;

    otherObject = anObject;
    if (otherObject == self)
	return YES;
    if (object_getClass(otherObject) != myClass)
	return NO;
    return object == otherObject->object && selector == otherObject->selector;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
	[debugDictionary setObject:object forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@]", OBShortObjectDescription(object), NSStringFromSelector(selector)];
}

@end
