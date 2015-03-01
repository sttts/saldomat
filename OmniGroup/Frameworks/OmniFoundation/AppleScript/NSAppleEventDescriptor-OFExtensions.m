// Copyright 1997-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSAppleEventDescriptor-OFExtensions.h>

#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/AppleScript/NSAppleEventDescriptor-OFExtensions.m 98771 2008-03-17 22:31:08Z kc $")

@implementation NSAppleEventDescriptor (OFExtensions)

@end

@implementation NSDictionary (OFExtensions_NSAppleEventDescriptor)

+ (NSDictionary *)dictionaryWithUserRecord:(NSAppleEventDescriptor *)descriptor;
{
    if (!(descriptor = [descriptor descriptorForKeyword:'usrf']))
        return nil;
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    int itemIndex, itemCount = [descriptor numberOfItems];
    
    for (itemIndex = 1; itemIndex <= itemCount; itemIndex += 2) {
        NSString *key = [[descriptor descriptorAtIndex:itemIndex] stringValue];
        NSString *value = [[descriptor descriptorAtIndex:itemIndex+1] stringValue];
        [result setObject:value forKey:key];
    }
    return result;
}

- (NSAppleEventDescriptor *)userRecordValue;
{
    NSAppleEventDescriptor *listDescriptor = [NSAppleEventDescriptor listDescriptor];
    NSEnumerator *enumerator = [self keyEnumerator];
    NSString *key;
    int listCount = 0;
    
    while ((key = [enumerator nextObject])) {
        NSString *value = [[self objectForKey:key] description];
        [listDescriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithString:key] atIndex:++listCount];
        [listDescriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithString:value] atIndex:++listCount];
    }
    
    NSAppleEventDescriptor *result = [NSAppleEventDescriptor recordDescriptor];
    [result setDescriptor:listDescriptor forKeyword:'usrf'];
    return result;
}

@end
