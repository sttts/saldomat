// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/CFSet-OFExtensions.h>

#import <OmniFoundation/OFCFCallbacks.h>
#import <OmniFoundation/OFCFWeakRetainCallbacks.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/CoreFoundationExtensions/CFSet-OFExtensions.m 98770 2008-03-17 22:25:33Z kc $")


const CFSetCallBacks
OFCaseInsensitiveStringSetCallbacks = {
    0,   // version
    OFCFTypeRetain,
    OFCFTypeRelease,
    OFCFTypeCopyDescription,
    OFCaseInsensitiveStringIsEqual,
    OFCaseInsensitiveStringHash,
};

const CFSetCallBacks OFNonOwnedPointerSetCallbacks  = {
    0,    // version
    NULL, // retain
    NULL, // release
    OFPointerCopyDescription,
    NULL, // isEqual
    NULL, // hash
};

const CFSetCallBacks OFIntegerSetCallbacks = {
    0,    // version
    NULL, // retain
    NULL, // release
    OFIntegerCopyDescription,
    NULL, // isEqual
    NULL, // hash
};

// -retain/-release, but no -hash/-isEqual:
const CFSetCallBacks OFPointerEqualObjectSetCallbacks = {
    0,   // version
    OFNSObjectRetain,
    OFNSObjectRelease,
    OFNSObjectCopyDescription,
    NULL,
    NULL,
};

// Not retained, but -hash/-isEqual:
const CFSetCallBacks OFNonOwnedObjectCallbacks = {
    0,    // version
    NULL, // retain
    NULL, // release
    OFNSObjectCopyDescription,
    OFNSObjectIsEqual,
    OFNSObjectHash,
};

const CFSetCallBacks OFNSObjectSetCallbacks = {
    0,   // version
    OFNSObjectRetain,
    OFNSObjectRelease,
    OFNSObjectCopyDescription,
    OFNSObjectIsEqual,
    OFNSObjectHash,
};

const CFSetCallBacks OFWeaklyRetainedObjectSetCallbacks = {
    0,   // version
    OFNSObjectWeakRetain,
    OFNSObjectWeakRelease,
    OFNSObjectCopyDescription,
    OFNSObjectIsEqual,
    OFNSObjectHash,
};

NSMutableSet *OFCreateNonOwnedPointerSet(void)
{
    return (NSMutableSet *)CFSetCreateMutable(kCFAllocatorDefault, 0, &OFNonOwnedPointerSetCallbacks);
}

NSMutableSet *OFCreatePointerEqualObjectSet(void)
{
    return (NSMutableSet *)CFSetCreateMutable(kCFAllocatorDefault, 0, &OFPointerEqualObjectSetCallbacks);
}
