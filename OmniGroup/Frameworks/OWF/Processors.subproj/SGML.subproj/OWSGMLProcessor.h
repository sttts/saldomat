// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWSGMLProcessor.h 68913 2005-10-03 19:36:19Z kc $

#import <OWF/OWObjectStreamProcessor.h>

@class NSMutableArray, NSUserDefaults;
@class OWAddress, OWSGMLAppliedMethods, OWSGMLDTD, OWSGMLMethods, OWSGMLTag, OWSGMLTagType;

@interface OWSGMLProcessor : OWObjectStreamProcessor
{
    OWSGMLAppliedMethods *appliedMethods;
    OWAddress *baseAddress;
    unsigned int *openTags;
    unsigned int *implicitlyClosedTags;
    NSMutableArray *undoers;
}

+ (OWSGMLMethods *)sgmlMethods;
+ (OWSGMLDTD *)dtd;

+ (void)setDebug:(BOOL)newDebugSetting;

- (void)setBaseAddress:(OWAddress *)anAddress;

- (BOOL)hasOpenTagOfType:(OWSGMLTagType *)tagType;
- (void)openTagOfType:(OWSGMLTagType *)tagType;
- (void)closeTagOfType:(OWSGMLTagType *)tagType;

- (void)processContentForTag:(OWSGMLTag *)tag;
- (void)processUnknownTag:(OWSGMLTag *)tag;
- (void)processIgnoredContentsTag:(OWSGMLTag *)tag;
- (void)processTag:(OWSGMLTag *)tag;
- (BOOL)processEndTag:(OWSGMLTag *)tag;
- (void)processCData:(NSString *)cData;

- (OWAddress *)baseAddress;

@end

@interface OWSGMLProcessor (Tags)
- (OWAddress *)addressForAnchorTag:(OWSGMLTag *)tag;
- (void)processMeaninglessTag:(OWSGMLTag *)tag;
- (void)processBaseTag:(OWSGMLTag *)tag;
- (void)processMetaTag:(OWSGMLTag *)tag;
- (void)processHTTPEquivalent:(NSString *)header value:(NSString *)value;  // To be overridden by subclasses
- (void)processTitleTag:(OWSGMLTag *)tag;
@end

@interface OWSGMLProcessor (SubclassesOnly)
- (BOOL)_hasOpenTagOfTypeIndex:(unsigned int)tagIndex;
- (void)_openTagOfTypeIndex:(unsigned int)tagIndex;
- (void)_implicitlyCloseTagAtIndex:(unsigned int)tagIndex;
- (BOOL)_closeTagAtIndexWasImplicit:(unsigned int)tagIndex;
@end
