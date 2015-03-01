// Copyright 2002-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFCFWeakRetainCallbacks.h>

#import <OmniBase/rcsid.h>
#import <OmniFoundation/OFWeakRetainProtocol.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/CoreFoundationExtensions/OFCFWeakRetainCallbacks.m 98771 2008-03-17 22:31:08Z kc $")

//
// OFWeakRetain callbacks
//

const void *OFNSObjectWeakRetain(CFAllocatorRef allocator, const void *value)
{
    id <OFWeakRetain,NSObject> objectValue = (void *)value;
    [objectValue retain];
    [objectValue incrementWeakRetainCount];
    return objectValue;
}

void OFNSObjectWeakRelease(CFAllocatorRef allocator, const void *value)
{
    id <OFWeakRetain,NSObject> const objectValue = (void *)value;
    [objectValue decrementWeakRetainCount];
    [objectValue release];
}

