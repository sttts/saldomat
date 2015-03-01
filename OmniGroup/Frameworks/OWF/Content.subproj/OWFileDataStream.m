// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWFileDataStream.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

@interface OWFileDataStream (private)
@end

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWFileDataStream.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWFileDataStream

// Init and dealloc

- initWithData:(NSData *)data filename:(NSString *)aFilename;
{
    if (data == nil) {
	[self release];
	return nil;
    }

    if ([super init] == nil)
	return nil;

    inputFilename = [aFilename retain];
    [self writeData:data];
    [self dataEnd];

    return self;
}

- initWithContentsOfFile:(NSString *)aFilename;
{
    NSData *data;
    id returnValue;
    
    aFilename = [aFilename stringByExpandingTildeInPath];
    data = [[NSData alloc] initWithContentsOfFile:aFilename];
    returnValue = [self initWithData:data filename:aFilename];
    [data release];
    return returnValue;
}

- initWithContentsOfMappedFile:(NSString *)aFilename;
{
    NSData *data;
    id returnValue;

    aFilename = [aFilename stringByExpandingTildeInPath];
    data = [[NSData alloc] initWithContentsOfMappedFile:aFilename];
    returnValue = [self initWithData:data filename:aFilename];
    [data release];
    return returnValue;
}

// DEPRECATED as of 12/10/2001: This method exists only for backwards compatibility
- initWithData:(NSData *)data;
{
    return [self initWithData:data filename:nil];
}

- (void)dealloc;
{
    [inputFilename release];
    [super dealloc];
}

// OWDataStream subclass

- (BOOL)pipeToFilename:(NSString *)aFilename withAttributes:(NSDictionary *)fileAttributes shouldPreservePartialFile:(BOOL)shouldPreserve;
{
    // Don't copy our input data unnecessarily
    if (inputFilename != nil)
	return NO;
    return [super pipeToFilename:aFilename withAttributes:fileAttributes shouldPreservePartialFile:shouldPreserve];
}

- (NSString *)filename;
{
    // Return our input filename
    if (inputFilename != nil)
        return inputFilename;
    return [super filename];
}

@end
