// Copyright 2003-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OIInspectionSet.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectionSet.m 95981 2007-12-13 05:01:30Z bungi $");

@implementation OIInspectionSet

// Init and dealloc

- init;
{
    if (!(self = [super init]))
        return nil;

    // We want pointer equality, not content equality (particularly for OSStyle)
    objects = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                        &OFPointerEqualObjectDictionaryKeyCallbacks,
                                        &OFIntegerDictionaryValueCallbacks);
    insertionSequence = 0;
    
    return self;
}

- (void)dealloc;
{
    CFRelease(objects);
    [super dealloc];
}

//
// API
//

- (void)addObject:(id)object;
{
    OBASSERT(object != nil);
    CFDictionaryAddValue(objects, object, (const void *)(++insertionSequence));
}

- (void)addObjectsFromArray:(NSArray *)someObjects;
{
    OFForEachInArray(someObjects, id, anObject, CFDictionaryAddValue(objects, anObject, (const void *)(++insertionSequence)));
}

- (void)removeObject:(id)object;
{
    CFDictionaryRemoveValue(objects, (const void *)object);
    if (CFDictionaryGetCount(objects) == 0)
        insertionSequence = 0;
}

- (BOOL)containsObject:(id)object;
{
    return CFDictionaryContainsKey(objects, object)? YES : NO;
}

- (NSArray *)allObjects;
{
    return [(NSDictionary *)objects allKeys];
}

- (unsigned int)count;
{
    return CFDictionaryGetCount(objects);
}

static NSComparisonResult _comparePointers(id obj1, id obj2, void *context)
{
    if (obj1 > obj2)
	return NSOrderedDescending;
    else if (obj1 < obj2)
	return NSOrderedAscending;
    return NSOrderedSame;
}

typedef struct {
    NSPredicate *predicate;
    NSMutableArray *results;
} addIfMatchesPredicateContext;

static void _addIfMatchesPredicate(const void *value, const void *sequence, void *context)
{
    addIfMatchesPredicateContext *ctx = context;
    id object = (id)value;

    
    if ([ctx->predicate evaluateWithObject:object]) {
	if (!ctx->results)
	    ctx->results = [[NSMutableArray alloc] init];
	[ctx->results addObject:object];
    }
}

- (NSArray *)copyObjectsSatisfyingPredicate:(NSPredicate *)predicate;
{
    OBPRECONDITION(predicate);
    
    addIfMatchesPredicateContext ctx;
    ctx.predicate = predicate;
    ctx.results = nil;

    CFDictionaryApplyFunction(objects, _addIfMatchesPredicate, &ctx);
    
    // Return an array sorted by pointer so that we can easily do an 'is identical' comparison
    [ctx.results sortUsingFunction:_comparePointers context:NULL];
    
    return ctx.results;
}

- (void)removeObjectsSatisfyingPredicate:(NSPredicate *)predicate;
{
    // Can't modify a set we are enumerating, so collect objects to remove up front.
    NSArray *toRemove = [self copyObjectsSatisfyingPredicate:predicate];
    [self removeObjectsInArray:toRemove];
    [toRemove release];
}

struct addIfMatchesPredicateFunctionContext {
    OIInspectionSetPredicateFunction predicate;
    void *subcontext;
    NSMutableArray *results;
};

static void addIfMatchesPredicateFunction(const void *value, const void *sequence, void *context)
{
    struct addIfMatchesPredicateFunctionContext *ctx = context;
    id object = (id)value;
    
    if (ctx->predicate(object, ctx->subcontext)) {
	if (!ctx->results)
	    ctx->results = [[NSMutableArray alloc] init];
        // Return an array sorted by pointer so that we can easily do an 'is identical' comparison
	[ctx->results insertObject:object inArraySortedUsingFunction:_comparePointers context:NULL];
    }
}

- (NSArray *)copyObjectsSatisfyingPredicateFunction:(OIInspectionSetPredicateFunction)predicate context:(void *)context;
{
    OBPRECONDITION(predicate);
    
    struct addIfMatchesPredicateFunctionContext ctx;
    ctx.predicate = predicate;
    ctx.subcontext = context;
    ctx.results = nil;
    
    CFDictionaryApplyFunction(objects, addIfMatchesPredicateFunction, &ctx);
    
    OBASSERT(ctx.results == nil || [ctx.results isSortedUsingFunction:_comparePointers context:NULL]);
    
    return ctx.results;
}

- (void)removeObjectsInArray:(NSArray *)toRemove;
{
    unsigned int objectIndex = [toRemove count];
    while (objectIndex--)
        [self removeObject:[toRemove objectAtIndex:objectIndex]];
}

static NSComparisonResult compareSequence(id obj1, id obj2, void *context)
{
    Boolean exists1, exists2;
    const void *seq1v, *seq2v;
    
    exists1 = CFDictionaryGetValueIfPresent((CFDictionaryRef)context, obj1, &seq1v);
    exists2 = CFDictionaryGetValueIfPresent((CFDictionaryRef)context, obj2, &seq2v);
    
    if (exists1 && exists2) {
        unsigned int seq1 = (unsigned int)seq1v, seq2 = (unsigned int)seq2v;
        
        if (seq1 > seq2)
            return NSOrderedDescending;
        else if (seq1 < seq2)
            return NSOrderedAscending;
        return NSOrderedSame;
    }
    
    // Objects not in the sequence at all get sorted to the end, in no particular order.
    if (exists1 && !exists2)
        return NSOrderedAscending;
    if (exists2 && !exists1)
        return NSOrderedDescending;
    return NSOrderedSame;
}

- (NSArray *)objectsSortedByInsertionOrder:(NSArray *)someObjects;
{
    return [someObjects sortedArrayUsingFunction:compareSequence context:(void *)objects];
}

- (unsigned int)insertionOrderForObject:(id)object;
{
    unsigned int order = NSNotFound;
    Boolean exists = CFDictionaryGetValueIfPresent(objects, object, (void *)&order);
    if (!exists)
        return NSNotFound;
    return order;
}

//
// Debugging
//
static void describeEnt(const void *k, const void *v, void *d)
{
    [(NSMutableDictionary *)d setObject:[NSNumber numberWithUnsignedInt:(unsigned int)v] forKey:OBShortObjectDescription((id)k)];
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict = [super debugDictionary];

    CFDictionaryApplyFunction(objects, describeEnt, dict);
    [dict setIntValue:insertionSequence forKey:@"insertionSequence"];
    
    return dict;
}

@end
