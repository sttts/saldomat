// Copyright 2003-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWFilteredAddressCache.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSException-OWConcreteCacheEntry.h"
#import "OWAddress.h"
#import "OWContent.h"
#import "OWContentCacheProtocols.h"
#import "OWContentType.h"
#import "OWProcessor.h"
#import "OWPipeline.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/OWFilteredAddressCache.m 68913 2005-10-03 19:36:19Z kc $");

@interface OWFilteredAddressArc : NSObject <OWCacheArc>
{
    OWContent *subject;
    NSDate *created;
}

- initWithSubject:(OWContent *)anEntry;

@end

@implementation OWFilteredAddressCache

- (NSArray *)allArcs;
{
    // TODO: Is this even possible to implement correctly?
    return [NSArray array];
}

- (NSArray *)arcsWithRelation:(OWCacheArcRelationship)aRelation toEntry:(OWContent *)anEntry inPipeline:(OWPipeline *)pipe
{
    OWFilteredAddressArc *arc;
    NSArray *result;
    
    if (![[pipe preferenceForKey:OWAddressFilteringEnabledDefaultName arc:nil] boolValue])
        return nil;
        
    if (anEntry == nil || !(aRelation & OWCacheArcSubject) ||
        ![anEntry isAddress] || ![(OWAddress *)[anEntry address] isFiltered])
        return nil;

    arc = [[OWFilteredAddressArc alloc] initWithSubject:anEntry];
    result = [NSArray arrayWithObject:arc];
    [arc release];

    return result;
}

- (float)cost
{
    return 0;
}

@end

@implementation OWFilteredAddressArc 

static OWContent *filteredAddressResult = nil;

+ (void)initialize
{
    OBINITIALIZE;

    NSString *filterMessage = NSLocalizedStringFromTableInBundle(@"This address has been filtered by your privacy settings", @"OWF", [OWFilteredAddressArc bundle], @"filtered address exception");
    NSException *filteredNotice = [[NSException alloc] initWithName:OWFilteredAddressErrorName reason:filterMessage userInfo:nil];
    filteredAddressResult = [[OWContent alloc] initWithContent:filteredNotice];
    [filteredAddressResult markEndOfHeaders];

    [filteredNotice release];
}

- initWithSubject:(OWContent *)anEntry
{
    [super init];

    subject = [anEntry retain];
    created = [[NSDate alloc] init];

    return self;
}

- (void)dealloc
{
    [subject release];
    [created release];
    [super dealloc];
}

- (NSArray *)entriesWithRelation:(OWCacheArcRelationship)relation
{
    NSMutableArray *result = [[NSMutableArray alloc] init];

    if (relation & OWCacheArcSubject)
        [result addObject:subject];
    if (relation & OWCacheArcObject)
        [result addObject:filteredAddressResult];

    return [result autorelease];
}

- (OWCacheArcType)arcType { return OWCacheArcDerivedContent; }
- (OWContent *)subject  { return subject; }
- (OWContent *)source   { return subject; }  // our source is the same as our subject
- (OWContent *)object   { return filteredAddressResult;  }
- (NSDate *)creationDate { return created; }

#if 0
- (OWCacheArcRelationship)relationsOfEntry:(OWContent *)anEntry intern:(OWContent **)interned
{
    if ([anEntry isEqual:subject]) {
        *interned = subject;
        return OWCacheArcSubject;
    }
    if ([anEntry isEqual:filteredAddressResult]) {
        *interned = filteredAddressResult;
        return OWCacheArcSubject;
    }
    return 0;
}
#endif

- (unsigned)invalidInPipeline:(OWPipeline *)context;
{
    // Allow overrides on a site-by-site basis
    BOOL filteringEnabled = [[context preferenceForKey:OWAddressFilteringEnabledDefaultName arc:self] boolValue];
    
    if (filteringEnabled)
        return 0;
    else
        return OWCacheArcInvalidContext;
}

- (OWCacheArcTraversalResult)traverseInPipeline:(OWPipeline *)context;
{
    return OWCacheArcTraversal_HaveResult;
}

- (OWContentType *)expectedResultType;
{
    return [OWContentType wildcardContentType];
}

- (float)expectedCost;
{
    return 0;
}

- (BOOL)abortArcTask;
{
    return NO;
}

- (NSDate *)firstBytesDate;
{
    return nil;
}

- (unsigned int)bytesProcessed;
{
    return 0;
}

- (unsigned int)totalBytes;
{
    return 0;
}

- (enum _OWProcessorStatus)status
{
    return OWProcessorRetired;
}

- (NSString *)statusString;
{
    return nil;
}

- (BOOL)resultIsSource   { return YES; }
- (BOOL)resultIsError    { return YES; }
- (BOOL)shouldNotBeCachedOnDisk { return YES; }

// Pseudo arcs never produce any events, so they don't need to keep track of observers
- (void)addArcObserver:(OWPipeline *)anObserver;
{
}

- (void)removeArcObserver:(OWPipeline *)anObserver;
{
}

@end
