// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFClobberDetectionZone.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFClobberDetectionZoneTest.m 93428 2007-10-25 16:36:11Z kc $")


int main(int argc, char *argv[])
{
    unsigned char *p, *q;
    
    OFUseClobberDetectionZoneAsDefaultZone();
    
    
    p = malloc(200);
    q = malloc(300);
    malloc_zone_print(malloc_default_zone(), 1);
    
    free(p);
    malloc_zone_print(malloc_default_zone(), 1);

    free(q);
    malloc_zone_print(malloc_default_zone(), 1);

    p = malloc(200);
    q = malloc(300);
    malloc_zone_print(malloc_default_zone(), 1);
    
    free(q);
    malloc_zone_print(malloc_default_zone(), 1);

    free(p);
    malloc_zone_print(malloc_default_zone(), 1);


    q[0] = 1;
    p[10] = 1;
    
    return 0;
}
