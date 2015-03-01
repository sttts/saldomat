// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWHTMLToSGMLObjects.h 68913 2005-10-03 19:36:19Z kc $

#import <OWF/OWDataStreamCharacterProcessor.h>
#import <Foundation/NSString.h>

@class OFTrie;
@class OWDataStreamCharacterCursor, OWDataStreamScanner, OWObjectStream, OWSGMLDTD, OWSGMLTagType;

@interface OWHTMLToSGMLObjects : OWDataStreamCharacterProcessor
{
    OWObjectStream *objectStream;
    OWDataStreamScanner *scanner;
    OFTrie *tagTrie;
    OWSGMLDTD *sourceContentDTD;

    struct {
        unsigned int netscapeCompatibleComments:1;
        unsigned int netscapeCompatibleNewlineAfterEntity:1;
        // ISO 8879 9.4.5 [61] 353:1 says that newlines following an entity should be ignored.  Unfortunately, Netscape preserves them.
        unsigned int netscapeCompatibleNonterminatedEntities:1;
        // Netscape does not require proper termination of entities.

        unsigned int shouldObeyMetaTag:1;
        unsigned int haveAddedObjectStreamToPipeline:1;
    } flags;
    
    OWSGMLTagType *metaCharsetHackTagType, *endMetaCharsetHackTagType;

    CFStringEncoding resetSourceEncoding;
}

+ (BOOL)recognizesEntityNamed:(NSString *)entityName;
    // Returns YES if the named entity is known.
    
+ (NSString *)entityNameForCharacter:(unichar)character;
    // Returns the name of an entity that resolves to this single character, if one is known.


// - (OWObjectStream *)outputStream;

@end
