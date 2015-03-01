// Copyright 2003-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFXMLWhitespaceBehavior.h>

#import <OmniFoundation/CFDictionary-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/XML/OFXMLWhitespaceBehavior.m 98770 2008-03-17 22:25:33Z kc $");

@implementation OFXMLWhitespaceBehavior

+ (OFXMLWhitespaceBehavior *)ignoreWhitespaceBehavior;
{
    static OFXMLWhitespaceBehavior *whitespace = nil;
    
    if (!whitespace)
        whitespace = [[OFXMLWhitespaceBehavior alloc] initWithDefaultBehavior:OFXMLWhitespaceBehaviorTypeIgnore];
    
    return whitespace;
}

// Init and dealloc

- initWithDefaultBehavior:(OFXMLWhitespaceBehaviorType)defaultBehavior;
{
    _defaultBehavior = defaultBehavior;
    _nameToBehavior = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFNSObjectDictionaryKeyCallbacks, &OFIntegerDictionaryValueCallbacks);
    return self;
}

- init;
{
    return [self initWithDefaultBehavior:OFXMLWhitespaceBehaviorTypeAuto];
}

- (void)dealloc;
{
    if (_nameToBehavior)
        CFRelease(_nameToBehavior);
    [super dealloc];
}

- (void)setBehavior:(OFXMLWhitespaceBehaviorType)behavior forElementName:(NSString *)elementName;
{
    OBPRECONDITION(OFXMLWhitespaceBehaviorTypeAuto == 0);
    
    if (behavior == OFXMLWhitespaceBehaviorTypeAuto)
        CFDictionaryRemoveValue(_nameToBehavior, elementName);
    else
        CFDictionarySetValue(_nameToBehavior, elementName, (const void *)behavior);
}

- (OFXMLWhitespaceBehaviorType)behaviorForElementName:(NSString *)elementName;
{
    OFXMLWhitespaceBehaviorType behavior;
    if (CFDictionaryGetValueIfPresent(_nameToBehavior, elementName, (const void **)&behavior))
        return behavior;
    return _defaultBehavior;
}

@end
