// Copyright 2003-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniBase/rcsid.h>

NAMED_RCS_ID(cache_constants, "$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Cache.subproj/OWDiskCacheInternal.h 89475 2007-08-01 23:58:16Z kc $");

#define OWDiskCache_DBVersion 10
#define OWDiskCache_DBVersion_Key (@"OWDiskCache DB Version")


enum OWDiskCacheConcreteContentType {
    OWDiskCacheUnknownConcreteType = 0,
    OWDiskCacheAddressConcreteType = 1,
    OWDiskCacheBytesConcreteType = 2,
    OWDiskCacheExceptionConcreteType = 3,
};

#define OWDiskCacheConcreteContentTypeMask	0x00FF	// Bits used for the concrete-type enum
#define OWDiskCacheConcreteContentInFile	0x8000	// Indicates the content is stored in its own file 
