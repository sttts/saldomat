// Copyright 2004-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWCacheSearch.h"

#import <Foundation/Foundation.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniBase/rcsid.h>
#import "OWContent.h"
#import "OWContentType.h"
#import "OWPipeline.h"

#ifdef DEBUG_kc
#import "OWAddress.h"
#endif

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Cache.subproj/OWCacheSearch.m 66176 2005-07-28 17:48:26Z kc $");

@interface OWCacheSearch (Private)

static NSComparisonResult compareByCacheCost(OFHeap *heap, void *userInfo, id a, id b);
static NSComparisonResult compareByCostAndDate(OFHeap *heap, void *userInfo, id a, id b);

- (void)_queryOneCache;

@end

@implementation OWCacheSearch

// Init and dealloc

- initForRelation:(OWCacheArcRelationship)aRelation toEntry:(OWContent *)anEntry inPipeline:(OWPipeline *)context;
{
    if ([super init] == nil)
        return nil;

    searchRelation = aRelation;
    sourceEntry = [anEntry retain];
#ifdef DEBUG_kc
    if ([sourceEntry isAddress] && [[[sourceEntry address] addressString] isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"OWPipelineDebugAddress"]])
        flags.debug = YES;
#endif
    weaklyRetainedPipeline = [context weakRetain];

    cachesToSearch = [[OFHeap alloc] initWithCapacity:0 compareFunction:compareByCacheCost userInfo:nil];
    arcsToConsider = [[OFHeap alloc] initWithCapacity:0 compareFunction:compareByCostAndDate userInfo:self];

    rejectedArcs = nil;
    unacceptableCost = FLT_MAX;

    return self;
}

- (void)dealloc;
{
    [sourceEntry release];
    [weaklyRetainedPipeline weakRelease];
    [cachesToSearch release];
    [arcsToConsider release];
    [rejectedArcs release];
    [freeArcs release];
    [super dealloc];
}

// API
- (void)addCaches:(NSArray *)someCaches;
{
    OFForEachInArray(someCaches, id <OWCacheArcProvider>, aCache, [cachesToSearch addObject:aCache]);
}

- (void)addFreeArcs:(NSArray *)someArcs;
{
    if (!freeArcs)
        freeArcs = [[NSMutableSet alloc] init];
    [freeArcs addObjectsFromArray:someArcs];
    OFForEachInArray(someArcs, id <OWCacheArc>, anArc, [arcsToConsider addObject:anArc]);
}

- (void)setRejectedArcs:(NSSet *)someArcs
{
    if (rejectedArcs)
        [rejectedArcs release];
    rejectedArcs = [someArcs mutableCopy];
}

- (void)rejectArc:(id <OWCacheArc>)anArc
{
    if (rejectedArcs == nil)
        rejectedArcs = [[NSMutableSet alloc] init];
    [rejectedArcs addObject:anArc];
}

- (void)setCostLimit:(float)newLimit
{
    unacceptableCost = newLimit;
}

- (OWContent *)source
{
    return sourceEntry;
}

// The real work is done by this method.
- (id <OWCacheArc>)nextArcWithoutBlocking;
{
    ASSERT_OWPipeline_Locked(); // -estimateCostForArc: still requires the global lock.

#ifdef DEBUG_kc
    if (flags.debug)
        NSLog(@"-[%@ %s]: cachesToSearch=%@ arcsToConsider=%@", OBShortObjectDescription(self), _cmd, [cachesToSearch description], [arcsToConsider description]);
#endif
    while ([cachesToSearch count] > 0 || [arcsToConsider count] > 0) {
        id <OWCacheArcProvider> aCache;
        id <OWCacheArc> anArc;
        float arcCostEstimate;

        aCache = [cachesToSearch peekObject];
        anArc = [arcsToConsider peekObject];
        arcCostEstimate = anArc != nil ? [self estimateCostForArc:anArc] : FLT_MAX;

#ifdef DEBUG_kc
        if (flags.debug)
            NSLog(@"-[%@ %s]: considering arc %@", OBShortObjectDescription(self), _cmd, anArc);
#endif

        if (aCache == nil || ( anArc != nil && ([aCache cost] > arcCostEstimate) )) {
            anArc = [arcsToConsider removeObject];
            OBASSERT(anArc != nil); // guaranteed by counts > 0 and previous conditional

            // Give up if we're down to the dregs.
            if (arcCostEstimate >= unacceptableCost)
                break;

#ifdef DEBUG_kc
            if (flags.debug)
                NSLog(@"-[%@ %s]: returning an arc: %@", OBShortObjectDescription(self), _cmd, anArc);
#endif
            return anArc;
        } else if ([aCache cost] <= 0.0) {
            [self _queryOneCache];
        } else {
#ifdef DEBUG_kc
            if (flags.debug)
                NSLog(@"-[%@ %s]: returning nil rather than blocking", OBShortObjectDescription(self), _cmd);
#endif
            return nil; // We would block, so return nil.
        }
    }

    // We've failed to find an arc. All die, O the embarrassment!
#ifdef DEBUG_kc
    if (flags.debug)
        NSLog(@"-[%@ %s]: failed to find an arc", OBShortObjectDescription(self), _cmd);
#endif
    return nil;
}

- (BOOL)endOfData;
{
    return ([cachesToSearch count] == 0) && ([arcsToConsider count] == 0);
}

- (void)waitForAvailability;
{
    for(;;) {
        id <OWCacheArcProvider> nextCache = [cachesToSearch peekObject];
        id <OWCacheArc> nextArc;
        float nextArcCostEstimate;

        // If we don't have another cache, then we won't be blocking on it.
        if (nextCache == nil)
            return;

        [OWPipeline lock];
        nextArc = [arcsToConsider peekObject];
        nextArcCostEstimate = ( nextArc != nil ) ? [self estimateCostForArc:nextArc] : 0;
        [OWPipeline unlock];

        // If we have an arc that we'll return before we look at the next cache, then we don't need to worry about that cache.
        if (nextArc != nil && ([nextCache cost] > nextArcCostEstimate))
            return;

        // Otherwise, we have a possibly-blocking cache at the head of our queue.
        // Query it and see how that affects the situation.
        [self _queryOneCache];
    }
}

- (float)estimateCostForArc:(id <OWCacheArc>)anArc;
{
    float followonCost, arcCost;
    NSNumber *anEstimate;
    OWContentType *destType;

    ASSERT_OWPipeline_Locked();
    // The inquiries we make of the arcs sometimes require the global lock to be held. TODO: Eliminate those cases, so that we can eliminate this assertion, and eliminate the lock/unlock in -checkForAvailability:.

    destType = [anArc expectedResultType];
    if (destType == nil)
        destType = [OWContentType wildcardContentType];
    anEstimate = [weaklyRetainedPipeline estimateCostFromType:destType];
#ifdef DEBUG_kc
    if (flags.debug)
        NSLog(@"-[%@ %s%@]: estimateCostFromType:%@ = %@", OBShortObjectDescription(self), _cmd, OBShortObjectDescription(anArc), [destType contentTypeString], anEstimate);
#endif

    followonCost = anEstimate != nil ? [anEstimate floatValue] : unacceptableCost;

    if ([anArc resultIsSource]) {
        anEstimate = [weaklyRetainedPipeline estimateCostFromType:[OWContentType sourceContentType]];
#ifdef DEBUG_kc
        if (flags.debug)
            NSLog(@"-[%@ %s%@]: estimateCostFromType:%@ = %@", OBShortObjectDescription(self), _cmd, OBShortObjectDescription(anArc), [[OWContentType sourceContentType] contentTypeString], anEstimate);
#endif
        if (anEstimate)
            followonCost = MIN(followonCost, [anEstimate floatValue]);
    }

    if ([freeArcs containsObject:anArc])
        arcCost = 0.0;
    else
        arcCost = [anArc expectedCost];

#ifdef DEBUG_kc
    if (flags.debug)
        NSLog(@"-[%@ %s%@]: total cost is %f = arcCost %f + COST_PER_LINK %f + followonCost %f", OBShortObjectDescription(self), _cmd, OBShortObjectDescription(anArc), arcCost + COST_PER_LINK + followonCost, arcCost, COST_PER_LINK, followonCost);
#endif

    return arcCost + COST_PER_LINK + followonCost;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary = [super debugDictionary];

    [debugDictionary setObject:sourceEntry forKey:@"sourceEntry" defaultObject:nil];
    [debugDictionary setIntValue:searchRelation forKey:@"searchRelation"];
    [debugDictionary setObject:weaklyRetainedPipeline forKey:@"weaklyRetainedPipeline" defaultObject:nil];
    [debugDictionary setFloatValue:unacceptableCost forKey:@"unacceptableCost"];
    [debugDictionary setObject:cachesToSearch forKey:@"cachesToSearch" defaultObject:nil];
    [debugDictionary setObject:arcsToConsider forKey:@"arcsToConsider" defaultObject:nil];
    [debugDictionary setObject:rejectedArcs forKey:@"rejectedArcs" defaultObject:nil];
    [debugDictionary setObject:freeArcs forKey:@"freeArcs" defaultObject:nil];

    return debugDictionary;
}

@end

@implementation OWCacheSearch (Private)

static NSComparisonResult compareByCacheCost(OFHeap *heap, void *userInfo, id a, id b)
{
    id <OWCacheArcProvider> cacheA = a, cacheB = b;
    float costA, costB;

    costA = [cacheA cost];
    costB = [cacheB cost];

    if (costA < costB)
        return NSOrderedAscending;
    if (costA == costB)
        return NSOrderedSame;
    return NSOrderedDescending;
}

static inline NSComparisonResult compareByCost(OFHeap *heap, void *userInfo, id a, id b)
{
    OWCacheSearch *costEstimator = userInfo;
    id <OWCacheArc> arcA = a, arcB = b;
    float costA, costB;

    costA = [costEstimator estimateCostForArc:arcA];
    costB = [costEstimator estimateCostForArc:arcB];

    if (costA < costB)
        return NSOrderedAscending;
    if (costA == costB)
        return NSOrderedSame;
    return NSOrderedDescending;
}

static NSComparisonResult compareByCostAndDate(OFHeap *heap, void *userInfo, id a, id b)
{
    NSComparisonResult result = compareByCost(heap, userInfo, a, b);

    if (result == NSOrderedSame) {
        id <OWCacheArc> arcA = a, arcB = b;
        NSDate *dateA = [arcA creationDate], *dateB = [arcB creationDate];

        if (dateA && dateB) {
            // This -compare: is reversed because we want to sort smaller costs to the front, but also later dates
            result = [dateB compare:dateA];
        } else {
            // In order to avoid inconsistent results from the sort function, we need to be able to decide how to order two arcs if one doesn't have a date but the other does. For now we'll arbitrarily sort dateless arcs as if they were old.
            if (dateA)
                return NSOrderedAscending; // Arc A has a date, but arc B doesn't
            if (dateB)
                return NSOrderedDescending; // Arc B has a date, but arc A doesn't
        }
    }

    return result;
}

- (void)_queryOneCache
{
    id <OWCacheArcProvider> aCache;
    NSArray *cacheArcs;

    aCache = [cachesToSearch removeObject];
    //            if (OWPipelineDebug || flags.debug)
    //                NSLog(@"%@ querying cache %@", OBShortObjectDescription(self), [(OFObject *)aCache shortDescription]);

    cacheArcs = [aCache arcsWithRelation:searchRelation toEntry:sourceEntry inPipeline:weaklyRetainedPipeline];

#ifdef DEBUG_kc
    if (flags.debug)
        NSLog(@"-[%@ %s]: %@ --> %@", OBShortObjectDescription(self), _cmd, OBShortObjectDescription(aCache), [cacheArcs description]);
#endif

    [OWPipeline lock];

    OFForEachInArray(cacheArcs, id <OWCacheArc>, anArc,
                     {
                         if (![rejectedArcs containsObject:anArc])
                             [arcsToConsider addObject:anArc];
#ifdef DEBUG_kc0
                         else
                             NSLog(@"-[%@ %s]: arc %@ matched rejected arc %@", OBShortObjectDescription(self), _cmd, anArc, [rejectedArcs member:anArc]);
#endif
                     });

    [OWPipeline unlock];
    
#ifdef DEBUG_kc
    if (flags.debug)
        NSLog(@"-[%@ %s]: arcsToConsider=%@, rejectedArcs=%@", OBShortObjectDescription(self), _cmd, [arcsToConsider description], [rejectedArcs description]);
#endif
}

@end
