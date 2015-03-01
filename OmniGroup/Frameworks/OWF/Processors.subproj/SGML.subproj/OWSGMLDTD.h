// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWSGMLDTD.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniFoundation/OFObject.h>

@class OFTrie;
@class OWContentType, OWSGMLTagType;
@class NSArray, NSMutableArray;

@interface OWSGMLDTD : OFObject
{
    OFTrie *tagTrie;
    NSMutableArray *allTags;
    OWContentType *sourceType;
    OWContentType *destinationType;
    unsigned int tagCount;
}

+ (OWSGMLDTD *)dtdForSourceContentType:(OWContentType *)aSourceType;
+ (NSArray *)allDTDs;

+ (OWSGMLDTD *)registeredDTDForSourceContentType: (OWContentType *) aSourceType
                          destinationContentType: (OWContentType *) aDestinationType;

- initWithSourceType:(OWContentType *)aSource destinationType:(OWContentType *)aDestination;

- (OFTrie *)tagTrie;
- (OWContentType *)sourceType;
- (OWContentType *)destinationType;
- (unsigned int)tagCount;
- (OWSGMLTagType *)tagTypeAtIndex:(unsigned int)index;
- (OWSGMLTagType *)tagTypeNamed:(NSString *)aName;
- (BOOL)hasTagTypeNamed:(NSString *)aName;

@end
