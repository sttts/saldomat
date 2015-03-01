// Copyright 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSIndexSet-OFExtensions.h 98846 2008-03-19 21:42:15Z wiml $
//

#import <Foundation/NSIndexSet.h>

@interface NSIndexSet (OFExtensions)

- (NSString *)rangeString;
- initWithRangeString:(NSString *)aString;
+ indexSetWithRangeString:(NSString *)aString;

- (NSRange)rangeGreaterThanOrEqualToIndex:(NSUInteger)index;

@end

