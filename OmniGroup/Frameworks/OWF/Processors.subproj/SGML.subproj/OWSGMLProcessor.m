// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWSGMLProcessor.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSString-OWSGMLString.h"
#import "OWAbstractObjectStream.h"
#import "OWContentCacheProtocols.h"
#import "OWContentInfo.h"
#import "OWContentType.h"
#import "OWDocumentTitle.h"
#import "OWHeaderDictionary.h"
#import "OWObjectStreamCursor.h"
#import "OWPipeline.h"
#import "OWAddress.h"
#import "OWSGMLAppliedMethods.h"
#import "OWSGMLDTD.h"
#import "OWSGMLMethods.h"
#import "OWSGMLTag.h"
#import "OWSGMLTagType.h"
#import "OWURL.h"


RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/SGML.subproj/OWSGMLProcessor.m 90855 2007-09-06 19:29:13Z rachael $")

@interface OWSGMLProcessor (Private)
@end

@implementation OWSGMLProcessor

static NSMutableDictionary *sgmlMethodsDictionary = nil;
static NSUserDefaults *defaults = nil;
static BOOL debugSGMLProcessing = NO;

+ (void)initialize;
{
    static BOOL initialized = NO;
    OWSGMLMethods *classSGMLMethods;

    [super initialize];

    if (initialized) {
        OWSGMLMethods *superclassSGMLMethods;

        superclassSGMLMethods = [sgmlMethodsDictionary objectForKey:[(NSObject *)[self superclass] description]];
        classSGMLMethods = [[OWSGMLMethods alloc] initWithParent:superclassSGMLMethods];
    } else {
        initialized = YES;

        sgmlMethodsDictionary = [[NSMutableDictionary alloc] init];
        classSGMLMethods = [[OWSGMLMethods alloc] init];
        defaults = [NSUserDefaults standardUserDefaults];
    }
    [sgmlMethodsDictionary setObject:classSGMLMethods forKey:[(NSObject *)self description]];
    [classSGMLMethods release];
}

+ (OWSGMLMethods *)sgmlMethods;
{
    return [sgmlMethodsDictionary objectForKey:[(NSObject *)self description]];
}

+ (OWSGMLDTD *)dtd;
{
    return nil;
}

+ (void)setDebug:(BOOL)newDebugSetting;
{
    debugSGMLProcessing = newDebugSetting;
}

- initWithContent:(OWContent *)initialContent context:(id <OWProcessorContext>)aPipeline;
{
    OWAddress *pipelineAddress;
    OWSGMLDTD *dtd;
    unsigned int tagCount;

    if (![super initWithContent:initialContent context:aPipeline])
        return nil;

    pipelineAddress = [pipeline contextObjectForKey:OWCacheArcSourceAddressKey];
    if (!pipelineAddress)
        pipelineAddress = [pipeline contextObjectForKey:OWCacheArcHistoryAddressKey];

#warning TODO [wiml nov2003] - Verify that base addresses are still set properly

    [self setBaseAddress:pipelineAddress];
    // GRT: Disable this until I figure out what the problem is with it (it was to do away with any cached error title in case this document has no real title of its own)
    //[OWDocumentTitle cacheRealTitle:nil forAddress:baseAddress];

    dtd = [isa dtd];
    appliedMethods = [[OWSGMLAppliedMethods allocWithZone:[self zone]] initFromSGMLMethods:[isa sgmlMethods] dtd:dtd forTargetClass:isa];

    tagCount = [dtd tagCount];
    if (tagCount > 0) {
        openTags = NSZoneCalloc([self zone], tagCount,sizeof(unsigned int));
        implicitlyClosedTags = NSZoneCalloc([self zone], tagCount,sizeof(unsigned int));
    }
    return self;
}

- (void)dealloc;
{
    [appliedMethods release];
    [baseAddress release];
    if (openTags)
        NSZoneFree(NSZoneFromPointer(openTags), openTags);
    if (implicitlyClosedTags)
        NSZoneFree(NSZoneFromPointer(implicitlyClosedTags), implicitlyClosedTags);
    [undoers release];
    [super dealloc];
}

- (void)setBaseAddress:(OWAddress *)anAddress;
{
    if (baseAddress == anAddress)
	return;
    [anAddress retain];
    [baseAddress release];
    baseAddress = anAddress;
}

- (BOOL)hasOpenTagOfType:(OWSGMLTagType *)tagType;
{
    return [self _hasOpenTagOfTypeIndex:[tagType dtdIndex]];
}

- (void)openTagOfType:(OWSGMLTagType *)tagType;
{
    [self _openTagOfTypeIndex:[tagType dtdIndex]];
}

- (void)closeTagOfType:(OWSGMLTagType *)tagType;
{
    [self _closeTagAtIndexWasImplicit:[tagType dtdIndex]];
}

#define MINIMUM_RECURSION_HEADROOM 65536

size_t remainingStackSize(void)
{
#if !TARGET_CPU_PPC
#warning Do not know how stack grows on this platform
    // Since we only use this code to parse bookmarks & RSS feeds, and neither of those should nest very deeply, we decided we could cheat & always allow the recursion to continue on x86 processors.
    return MINIMUM_RECURSION_HEADROOM+1;
#endif
    char *low;
    char stack;
    
    // The stack grows negatively on PPC
    low = pthread_get_stackaddr_np(pthread_self()) - pthread_get_stacksize_np(pthread_self());
    return &stack - low;
}

- (void)processContentForTag:(OWSGMLTag *)tag;
{
    OWSGMLTagType *tagType;
    unsigned int tagIndex;
    id <OWSGMLToken> sgmlToken;

    // Require a certain amount of stack space before recursively processing tags so that deeply nested tags do not cause us to crash.
    if (remainingStackSize() < MINIMUM_RECURSION_HEADROOM)
        return;

    if (tag) {
	tagType = sgmlTagType(tag);
	tagIndex = [tagType dtdIndex];
	[self _openTagOfTypeIndex:tagIndex];
    } else {
	tagType = nil;
	tagIndex = NSNotFound;
    }

    while ((sgmlToken = [objectCursor readObject])) {
        switch ([sgmlToken tokenType]) {
            case OWSGMLTokenTypeStartTag:
                [self processTag:(id)sgmlToken];
                break;
            case OWSGMLTokenTypeCData:
                [self processCData:(id)sgmlToken];
                break;
            case OWSGMLTokenTypeEndTag: {
                OWSGMLTagType *closeTagType;
                
                closeTagType = sgmlTagType((OWSGMLTag *)sgmlToken);
                if (closeTagType == tagType) { // matching end tag?
                    if ([self _closeTagAtIndexWasImplicit:tagIndex])
                        break; // Nope, turns out we just implicitly closed this tag, so it's not our matching end tag
                    else
                        return; // Yup, this is our end tag, let's bail
                } else if (![self processEndTag:(id)sgmlToken] // end tag method not registered
                           && tag // We're not at the top level
                           && [self _hasOpenTagOfTypeIndex:[closeTagType dtdIndex]]) { // matching open tag before
                    [objectCursor ungetObject:sgmlToken];
                    [self _implicitlyCloseTagAtIndex:tagIndex];
                    return;
                }
                break;
            }
            default:
                break;
        }
    }
    
    if (tag)
        [self _closeTagAtIndexWasImplicit:tagIndex];
}

- (void)processUnknownTag:(OWSGMLTag *)tag;
{
    // We used to process the content for unknown tags, but this can lead to incredibly deep recursion if you're using a processor (such as our image map processor) which hasn't registered a method to handle, say, <img> tags (which don't have a matching close tag).  This caused crashes on pages like http://www.seatimes.com/classified/rent/b_docs/capts.html where we'd run out out of stack space.
}

- (void)processIgnoredContentsTag:(OWSGMLTag *)tag;
{
    id <OWSGMLToken> sgmlToken;
    OWSGMLTagType *tagType;

    tagType = sgmlTagType(tag);
    while ((sgmlToken = [objectCursor readObject])) {
        switch ([sgmlToken tokenType]) {
            case OWSGMLTokenTypeEndTag:
                if (sgmlTagType((OWSGMLTag *)sgmlToken) == tagType)
                    return;
            default:
                break;
        }
    }
}

- (void)processTag:(OWSGMLTag *)tag;
{
    // Call registered method to handle this tag
    sgmlAppliedMethodsInvokeTag(appliedMethods, tagTypeDtdIndex(sgmlTagType(tag)), self, tag);
}


- (BOOL)processEndTag:(OWSGMLTag *)tag;
{
    return sgmlAppliedMethodsInvokeEndTag(appliedMethods, tagTypeDtdIndex(sgmlTagType(tag)), self, tag);
}

- (void)processCData:(NSString *)cData;
{
}

- (void)process;
{
    [self processContentForTag:nil];
}

- (OWAddress *)baseAddress;
{
    return baseAddress;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (baseAddress)
	[debugDictionary setObject:baseAddress forKey:@"baseAddress"];

    return debugDictionary;
}

@end


@implementation OWSGMLProcessor (Tags)

static OWSGMLTagType *anchorTagType;
static OWSGMLTagType *baseTagType;
static OWSGMLTagType *bodyTagType;
static OWSGMLTagType *headTagType;
static OWSGMLTagType *htmlTagType;
static OWSGMLTagType *metaTagType;
static OWSGMLTagType *titleTagType;
static OWSGMLTagType *styleTagType;

static unsigned int anchorEffectAttributeIndex;
static unsigned int anchorHrefAttributeIndex;
static unsigned int anchorTargetAttributeIndex;
static unsigned int anchorTitleAttributeIndex;
static unsigned int baseHrefAttributeIndex;
static unsigned int baseTargetAttributeIndex;
static unsigned int metaNameAttributeIndex;
static unsigned int metaContentAttributeIndex;
static unsigned int metaHTTPEquivAttributeIndex;
static unsigned int metaCharSetAttributeIndex;

+ (void)didLoad;
{
    OWSGMLMethods *methods;
    OWSGMLDTD *dtd;

    // NOTE:
    //
    // You CANNOT add any tags here which aren't also applicable to frameset pages, because the SGMLFrameRecognizer subclass depends on any non-frame tags being unrecognized in its superclass (us) so it can switch the document to HTML.

    dtd = [self dtd];

    anchorTagType = [dtd tagTypeNamed:@"a"];
    baseTagType = [dtd tagTypeNamed:@"base"];
    bodyTagType = [dtd tagTypeNamed:@"body"];
    headTagType = [dtd tagTypeNamed:@"head"];
    htmlTagType = [dtd tagTypeNamed:@"html"];
    metaTagType = [dtd tagTypeNamed:@"meta"];
    titleTagType = [dtd tagTypeNamed:@"title"];
    styleTagType = [dtd tagTypeNamed:@"style"];
    [styleTagType setContentHandling:OWSGMLTagContentHandlingNonSGML];

    anchorHrefAttributeIndex = [anchorTagType addAttributeNamed:@"href"];
    anchorTargetAttributeIndex = [anchorTagType addAttributeNamed:@"target"];
    anchorEffectAttributeIndex = [anchorTagType addAttributeNamed:@"effect"];
    anchorTitleAttributeIndex = [anchorTagType addAttributeNamed:@"title"];

    baseHrefAttributeIndex = [baseTagType addAttributeNamed:@"href"];
    baseTargetAttributeIndex = [baseTagType addAttributeNamed:@"target"];

    metaNameAttributeIndex = [metaTagType addAttributeNamed:@"name"];
    metaContentAttributeIndex = [metaTagType addAttributeNamed:@"content"];
    metaHTTPEquivAttributeIndex = [metaTagType addAttributeNamed:@"http-equiv"];
    metaCharSetAttributeIndex = [metaTagType addAttributeNamed:@"charset"];

    methods = [self sgmlMethods];

    [methods registerMethod:@"Meaningless" forTagName:@"html"];
    [methods registerMethod:@"Meaningless" forTagName:@"head"];
    [methods registerMethod:@"Base" forTagName:@"base"];
    [methods registerMethod:@"Meta" forTagName:@"meta"];
    [methods registerMethod:@"Title" forTagName:@"title"];
    [methods registerMethod:@"Style" forTagName:@"style"];
}

- (OWAddress *)addressForAnchorTag:(OWSGMLTag *)anchorTag;
{
    NSString *href, *title, *target;
    OWAddress *address;

    href = sgmlTagValueForAttributeAtIndex(anchorTag, anchorHrefAttributeIndex);

    if (!href)
	return nil;

    target = sgmlTagValueForAttributeAtIndex(anchorTag, anchorTargetAttributeIndex);
    if (!target)
	target = [baseAddress target];
	
    address = [baseAddress addressForRelativeString:href inProcessorContext:pipeline target:target effect:[OWAddress effectForString:sgmlTagValueForAttributeAtIndex(anchorTag, anchorEffectAttributeIndex)]];

    title = sgmlTagValueForAttributeAtIndex(anchorTag, anchorTitleAttributeIndex);
    if (title && [title length] > 0) {
	// We now have a guess as to what this document's title is
	[OWDocumentTitle cacheGuessTitle:title forAddress:address];
    }

    return address;
}

- (void)processMeaninglessTag:(OWSGMLTag *)tag;
{
}

- (void)processBaseTag:(OWSGMLTag *)tag;
{
    NSString *href, *target;
    OWAddress *address;

    href = sgmlTagValueForAttributeAtIndex(tag, baseHrefAttributeIndex);
    target = sgmlTagValueForAttributeAtIndex(tag, baseTargetAttributeIndex);

    if (href) {
	address = [OWAddress addressWithURL:[OWURL urlFromString:href] target:target effect:OWAddressEffectFollowInWindow];
    } else if (target) {
	address = [baseAddress addressWithTarget:target];
    } else
	return;
    if (address)
        [self setBaseAddress:address];
}

- (void)processMetaTag:(OWSGMLTag *)tag;
{
    NSString *httpEquivalentHeaderKey;

    httpEquivalentHeaderKey = sgmlTagValueForAttributeAtIndex(tag, metaHTTPEquivAttributeIndex);
    if (httpEquivalentHeaderKey) {
        NSString *headerValue;

        headerValue = sgmlTagValueForAttributeAtIndex(tag, metaContentAttributeIndex);
        if (headerValue)
            [self processHTTPEquivalent:httpEquivalentHeaderKey value:headerValue];
        // Note that the <meta> tag could have just specified a new string encoding or content type. Rght now changes in the string encoding are handled by the ugly hack in OWHTMLToSGMLObjects; other changes are not handled at all unless by subclasses (or the target, indirectly through subclasses).
    }
}

- (void)processHTTPEquivalent:(NSString *)header value:(NSString *)value;
{
    /* Overridden by subclasses, if they care */
    /* Many subclasses will want to add any <META> headers to their destination OWContent's metadata */
}

- (void)processTitleTag:(OWSGMLTag *)tag;
{
    id <OWSGMLToken> sgmlToken;
    NSMutableString *titleString;
    OWSGMLTagType *tagType;

    titleString = [NSMutableString stringWithCapacity:128];
    while ((sgmlToken = [objectCursor readObject])) {
        switch ([sgmlToken tokenType]) {
            case OWSGMLTokenTypeCData:
                [titleString appendString:[sgmlToken string]];
                break;
            case OWSGMLTokenTypeEndTag:
                tagType = [(OWSGMLTag *)sgmlToken tagType];
                if (tagType == titleTagType || tagType == headTagType)
                    goto exitAndCacheTitle;
            case OWSGMLTokenTypeStartTag:
                tagType = [(OWSGMLTag *)sgmlToken tagType];
                if (tagType == bodyTagType)
                    goto exitAndCacheTitle;
            default:
#ifdef DEBUG
                NSLog(@"HTML: Ignoring %@ within %@", sgmlToken, tag);
#endif
                break;
        }
    }

exitAndCacheTitle:
    [OWDocumentTitle cacheRealTitle:[titleString stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace] forAddress:baseAddress];
}

- (void)processStyleTag:(OWSGMLTag *)tag;
{
    id <OWSGMLToken> sgmlToken;
    
    while ((sgmlToken = [objectCursor readObject])) {
        switch ([sgmlToken tokenType]) {
            case OWSGMLTokenTypeCData:
                break;
            case OWSGMLTokenTypeEndTag:
                // This pretty much has to be an </STYLE> tag, because style is marked as non-SGML
                OBASSERT([(OWSGMLTag *)sgmlToken tagType] == [tag tagType]);
                return; // We no longer process style sheets in OWF, WebCore does that instead
            default:
#ifdef DEBUG
                NSLog(@"HTML: Ignoring %@ within %@", sgmlToken, tag);
#endif
                break;
        }
    }
}

@end

@implementation OWSGMLProcessor (SubclassesOnly)

- (BOOL)_hasOpenTagOfTypeIndex:(unsigned int)tagIndex;
{
    return openTags[tagIndex] > 0;
}

- (void)_openTagOfTypeIndex:(unsigned int)tagIndex;
{
    openTags[tagIndex]++;
    implicitlyClosedTags[tagIndex] = 0;
}

- (void)_implicitlyCloseTagAtIndex:(unsigned int)tagIndex;
{
    implicitlyClosedTags[tagIndex]++;
    openTags[tagIndex]--;
}

- (BOOL)_closeTagAtIndexWasImplicit:(unsigned int)tagIndex;
{
    BOOL result;
    
    if ((result = implicitlyClosedTags[tagIndex] > 0))    
        implicitlyClosedTags[tagIndex]--;
    else if (openTags[tagIndex] > 0)
        openTags[tagIndex]--;
    return result;
}

@end

@implementation OWSGMLProcessor (Private)
@end
