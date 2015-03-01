// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWContentType.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniFoundation/OFObject.h>

@class OWContentTypeLink, OWConversionPathElement, OWProcessorDescription;
@class OFMultiValueDictionary;
@class NSArray, NSMutableArray, NSMutableSet, NSSet, NSString;

#import <Foundation/NSDate.h> // For NSTimeInterval

@interface OWContentType : OFObject <NSCoding>
{
    NSString *contentTypeString;
    unsigned int hash;
    NSMutableArray *links;
    NSMutableSet *reverseLinks;
    NSMutableDictionary *bestPathByType;
    NSArray *extensions;
    unsigned long hfsType, hfsCreator;
    NSTimeInterval expirationTimeInterval;

    NSString *imageName;
    NSString *readableString;
    
    struct {
        unsigned int isEncoding:1;
        unsigned int isPublic:1;
        unsigned int isInteresting:1;
    } flags;
}

+ (OWContentType *)contentTypeForString:(NSString *)aString;
+ (OWContentType *)contentEncodingForString:(NSString *)aString;
+ (OWContentType *)existingContentTypeForString:(NSString *)aString;
+ (OWContentType *)wildcardContentType;
+ (OWContentType *)sourceContentType;  // This is a pseudo content-type handled specially by pipelines. No actual content has this type.
+ (OWContentType *)retypedSourceContentType; // Targets can request this as an alternate content type (with a cost) to specify how willing they are to ignore the original content-type designation on source content
+ (OWContentType *)unknownContentType;
+ (OWContentType *)errorContentType;
+ (OWContentType *)nothingContentType;
+ (NSArray *)contentEncodings;
+ (NSArray *)contentTypes;
+ (void)setDefaultExpirationTimeInterval:(NSTimeInterval)newTimeInterval;
+ (void)updateExpirationTimeIntervalsFromDefaults;

+ (OWContentTypeLink *)linkForTargetContentType:(OWContentType *)targetContentType fromContentType:(OWContentType *)sourceContentType orContentTypes:(NSSet *)sourceTypes;

+ (void)registerFileExtension:(NSString *)extension forContentType:(OWContentType *)contentType;
+ (OWContentType *)contentTypeForExtension:(NSString *)extension;

+ (OWContentType *)contentTypeForFilename:(NSString *)filename isLocalFile:(BOOL)isLocalFile;
+ (OFMultiValueDictionary *)contentTypeAndEncodingForFilename:(NSString *)aFilename isLocalFile:(BOOL)isLocalFile;

- (void)setExtensions:(NSArray *)someExtensions;
- (NSArray *)extensions;
- (NSString *)primaryExtension;

- (void)setHFSType:(unsigned long)newHFSType;
- (unsigned long)hfsType;
- (void)setHFSCreator:(unsigned long)newHFSCreator;
- (unsigned long)hfsCreator;

- (void)setImageName:(NSString *)newImageName;
- (NSString *)imageName;

- (NSString *)contentTypeString;
- (NSString *)readableString;
- (BOOL)isEncoding;
    // Is this actually a Content-Encoding?
- (BOOL)isPublic;
    // Is this visible to the outside world?
- (BOOL)isInteresting;
    // Should we mention this type in our HTTP Accept headers?

// Aliases
- (void)registerAlias:(NSString *)newAlias;


// Links
- (void)linkToContentType:(OWContentType *)targetContentType usingProcessorDescription:(OWProcessorDescription *)aProcessorDescription cost:(float)aCost;
- (OWConversionPathElement *)bestPathForTargetContentType:(OWContentType *)targetType;
    // Returns the lowest total cost path from the receiving content type to the specified target content type, or nil if there is no possible path.
- (NSArray *)directTargetContentTypes;
    // Returns an array of OWContentTypeLinks, not OWContentTypes as the name might suggest.
- (NSSet *)directSourceContentTypes;
- (NSSet *)indirectSourceContentTypes;

// Content expiration
- (NSTimeInterval)expirationTimeInterval;
- (void)setExpirationTimeInterval:(NSTimeInterval)newTimeInterval;

// Filenames
- (NSString *)pathForEncodings:(NSArray /* of OWContentType */ *)contentEncodings givenOriginalPath:(NSString *)aPath;

@end

#import <OWF/FrameworkDefines.h>

OWF_EXTERN NSTimeInterval OWContentTypeNeverExpireTimeInterval;
OWF_EXTERN NSTimeInterval OWContentTypeExpireWhenFlushedTimeInterval;
OWF_EXTERN NSString *OWContentTypeNeverExpireString;
OWF_EXTERN NSString *OWContentTypeExpireWhenFlushedString;
OWF_EXTERN NSString *OWContentTypeReloadExpirationTimeIntervalsNotificationName;
