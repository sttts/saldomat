// Copyright 1997-2005, 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/sha1.h 98221 2008-03-04 21:06:19Z kc $

#define SHA1_SIGNATURE_LENGTH 20

typedef struct {
    unsigned long state[5];
    unsigned long count[2];
    unsigned char buffer[64];
} SHA1_CTX;

// Use __private_extern__ so these functions are available within this framework, but not exported outside of the framework.
__private_extern__ void SHA1Init(SHA1_CTX* context);
__private_extern__ void SHA1Update(SHA1_CTX* context, const unsigned char* data, unsigned int len);
__private_extern__ void SHA1Final(unsigned char digest[SHA1_SIGNATURE_LENGTH], SHA1_CTX* context);

