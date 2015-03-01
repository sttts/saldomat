// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFIObjectSelectorBool.h>

#import <objc/objc-class.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFIObjectSelectorBool.m 98770 2008-03-17 22:25:33Z kc $")

@implementation OFIObjectSelectorBool;

static Class myClass;

+ (void)initialize;
{
    OBINITIALIZE;
    myClass = self;
}

- initForObject:(id)anObject selector:(SEL)aSelector withBool:(BOOL)aBool;
{
    OBPRECONDITION([anObject respondsToSelector:aSelector]);

    [super initForObject:anObject selector:aSelector];

    theBool = aBool;

    return self;
}

- (void)invoke;
{
    Class cls = object_getClass(object);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        [NSException raise:NSInvalidArgumentException format:@"%s(0x%x) does not respond to the selector %@", class_getName(cls), (unsigned)object, NSStringFromSelector(selector)];

    method_getImplementation(method)(object, selector, theBool);
}

- (unsigned int)hash;
{
    return (unsigned int)object + (unsigned int)(void *)selector + (unsigned int)theBool;
}

- (BOOL)isEqual:(id)anObject;
{
    OFIObjectSelectorBool *otherObject;

    otherObject = anObject;
    if (object_getClass(otherObject) != myClass)
	return NO;
    return object == otherObject->object && selector == otherObject->selector && theBool == otherObject->theBool;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (object)
	[debugDictionary setObject:object forKey:@"object"];
    [debugDictionary setObject:NSStringFromSelector(selector) forKey:@"selector"];
    [debugDictionary setObject:theBool ? @"YES" : @"NO" forKey:@"theBool"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"-[%@ %@%d]", OBShortObjectDescription(object), NSStringFromSelector(selector), theBool ? @"YES" : @"NO"];
}

@end
