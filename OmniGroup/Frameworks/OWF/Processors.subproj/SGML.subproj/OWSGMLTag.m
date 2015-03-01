// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWSGMLTag.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/NSString-OWSGMLString.h>
#import <OWF/OWSGMLTagType.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWSGMLTag.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWSGMLTag

static NSMutableCharacterSet *requiresQuotesCharacterSet = nil;

+ (void)initialize;
{
    OBINITIALIZE;

    requiresQuotesCharacterSet = [[NSMutableCharacterSet alloc] init];
    [requiresQuotesCharacterSet addCharactersInString:@".-"];
    [requiresQuotesCharacterSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    [requiresQuotesCharacterSet invert];
}

+ (OWSGMLTag *)retainedTagWithTokenType:(OWSGMLTokenType)aType tagType:(OWSGMLTagType *)aTagType;
{
    OWSGMLTag *result;
    unsigned int tagTypeAttributeCount;
    
    tagTypeAttributeCount = [aTagType attributeCount];
    result = (id)NSAllocateObject(self, sizeof(NSString *) * tagTypeAttributeCount, NULL);
    result->tokenType = aType;
    result->nonretainedTagType = aTagType;
    OBASSERT(tagTypeAttributeCount < 256);
    result->attributeCount = (unsigned char)tagTypeAttributeCount;
    return result;
}

+ (OWSGMLTag *)tagWithTokenType:(OWSGMLTokenType)aType tagType:(OWSGMLTagType *)aTagType;
{
    return [[self retainedTagWithTokenType:aType tagType:aTagType] autorelease];
}

+ (OWSGMLTag *)startTagOfType:(OWSGMLTagType *)aTagType;
{
    return [[self retainedTagWithTokenType:OWSGMLTokenTypeStartTag tagType:aTagType] autorelease];
}

+ (OWSGMLTag *)endTagOfType:(OWSGMLTagType *)aTagType;
{
    return [[self retainedTagWithTokenType:OWSGMLTokenTypeEndTag tagType:aTagType] autorelease];
}

- (void)dealloc;
{
    unsigned int attributeIndex;

    for (attributeIndex = 0; attributeIndex < attributeCount; attributeIndex++)
        [attributes[attributeIndex] release];
        
    [extraAttributes release];
    extraAttributes = nil;
    
    [super dealloc];
}

//

- (OWSGMLTagType *)tagType;
{
    return nonretainedTagType;
}

- (NSString *)name;
{
    return [nonretainedTagType name];
}

- (NSDictionary *)attributes;
{
    NSMutableDictionary *result;
    NSArray *attributeNames;
    unsigned int attributeIndex;

    result = [NSMutableDictionary dictionary];
    attributeNames = [nonretainedTagType attributeNames];
    for (attributeIndex = 0; attributeIndex < attributeCount; attributeIndex++) {
        NSString *attributeName, *attributeValue;

        attributeName = [attributeNames objectAtIndex:attributeIndex];
        if ((attributeValue = attributes[attributeIndex]))
            [result setObject:attributeValue forKey:attributeName];
    }
    return result;
}

//

- (BOOL)isNamed:(NSString *)aName;
{
    return [[nonretainedTagType name] isEqualToString:aName];
}

//

- (void)setValue:(NSString *)value atIndex:(unsigned int)index;
{
    OBPRECONDITION(index < attributeCount);
    // WJS 4/6/98: Netscape 4.0 and IE 4.0 both ignore any but the first value for an attribute, so if we already have a value we just return.
    if (attributes[index])
        return;
    attributes[index] = [value retain];
}

- (NSString *)valueForAttribute:(NSString *)attributeName;
{
    unsigned int attributeIndex;

    attributeIndex = [nonretainedTagType indexOfAttribute:attributeName];
    if (attributeIndex == NSNotFound)
        return nil;
    return sgmlTagValueForAttributeAtIndex(self, attributeIndex);
}

- (BOOL)attributePresent:(NSString *)attributeName;
{
    unsigned int attributeIndex;

    attributeIndex = [nonretainedTagType indexOfAttribute:attributeName];
    return sgmlTagAttributePresentAtIndex(self, attributeIndex);
}

//

- (NSString *)valueForAttributeAtIndex:(unsigned int)index;
{
    return sgmlTagValueForAttributeAtIndex(self, index);
}

- (BOOL)attributePresentAtIndex:(unsigned int)index;
{
    return sgmlTagAttributePresentAtIndex(self, index);
}

// Extra attributes (which were parsed but not recognized)

- (NSDictionary *)extraAttributes;
{
    return extraAttributes;
}

- (void)setValue:(NSString *)value forExtraAttribute:(NSString *)attributeName;
{
    if (!extraAttributes)
        extraAttributes = [[NSMutableDictionary alloc] init];
    else if ([extraAttributes objectForKey:attributeName])
        // Ignore any but the first value for an attribute
        return;

    [extraAttributes setObject:value forKey:attributeName];
}

// Common attributes to all tags

- (NSString *)valueForIDAttribute;
{
    return sgmlTagValueForAttributeAtIndex(self, [OWSGMLTagType idAttributeIndex]);
}
- (NSString *)valueForClassAttribute;
{
    return sgmlTagValueForAttributeAtIndex(self, [OWSGMLTagType classAttributeIndex]);
}
- (NSString *)valueForStyleAttribute;
{
    return sgmlTagValueForAttributeAtIndex(self, [OWSGMLTagType styleAttributeIndex]);
}


// OWSGMLToken protocol

- (NSString *)sgmlString;
{
    return [self sgmlStringWithQuotingFlags:SGMLQuoting_NamedEntities];
}

- (NSString *)sgmlStringWithQuotingFlags:(int)flags;
{
    NSMutableString *sgmlString;
    NSArray *attributeNames;
    unsigned int attributeIndex;

    flags &= ~( SGMLQuoting_AllowAttributeMetas );
    sgmlString = [NSMutableString stringWithCapacity:[[nonretainedTagType name] length] + 3];
    [sgmlString appendString:(tokenType == OWSGMLTokenTypeStartTag) ? @"<" : @"</"];
    [sgmlString appendString:[nonretainedTagType name]];
    attributeNames = [nonretainedTagType attributeNames];
    for (attributeIndex = 0; attributeIndex < attributeCount; attributeIndex++) {
        NSString *attributeName, *attributeValue;

        attributeName = [attributeNames objectAtIndex:attributeIndex];
        attributeValue = attributes[attributeIndex];

        if (attributeValue == nil)
            continue;
        [sgmlString appendFormat:@" %@", attributeName];
        if ([attributeValue isNull])
            continue;
        if ([attributeValue rangeOfCharacterFromSet:requiresQuotesCharacterSet].length) {
            [sgmlString appendFormat:@"=\"%@\"", [attributeValue stringWithEntitiesQuoted:flags]];
        } else {
            [sgmlString appendFormat:@"=%@", [attributeValue stringWithEntitiesQuoted:flags]];
        }
    }
    [sgmlString appendString:@">"];
    return sgmlString;
}

- (NSString *)string;
{
    return [self sgmlString];
}

- (OWSGMLTokenType)tokenType;
{
    return tokenType;
}

// Debugging

- (NSString *)shortDescription;
{
    return [self sgmlString];
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;
    NSString *typeString;

    debugDictionary = [super debugDictionary];
    switch (tokenType) {
        case OWSGMLTokenTypeStartTag:
            typeString = @"StartTag";
            break;
        case OWSGMLTokenTypeEndTag:
            typeString = @"EndTag";
            break;
        default:
            typeString = nil;
            break;
    }
    if (typeString)
	[debugDictionary setObject:typeString forKey:@"_type"];
    if (nonretainedTagType)
        [debugDictionary setObject:nonretainedTagType forKey:@"nonretainedTagType"];
    [debugDictionary setObject:[self attributes] forKey:@"attributes"];
    if (extraAttributes)
        [debugDictionary setObject:extraAttributes forKey:@"extraAttributes"];
    return debugDictionary;
}

@end
