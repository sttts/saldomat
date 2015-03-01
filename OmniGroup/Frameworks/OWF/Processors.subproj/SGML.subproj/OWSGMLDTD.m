// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWSGMLDTD.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWContentType.h>
#import <OWF/OWSGMLTagType.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWSGMLDTD.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWSGMLDTD

static NSMutableDictionary *dtdForType = nil;

+ (void)initialize;
{
    static BOOL initialized = NO;

    [super initialize];
    if (initialized)
        return;
    initialized = YES;

    dtdForType = [[NSMutableDictionary alloc] init];
}

+ (OWSGMLDTD *)dtdForSourceContentType:(OWContentType *)aSourceType;
{
    return [dtdForType objectForKey:[aSourceType contentTypeString]];
}

+ (NSArray *)allDTDs;
{
    return [dtdForType allValues];
}

+ (OWSGMLDTD *)registeredDTDForSourceContentType:(OWContentType *)aSourceType destinationContentType:(OWContentType *)aDestinationType;
{
    OWSGMLDTD *dtd;

    dtd = [[[self alloc] initWithSourceType:aSourceType destinationType:aDestinationType] autorelease];

    OBASSERT(![dtdForType objectForKey:[aSourceType contentTypeString]]);
    [dtdForType setObject:dtd forKey:[aSourceType contentTypeString]];

    return dtd;
}

- initWithSourceType:(OWContentType *)aSource 
    destinationType:(OWContentType *)aDestination;
{
    [super init];
    sourceType = [aSource retain];
    destinationType = [aDestination retain];
    tagTrie = [[OFTrie alloc] initCaseSensitive:NO];
    tagCount = 0;
    allTags = [[NSMutableArray alloc] init];
    return self;
}

- (OFTrie *)tagTrie;
{
    return tagTrie;
}

- (OWContentType *)sourceType;
{
    return sourceType;
}

- (OWContentType *)destinationType;
{
    return destinationType;
}

- (unsigned int)tagCount;
{
    return tagCount;
}

- (OWSGMLTagType *)tagTypeAtIndex:(unsigned int)index;
{
    return [allTags objectAtIndex:index];
}

- (OWSGMLTagType *)tagTypeNamed:(NSString *)aName;
{
    OWSGMLTagType *tagType;

    tagType = (OWSGMLTagType *)[tagTrie bucketForString:aName];

    if (!tagType) {
        tagType = [[OWSGMLTagType alloc] initWithName:aName dtdIndex:tagCount++];
        [tagTrie addBucket:tagType forString:aName];
        [allTags addObject:tagType];
        [tagType release];
    }
    return tagType;
}

- (BOOL)hasTagTypeNamed:(NSString *)aName;
{
    return [tagTrie bucketForString:aName] != nil;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];

    [debugDictionary setObject:tagTrie forKey:@"tagTrie"];
    [debugDictionary setObject:sourceType forKey:@"sourceType"];
    [debugDictionary setObject:destinationType forKey:@"destinationType"];
    [debugDictionary setObject:[NSString stringWithFormat:@"%d", tagCount] forKey:@"tagCount"];

    return debugDictionary;
}

@end
