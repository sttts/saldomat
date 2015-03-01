// Copyright 2003-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectionSet.h 95981 2007-12-13 05:01:30Z bungi $

#import <OmniFoundation/OFObject.h>

@class NSArray, NSMutableSet, NSPredicate;

typedef BOOL (*OIInspectionSetPredicateFunction)(id anObject, void *context);

#import <CoreFoundation/CFDictionary.h> // For CFMutableDictionaryRef

@interface OIInspectionSet : OFObject
{
    CFMutableDictionaryRef objects;
    unsigned int insertionSequence;
}

- (void)addObject:(id)object;
- (void)addObjectsFromArray:(NSArray *)objects;
- (void)removeObject:(id)object;
- (void)removeObjectsInArray:(NSArray *)toRemove;

- (BOOL)containsObject:(id)object;
- (unsigned int)count;

- (NSArray *)allObjects;

- (NSArray *)copyObjectsSatisfyingPredicate:(NSPredicate *)predicate;
- (void)removeObjectsSatisfyingPredicate:(NSPredicate *)predicate;
- (NSArray *)copyObjectsSatisfyingPredicateFunction:(OIInspectionSetPredicateFunction)predicate context:(void *)context;

- (NSArray *)objectsSortedByInsertionOrder:(NSArray *)someObjects;
- (unsigned int)insertionOrderForObject:(id)object; // NSNotFound if not present

@end
