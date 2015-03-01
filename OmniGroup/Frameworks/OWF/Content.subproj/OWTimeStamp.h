// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWTimeStamp.h 68913 2005-10-03 19:36:19Z kc $

#import <OWF/OWAbstractContent.h>

@class NSDate;
@class OWAddress, OWContentCache, OWContentType;

@interface OWTimeStamp : OWAbstractContent
{
    NSDate *date;
    OWContentType *type;
}

+ (OWContentType *)lastChangedContentType;
+ (NSDate *)dateForAddress:(OWAddress *)address;

- initWithDate:(NSDate *)aDate contentType:(OWContentType *)dateType;
- (NSDate *)date;

@end

