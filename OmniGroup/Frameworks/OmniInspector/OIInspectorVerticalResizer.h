// Copyright 2002-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectorVerticalResizer.h 72316 2006-02-07 18:59:27Z bungi $

#import <AppKit/NSSplitView.h>

@interface OIInspectorVerticalResizer : NSSplitView 
{
    float minimumSuperviewHeight;
}

@end
