// Copyright 2003-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSApplication-OSUSupport.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/rcsid.h>

#import "OSUController.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSoftwareUpdate/NSApplication-OSUSupport.m 68944 2005-10-03 21:24:25Z kc $");

@implementation NSApplication (OSUSupport)

// Check for new version of this application on Omni's web site. Triggered by direct user action.
- (IBAction)checkForNewVersion:(id)sender;
{
    [[OSUController class] checkSynchronouslyWithUIAttachedToWindow:nil];
}

@end

