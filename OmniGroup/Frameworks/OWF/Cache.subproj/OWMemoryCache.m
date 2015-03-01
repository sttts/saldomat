// Copyright 2003-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWMemoryCache.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "OWAddress.h"
#import "OWContent.h"
#import "OWContentCacheProtocols.h"
#import "OWContentCacheGroup.h"
#import "OWPipeline.h"
#import "OWStaticArc.h"
#import "OWURL.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Cache.subproj/OWMemoryCache.m 68913 2005-10-03 19:36:19Z kc $");

@interface OWMemoryCache (Private)

- (void)_scanArcsForSubject:(OWContent *)anEntry giving:(NSMutableArray *)arcsOut;
- (void)_scanArcsFor:(OWContent *)anEntry relation:(OWCacheArcRelationship)aRelation giving:(NSMutableArray *)arcsOut;

- (id)_keyForSubject:(OWContent *)subject;
- (void)_scheduleExpireBeforeDate:(NSDate *)deadline;
- (void)_expire;
- (void)_flushCache:(NSNotification *)note;
- (void)_purgeMarkedEntriesFromRows:(NSMutableSet *)rowsToPurge;
- (void)_lockedCancelCurrentExpireEvent;
- (void)_removeAllArcs;
- (void)_invalidateAllArcs;

@end

@interface OWMemoryCacheEntry : OFObject
{
@public
    OWStaticArc *arc;
    OWMemoryCacheEntry *next;
    NSTimeInterval lastUsed;
    NSTimeInterval reasonableLifetime;
    struct {
        unsigned int hasBeenOfferedToNextCache:1;
        unsigned int superseded:1;
        unsigned int shouldRemove:1;
        unsigned int hasValidator:1;
    } flags;
}

- initWithArc:(OWStaticArc *)anArc;
- (OWStaticArc *)arc;
- (void)touch;
- (void)invalidate;
- (void)substituteArc:(OWStaticArc *)anArc;

@end

@implementation OWMemoryCacheEntry

#define DEFAULT_DEFAULT_LIFETIME_A_DOO_WOP 60

- initWithArc:(OWStaticArc *)anArc;
{
    if ([super init] == nil)
        return nil;

    arc = [anArc retain];
    next = nil;
    lastUsed = [NSDate timeIntervalSinceReferenceDate];
    reasonableLifetime = DEFAULT_DEFAULT_LIFETIME_A_DOO_WOP;
    flags.hasBeenOfferedToNextCache = NO;
    flags.superseded = NO;
    flags.shouldRemove = NO;
    flags.hasValidator = [[anArc object] hasValidator];

    return self;
}

- (void)dealloc
{
    [arc release];
    [next release];
    [super dealloc];
}

- (OWStaticArc *)arc
{
    return arc;
}

- (void)touch;
{
    lastUsed = [NSDate timeIntervalSinceReferenceDate];
}

- (void)invalidate
{
    //NSString *m = [NSString stringWithFormat:@"invalidating %@", [arc shortDescription]];
    [arc invalidate];
    if (!flags.hasValidator) {
        //m = [NSString stringWithFormat:@"%@, shouldRemove %d->1", m, shouldRemove];
        flags.shouldRemove = YES;
    }
    //NSLog(@"%@: %@", [self shortDescription], m);
}

- (void)substituteArc:(OWStaticArc *)anArc;
{
    OWMemoryCacheEntry *newEntry;
    
    if (anArc == arc)
        return;

    newEntry = [[OWMemoryCacheEntry alloc] initWithArc:anArc];
    if (flags.superseded)
        newEntry->flags.superseded = YES;
    if (flags.hasBeenOfferedToNextCache)
        newEntry->flags.hasBeenOfferedToNextCache = YES;
    newEntry->lastUsed = lastUsed;

    newEntry->next = next;
    next = newEntry;

    flags.shouldRemove = YES;
}

@end

@implementation OWMemoryCache

// Init and dealloc
- init;
{
    NSZone *myZone;
    
    if ([super init] == nil)
        return nil;

    myZone = [self zone];
    lock = [[NSLock alloc] init];
    arcsBySubject = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFNSObjectDictionaryKeyCallbacks, &OFNSObjectDictionaryValueCallbacks);
    knownOtherContent = [[NSMutableSet allocWithZone:myZone] init];
    [OWContentCacheGroup addObserver:self];

    return self;
}

- (void)dealloc;
{
    [OWContentCacheGroup removeObserver:self];
    [arcsBySubject release];
    [knownOtherContent release];
    [lock release];
    [super dealloc];
}

// API

- (void)setResultCache:(id <OWCacheArcProvider, OWCacheContentProvider>)newBackingCache;
{
    [newBackingCache retain];
    [backingCache release];
    backingCache = newBackingCache;
}

- (id <OWCacheArcProvider>)resultCache;
{
    return backingCache;
}

- (void)setFlush:(BOOL)flushable;
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:OWContentCacheFlushNotification object:nil];
    if (flushable)
        [center addObserver:self selector:@selector(_flushCache:) name:OWContentCacheFlushNotification object:nil];
}

- (NSArray *)allArcs;
{
    [lock lock];
    NSArray *arcs = [[NSArray alloc] initWithArray:[[arcsBySubject allValues] arrayByPerformingSelector:@selector(arc)]];
    [lock unlock];
    
    return [arcs autorelease];
}

- (NSArray *)arcsWithRelation:(OWCacheArcRelationship)relation toEntry:(OWContent *)anEntry inPipeline:(OWPipeline *)pipe
{
    NSMutableArray *result;
    NSString *cacheControl;

    if (![anEntry isHashable])
        return nil;

    // minor optimization
    cacheControl = [pipe contextObjectForKey:OWCacheArcCacheBehaviorKey];
    if (cacheControl &&
        ([cacheControl isEqual:OWCacheArcReload] || [cacheControl isEqual:OWCacheArcRevalidate]))
        return nil;

    [lock lock];
    
    result = [[NSMutableArray alloc] init];
    if (relation & (~OWCacheArcSubject))
        [self _scanArcsFor:anEntry relation:relation giving:result];  // General case.
    else if (relation & OWCacheArcSubject)
        [self _scanArcsForSubject:anEntry giving:result];  // Most common case.

    if ([result count] > 0) {
        [result autorelease];
        [result makeObjectsPerformSelector:@selector(touch)];
        [result replaceObjectsInRange:(NSRange){0, [result count]} byApplyingSelector:@selector(arc)];
    } else {
        [result release];
        result = nil;
    }

    [lock unlock];

    [result reverse];
    
    return result;
}

- (float)cost
{
    return 0;
}

- (void)removeArcsWithRelation:(OWCacheArcRelationship)relation toEntry:(OWContent *)anEntry;
{
    [self _removeAllArcs];
}

- (id <OWCacheArc>)addArc:(OWStaticArc *)anArc
{
    OWMemoryCacheEntry *newEntry;
    OWMemoryCacheEntry *existingEntry;
    NSMutableArray *priorArcs;
    id cacheRow;

#ifdef DEBUG_kc0
    NSLog(@"-[%@ %s], anArc=%@", OBShortObjectDescription(self), _cmd, OBShortObjectDescription(anArc));
#endif
    [lock lock];
    
    //... validate cacheability? TODO


    // add arc to list
    newEntry = [[OWMemoryCacheEntry alloc] initWithArc:anArc];
    cacheRow = [self _keyForSubject:[anArc subject]];
    existingEntry = [arcsBySubject objectForKey:cacheRow];
    if (existingEntry != nil) {
        //... look for possibly duplicate/superseded arcs while walking to the end of the list
        priorArcs = [[NSMutableArray alloc] init];
        for(;;) {
            if (!(existingEntry->flags.shouldRemove) && !(existingEntry->flags.superseded))
                [priorArcs addObject:existingEntry];
            if (!(existingEntry->next)) {
                existingEntry->next = [newEntry retain];
                break;
            }
            existingEntry = existingEntry->next;
        }
    } else {
        // ... we don't have any entries for this subject yet.
        priorArcs = nil;
        CFDictionarySetValue((CFMutableDictionaryRef)arcsBySubject, cacheRow, newEntry);
        OBASSERT(newEntry->next == nil);
    }
    [newEntry touch];
    [newEntry release];

    [knownOtherContent addObject:[anArc object]];
    if ([anArc source] != nil)
        [knownOtherContent addObject:[anArc source]];

    [lock unlock];

    // Now check for duplicate/superseded arcs while the cache lock is not held. (We will need the global lock though.)
    if (priorArcs != nil && [priorArcs count] > 0) {
        unsigned arcIndex, arcCount;
        arcCount = [priorArcs count];
        [OWPipeline lock];

        for (arcIndex = arcCount; arcIndex > 0; arcIndex --) {
            OWMemoryCacheEntry *priorArcEntry = [priorArcs objectAtIndex:arcIndex - 1];
            if (![anArc dominatesArc:[priorArcEntry arc]]) {
                [priorArcs removeObjectAtIndex:arcIndex - 1];
            } else {
#ifdef DEBUG_wiml
                NSLog(@"%@ supersedes %@", [anArc shortDescription], [priorArcEntry->arc shortDescription]);
#endif
            }
        }

        [OWPipeline unlock];
        
        // Set the superseded flags.
        arcCount = [priorArcs count];
        if (arcCount > 0) {
            [lock lock];
            for (arcIndex = 0; arcIndex < arcCount; arcIndex++)
                ((OWMemoryCacheEntry *)[priorArcs objectAtIndex:arcIndex])->flags.superseded = YES;
            [lock unlock];
        }
    }
    [priorArcs release];
    
    // TODO: adjust expiration according to arc info, destination content type, and all sorts of extremely clever things like that. Hey, maybe lifetime should be an attribute of the arc.
    
    //... queue any expirations or move-to-next-layer events
    [self _scheduleExpireBeforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
    
    return anArc;
}

- (OWContent *)storeContent:(OWContent *)someContent;
{
    OWContent *existingContent;
    OWMemoryCacheEntry *existingEntry;
    
    //... validate cacheability
    if (someContent == nil || ![someContent isHashable])
        return nil;

    [lock lock];
    
    // search for equivalent content, return it
    
    existingEntry = [arcsBySubject objectForKey:[self _keyForSubject:someContent]];
    while (existingEntry != nil) {
        existingContent = [[existingEntry arc] subject];
        if ([someContent isEqual:existingContent]) {
            [existingContent retain];
            [lock unlock];
            return [existingContent autorelease];
        }
        existingEntry = existingEntry->next;
    }
        
    existingContent = [knownOtherContent member:someContent];
    if (existingContent != nil && existingContent != someContent) {
        [existingContent retain];
        [lock unlock];
#ifdef DEBUG_kc0
        NSLog(@"-[%@ %s]: Found equivalent existing content, returning it rather than the new content: %@",  OBShortObjectDescription(self), _cmd, someContent);
#endif
        return [existingContent autorelease];
    }
    
    [lock unlock];

    return someContent;
}

- (BOOL)canStoreContent:(OWContent *)someContent
{
    if ([someContent isHashable])
        return YES;
    else
        return NO;
}

- (BOOL)canStoreArc:(id <OWCacheArc>)anArc;
{
    NSArray *arcContent;
    int entIndex, entCount;

    arcContent = [anArc entriesWithRelation:OWCacheArcAnyRelation];
    entCount = [arcContent count];
    if (entCount == 0)
        return NO;
    for (entIndex = 0; entIndex < entCount; entIndex ++) {
        if (![self canStoreContent:[arcContent objectAtIndex:entIndex]])
            return NO;
    }
    
    return YES;
}


// We never give out any handles, so we'd better not be called with any.

- (void)adjustHandle:(id)aHandle reference:(int)referenceCountDelta;
{
    [NSException raise:NSInternalInconsistencyException format:@"cache handle %@ given to %@", [aHandle shortDescription], [self shortDescription]];
}

- (unsigned)contentHashForHandle:(id)aHandle;
{
    return 0;  // indicates we don't have a hash for this handle
}

- (id <OWConcreteCacheEntry>)contentForHandle:(id)aHandle;
{
    [NSException raise:NSInternalInconsistencyException format:@"cache handle %@ given to %@", [aHandle shortDescription], [self shortDescription]];
    return nil;
}

- (void)invalidateResource:(OWURL *)resource beforeDate:(NSDate *)invalidationDate;
{
    if (invalidationDate == nil)
        invalidationDate = [NSDate date];

    //NSLog(@"%@ invalidation note: %@", [self shortDescription], [noteInfo description]);

    [lock lock];

    BOOL scheduleExpiration = NO;

    OWMemoryCacheEntry *cursor = [arcsBySubject objectForKey:resource];
    while (cursor != nil) {
        OWStaticArc *anArc = cursor->arc;
        if ([invalidationDate compare:[anArc creationDate]] == NSOrderedDescending) {
            scheduleExpiration = YES;
            [cursor invalidate];
        }
        cursor = cursor->next;
    }

    [lock unlock];

    if (scheduleExpiration)
        [self _scheduleExpireBeforeDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
}

- (void)invalidateArc:(id <OWCacheArc>)anArc
{
    // We don't need to do anything, because we use the arcs directly.
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary = [super debugDictionary];

    if (arcsBySubject != nil)
        [debugDictionary setObject:arcsBySubject forKey:@"arcsBySubject"];
    if (knownOtherContent != nil)
        [debugDictionary setObject:knownOtherContent forKey:@"knownOtherContent"];
    if (backingCache != nil)
        [debugDictionary setObject:OBShortObjectDescription(backingCache) forKey:@"backingCache"];
    if (expireEvent != nil)
        [debugDictionary setObject:expireEvent forKey:@"expireEvent"];

    return debugDictionary;
}

@end

@implementation OWMemoryCache (Private)

- (void)_scanArcsForSubject:(OWContent *)anEntry giving:(NSMutableArray *)arcsOut
{
    OWMemoryCacheEntry *cacheLine;
    // Must be called with the cache lock held.

    cacheLine = [arcsBySubject objectForKey:[self _keyForSubject:anEntry]];

    while (cacheLine != nil) {
        if (!cacheLine->flags.shouldRemove && [[[cacheLine arc] subject] isEqual:anEntry])
            [arcsOut addObject:cacheLine];
        cacheLine = cacheLine->next;
    }
}

- (void)_scanArcsFor:(OWContent *)anEntry relation:(OWCacheArcRelationship)lookForRelationship giving:(NSMutableArray *)matchedArcs
{
    NSEnumerator *cacheRowEnumerator;
    OWMemoryCacheEntry *cacheEntry;

    // Must be called with the cache lock held.

    cacheRowEnumerator = [arcsBySubject objectEnumerator];
    cacheEntry = nil;

    for(;;) {
        if (cacheEntry != nil)
            cacheEntry = cacheEntry->next;
        if (cacheEntry == nil)
            cacheEntry = [cacheRowEnumerator nextObject];
        if (cacheEntry == nil)
            break;

        if (!cacheEntry->flags.shouldRemove) {
            OWCacheArcRelationship arcMatches = [cacheEntry->arc relationsOfEntry:anEntry intern:NULL];
            if (arcMatches & lookForRelationship) {
                [cacheEntry touch];
                [matchedArcs addObject:cacheEntry];
            }
        }
    }
}

- (id)_keyForSubject:(OWContent *)subject
{
    /* The idea here is to put all cache entries describing the same resource in the same cache row, so that we can easily deal with the interactions among them. (For example, a POST and a GET are different subject content, but they refer to the same resource.) */

    if ([subject isAddress])
        return [[[subject address] url] urlWithoutUsernamePasswordOrFragment];
    else
        return subject;
}

- (void)_flushCache:(NSNotification *)note
{
#ifdef DEBUG_kc0
    NSLog(@"-[%@ %s]", OBShortObjectDescription(self), _cmd);
#endif

    if ([OWContentCacheFlush_Remove isEqual:[[note userInfo] objectForKey:OWContentCacheInvalidateOrRemoveNotificationInfoKey]]) {
        [self _removeAllArcs];
    } else {
        [self _invalidateAllArcs];
    }
}

- (void)_scheduleExpireBeforeDate:(NSDate *)deadline;
{
    [lock lock];

    if (expireEvent != nil && [[expireEvent date] compare:deadline] == NSOrderedDescending) {
        [self _lockedCancelCurrentExpireEvent];
    }

    if (expireEvent == nil) {
        expireEvent = [[OFScheduledEvent alloc] initForObject:self selector:@selector(_expire) withObject:nil atDate:deadline];
        [[OWContentCacheGroup scheduler] scheduleEvent:expireEvent];
    }	

    [lock unlock];
}	

- (void)_expire;
{
    NSTimeInterval now, nextExpire;
    NSEnumerator *cacheRowEnumerator;
    NSMutableArray *entriesToOffer;
    NSMutableSet *shouldPurge;
    OWMemoryCacheEntry *entry;
    id thisRowKey;
    BOOL anExpire;
    unsigned arcIndex, arcsAccepted;

    [lock lock];

    [expireEvent release];
    expireEvent = nil;

    nextExpire = 60 * 60;
    anExpire = NO;
    arcsAccepted = 0;
    entriesToOffer = [[NSMutableArray alloc] init];
    shouldPurge = [NSMutableSet set];
    [knownOtherContent removeAllObjects];
    now = [NSDate timeIntervalSinceReferenceDate];

    cacheRowEnumerator = [arcsBySubject keyEnumerator];
    entry = nil;
    thisRowKey = nil;

    for(;;) {
        NSTimeInterval timeToLive;

        if (entry != nil)
            entry = entry->next;
        if (entry == nil) {
            thisRowKey = [cacheRowEnumerator nextObject];
            entry = [arcsBySubject objectForKey:thisRowKey];
        }
        if (entry == nil)
            break;

        // Ignore entries that have already been marked for deletion
        if (entry->flags.shouldRemove) {
            [shouldPurge addObject:thisRowKey];
            continue;
        }

        // Arcs that we should consider adding to the backing cache.
        if (backingCache != nil && !(entry->flags.hasBeenOfferedToNextCache) && !(entry->flags.superseded)) {
            entry->flags.hasBeenOfferedToNextCache = YES;
            [entriesToOffer addObject:entry];
        }

        // Arcs that haven't been used in a while.
        timeToLive = entry->reasonableLifetime - (now - entry->lastUsed);
        if (timeToLive < 0 || (entry->flags.superseded && !entry->flags.hasValidator)) {
            // I've ... seen things you ... people wouldn't believe. (etc, etc) Time... to die.  *flappity flappity flappity*
            // ?
            entry->flags.shouldRemove = YES;
            [shouldPurge addObject:thisRowKey];
        } else {
            nextExpire = MIN(nextExpire, timeToLive);
            anExpire = YES;
        }

        if (!entry->flags.shouldRemove) {
            [knownOtherContent addObject:[entry->arc object]];
            [knownOtherContent addObject:[entry->arc source]];
        }            
    }

    [lock unlock];

    [OWPipeline lock];
    for(arcIndex = 0; arcIndex < [entriesToOffer count]; arcIndex ++) {
        BOOL storable = [backingCache canStoreArc:[[entriesToOffer objectAtIndex:arcIndex] arc]];
        if (!storable) {
            [entriesToOffer removeObjectAtIndex:arcIndex];
            arcIndex --;
        }
    }
    [OWPipeline unlock];
    
    NS_DURING {
        // Without camping on the cache lock, offer any cacheable arcs to the next cache.
        for(arcIndex = 0; arcIndex < [entriesToOffer count]; arcIndex ++) {
            OWStaticArc *storedArc;

            entry = [entriesToOffer objectAtIndex:arcIndex];
            storedArc = (OWStaticArc *)[backingCache addArc:entry->arc];
            if (storedArc != nil) {
                arcsAccepted++;

                if (storedArc != entry->arc && [storedArc isKindOfClass:[OWStaticArc class]]) {
                    [lock lock];
                    [shouldPurge addObject:[entry->arc subject]];
                    [entry substituteArc:storedArc];
                    [lock unlock];
                }
            }
        }

    } NS_HANDLER {
#ifdef DEBUG    
        NSLog(@"%@ received exception %@ during expire", [self shortDescription], [localException description]);
#endif        
        // Just drop the exception on the floor.
        // TODO: Requeue entries not actually offered?
    } NS_ENDHANDLER;

#ifdef DEBUG_wiml
    if ([entriesToOffer count])
        NSLog(@"-[%@ %s] Offered %u arcs to %@, accepted %u", [self shortDescription], _cmd, [entriesToOffer count], [(id)backingCache shortDescription], arcsAccepted);
#endif

    [entriesToOffer release];

    // Schedule the next sweep.
    if (anExpire) {
        nextExpire = MAX(nextExpire, 3.0);
        [self _scheduleExpireBeforeDate:[NSDate dateWithTimeIntervalSinceNow:nextExpire]];
    }

#ifdef DEBUG_wiml
    NSLog(@"-[%@ %s] took %.3f seconds. Next run in %.1f seconds.", [self shortDescription], _cmd, ([NSDate timeIntervalSinceReferenceDate] - now), nextExpire);
#endif

    [self _purgeMarkedEntriesFromRows:shouldPurge];
}

- (void)_purgeMarkedEntriesFromRows:(NSMutableSet *)touchedRows;
{
#ifdef DEBUG_kc0
    NSLog(@"-[%@ %s], touchedRows=%@", OBShortObjectDescription(self), _cmd, touchedRows);
#endif

    unsigned rowsTouched, entriesRemoved, rowsEmptied;
    NSTimeInterval began;
    
    [lock lock];
    began = [NSDate timeIntervalSinceReferenceDate];

    rowsTouched = 0;
    rowsEmptied = 0;
    entriesRemoved = 0;

    while ([touchedRows count] > 0) {
        OWContent *purgeRow = [touchedRows anyObject];
        OWMemoryCacheEntry *cursor, *lastEntry;

        lastEntry = nil;
        cursor = [arcsBySubject objectForKey:purgeRow];
        rowsTouched++;
        while (cursor != nil) {

            if (cursor->flags.shouldRemove) {
                entriesRemoved++;
                
                if (lastEntry == nil) {
                    cursor = cursor->next;
                    if (cursor == nil) {
                        rowsEmptied++;
                        [arcsBySubject removeObjectForKey:purgeRow];
                    } else {
                        CFDictionarySetValue((CFMutableDictionaryRef)arcsBySubject, purgeRow, cursor);
                    }
                } else {
                    OBASSERT(lastEntry->next == cursor);
                    lastEntry->next = [cursor->next retain];
                    [cursor release];
                    cursor = lastEntry->next;
                }
            } else {
                lastEntry = cursor;
                cursor = cursor->next;
            }
            
        }

        [touchedRows removeObject:purgeRow];
    }

#if defined(DEBUG_wiml) || defined(DEBUG_kc0)
    NSLog(@"-[%@ %s] took %.3f seconds. Removed %u entries in %u rows, removing %u rows.", [self shortDescription], _cmd, ([NSDate timeIntervalSinceReferenceDate] - began), entriesRemoved, rowsTouched, rowsEmptied);
#endif
    
    [lock unlock];
}

- (void)_lockedCancelCurrentExpireEvent;
{
    if (expireEvent == nil)
        return;

    [[OWContentCacheGroup scheduler] abortEvent:expireEvent];
    [expireEvent release];
    expireEvent = nil;
}

- (void)_removeAllArcs;
{
    NSMutableDictionary *retainedArcsBySubject;
    NSMutableSet *retainedKnownOtherContent;

    [lock lock];
    
    [self _lockedCancelCurrentExpireEvent];

    // Clear out our instance variables inside the lock, but don't actually release their contents yet
    retainedArcsBySubject = arcsBySubject;
    retainedKnownOtherContent = knownOtherContent;
    arcsBySubject = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFNSObjectDictionaryKeyCallbacks, &OFNSObjectDictionaryValueCallbacks);
    knownOtherContent = [[NSMutableSet allocWithZone:[self zone]] init];
    [lock unlock];

    // OK, now release those former instance variables
    [retainedArcsBySubject release];
    [retainedKnownOtherContent release];
}

- (void)_invalidateAllArcs;
{
    NSMutableSet *purgeRows = [NSMutableSet set];
    [lock lock];

    NS_DURING {
        NSEnumerator *cacheRowEnumerator = [arcsBySubject keyEnumerator];
        id cacheRowKey;

        while ((cacheRowKey = [cacheRowEnumerator nextObject]) != nil) {
            OWMemoryCacheEntry *cacheRowCursor;

            for (cacheRowCursor = [arcsBySubject objectForKey:cacheRowKey];
                 cacheRowCursor != nil;
                 cacheRowCursor = cacheRowCursor->next) {

                if (cacheRowCursor->flags.hasBeenOfferedToNextCache) {
                    cacheRowCursor->flags.shouldRemove = YES;
                } else {
                    [cacheRowCursor invalidate];
                }

                [purgeRows addObject:cacheRowKey];
            }
        }
    } NS_HANDLER {
#ifdef DEBUG
        NSLog(@"%@: ignoring exception in %s: %@", [self shortDescription], _cmd, localException);
#endif
    } NS_ENDHANDLER;

    [lock unlock];

    [self _purgeMarkedEntriesFromRows:purgeRows];
}

@end
