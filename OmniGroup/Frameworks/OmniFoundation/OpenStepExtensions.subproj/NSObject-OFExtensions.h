// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSObject-OFExtensions.h 98560 2008-03-12 17:28:00Z bungi $

#import <Foundation/NSObject.h>

@class NSArray, NSSet, NSBundle;

@interface NSObject (OFExtensions)

+ (Class)classImplementingSelector:(SEL)aSelector;

+ (NSBundle *)bundle;
- (NSBundle *)bundle;

- (void)performSelector:(SEL)sel withEachObjectInArray:(NSArray *)array;
- (void)performSelector:(SEL)sel withEachObjectInSet:(NSSet *)set;

- (BOOL)satisfiesCondition:(SEL)sel withObject:(id)object;

@end
