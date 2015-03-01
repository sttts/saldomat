// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/CFDictionary-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFLowerCaseTest.m 93428 2007-10-25 16:36:11Z kc $")

int main(int argc, char *argv[])
{
    CFMutableDictionaryRef dict;

    [OBPostLoader processClasses];
    
    dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFCaseInsensitiveStringKeyDictionaryCallbacks, &kCFTypeDictionaryValueCallBacks);
    
    CFDictionaryAddValue(dict, @"foo key", @"foo value");
    NSLog(@"FOO KEY = %@", CFDictionaryGetValue(dict, @"FOO KEY"));


    return 0;
}
