// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSUSendFeedbackErrorRecovery.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSoftwareUpdate/OSUSendFeedbackErrorRecovery.m 93428 2007-10-25 16:36:11Z kc $")

@implementation OSUSendFeedbackErrorRecovery

- (void)getFeedbackAddress:(NSString **)feedbackAddress andSubject:(NSString **)subjectLine;
{
    [super getFeedbackAddress:feedbackAddress andSubject:subjectLine];
    
    // Override the email address for software update related issues
    *feedbackAddress = @"omnisoftwareupdate@omnigroup.com";
}

@end
