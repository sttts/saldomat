// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWSGMLTag.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniFoundation/OFObject.h>

#import <OWF/OWSGMLTokenProtocol.h>
#import <OWF/OWSGMLTagType.h> // assertions call methods on this class

@interface OWSGMLTag : OFObject <OWSGMLToken>
{
@public
    OWSGMLTokenType tokenType;
    OWSGMLTagType *nonretainedTagType;
    NSMutableDictionary *extraAttributes;
    unsigned char attributeCount;
    NSString *attributes[0];
}

+ (OWSGMLTag *)retainedTagWithTokenType:(OWSGMLTokenType)aType tagType:(OWSGMLTagType *)aTagType;
+ (OWSGMLTag *)tagWithTokenType:(OWSGMLTokenType)aType tagType:(OWSGMLTagType *)aTagType;
+ (OWSGMLTag *)startTagOfType:(OWSGMLTagType *)aTagType;
+ (OWSGMLTag *)endTagOfType:(OWSGMLTagType *)aTagType;

- (OWSGMLTagType *)tagType;
- (NSString *)name;
- (NSDictionary *)attributes;

- (BOOL)isNamed:(NSString *)aName;

- (void)setValue:(NSString *)value atIndex:(unsigned int)index;
- (NSString *)valueForAttribute:(NSString *)attributeName;
- (BOOL)attributePresent:(NSString *)attributeName;

- (NSString *)valueForAttributeAtIndex:(unsigned int)index;
- (BOOL)attributePresentAtIndex:(unsigned int)index;

// Extra attributes (which were parsed but not recognized)
- (NSDictionary *)extraAttributes;
- (void)setValue:(NSString *)value forExtraAttribute:(NSString *)attributeName;

// Common attributes to all tags
- (NSString *)valueForIDAttribute;
- (NSString *)valueForClassAttribute;
- (NSString *)valueForStyleAttribute;

@end

#import <Foundation/NSString.h>
#import <OmniBase/assertions.h>
#import <OmniFoundation/OFNull.h>

static inline OWSGMLTagType *sgmlTagType(OWSGMLTag *tag)
{
    return tag->nonretainedTagType;
}

static inline OWSGMLTokenType sgmlTagTokenType(OWSGMLTag *tag)
{
    return tag->tokenType;
}

static inline BOOL sgmlTagAttributePresentAtIndex(OWSGMLTag *tag, unsigned int index)
{
    OBPRECONDITION(index < [tag->nonretainedTagType attributeCount]);
    if (index >= tag->attributeCount)
        return NO;
    return tag->attributes[index] != nil;
}

static inline NSString *sgmlTagValueForAttributeAtIndex(OWSGMLTag *tag, unsigned int index)
{
    NSString *value;

    OBPRECONDITION(index < [tag->nonretainedTagType attributeCount]);

    if (index >= tag->attributeCount)
        return nil;
    value = tag->attributes[index];
    if (value == OFNullStringObject)
        return nil;
    return value;
}

static inline int sgmlTagIntValueForAttributeAtIndexWithDefaultValue(OWSGMLTag *tag, unsigned int index, int defaultValue)
{
    NSString *value;

    OBPRECONDITION(index < [tag->nonretainedTagType attributeCount]);

    value = sgmlTagValueForAttributeAtIndex(tag, index);
    if (value == nil || [value length] == 0)
        return defaultValue;
    return [value intValue];
}
