// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAFlippedView.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/branches/Staff/bungi/OmniFocus-20071104-ColumnResizing/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OAFileWell.m 68913 2005-10-03 19:36:19Z kc $")

// Useful for nibs where you need a flipped container view that has nothing else special about it.
@implementation OAFlippedView

- (BOOL)isFlipped;
{
    return YES;
}

@end
