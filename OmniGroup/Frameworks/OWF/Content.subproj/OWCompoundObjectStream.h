// Copyright 1999-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWCompoundObjectStream.h 68913 2005-10-03 19:36:19Z kc $

#import <OWF/OWAbstractObjectStream.h>

@class OWObjectStreamCursor;

@interface OWCompoundObjectStream : OWAbstractObjectStream
{
    OWAbstractObjectStream *framingStream;
    OWAbstractObjectStream *interjectedStream;

    unsigned int interjectedAtIndex;
}

/* a convenience method */
+ (OWObjectStreamCursor *)cursorAtCursor:(OWObjectStreamCursor *)aCursor beforeStream:(OWAbstractObjectStream *)interjectMe;

/* designated initializer */
- initWithStream:(OWAbstractObjectStream *)aStream interjectingStream:(OWAbstractObjectStream *)anotherStream atIndex:(unsigned int)index;

/* raises an exception if aStream is not a (possibly indirect) member of this compound object stream */
- (unsigned int)translateIndex:(unsigned int)index fromStream:(OWAbstractObjectStream *)aStream;

@end
