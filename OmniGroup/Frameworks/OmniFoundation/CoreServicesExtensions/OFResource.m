// Copyright 2001-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFResource.h>

#import <OmniFoundation/NSString-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/CoreServicesExtensions/OFResource.m 98770 2008-03-17 22:25:33Z kc $");

@interface OFResource (Private)
@end

@implementation OFResource

// Init and dealloc


- (id)initInResourceFork:(OFResourceFork *)resFork withHandle:(Handle)resHandle;
{
    OBPRECONDITION(resFork != nil);
    OBPRECONDITION(resHandle != nil);
    
    if ([super init] == nil)
        return nil;

    resourceFork = resFork;
    resourceHandle = resHandle;
    [self recacheInfo];
    
    return self;
}

- (void)dealloc;
{
    if (name)
        [name release];
    if (type)
        [type release];
        
    [super dealloc];
}


// API

- (void)recacheInfo;
{
    short theID;
    ResType theType;
    Str255 nameBuffer;
    NSString *nameString;
    
    OBASSERT(resourceHandle != nil);
    
    GetResInfo(resourceHandle, &theID, &theType, nameBuffer);
    
    [self setResourceID:theID];
    
    if (type)
        [type release];
    type = [[NSString alloc] initWithString:[NSString stringWithFourCharCode:theType]];
    
    if (nameBuffer)
        nameString = [[NSString alloc] initWithString:(NSString *)CFStringCreateWithPascalString(NULL, nameBuffer, kCFStringEncodingMacRoman)];
    else
        nameString = [[NSString alloc] initWithString:@""];
        
    [nameString autorelease];
    [self setName:nameString];
}

- (void)saveInfoToDisk;
{
    OBASSERT(resourceHandle != nil);
    
    SetResInfo(resourceHandle, resourceID, CFStringGetPascalStringPtr((CFStringRef)name, kCFStringEncodingMacRoman));
}

- (Handle)resourceHandle;
{
    return resourceHandle;
}

- (void)setResourceHandle:(Handle)newHandle;
{
    resourceHandle = newHandle;
    [self recacheInfo];
}

- (NSString *)name;
{
    if (!name)
        [self recacheInfo];
        
    return name;
}

- (void)setName:(NSString *)newName;
{
    if (name)
        [name release];
        
    name = [newName retain];
}

- (short)resourceID;
{
    return resourceID;
}

- (void)setResourceID:(short)newResourceID;
{
    resourceID = newResourceID;
}

- (NSString *)type;
{
    return type;
}


- (unsigned long)size;
{
    OBASSERT(resourceHandle != nil);
    
    return GetResourceSizeOnDisk(resourceHandle);
}

@end

@implementation OFResource (NotificationsDelegatesDatasources)
@end

@implementation OFResource (Private)
@end
