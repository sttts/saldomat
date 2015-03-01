// Copyright 1998-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OIF/OIBitmapImageProcessor.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OIF/OIImage.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OIF/OIBitmapImageProcessor.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OIBitmapImageProcessor

- (void)dealloc;
{
    [resultImageRep release];
    [embeddedICCProfile release];
    [super dealloc];
}

//

- (void)setImageRep:(NSBitmapImageRep *)imageRep;
{
    NSImage *newImage;

    if (resultImageRep == imageRep)
	return;

    [resultImageRep release];
    resultImageRep = [imageRep retain];
    
    if (embeddedICCProfile != nil)
    	[resultImageRep setProperty:NSImageColorSyncProfileData withValue:embeddedICCProfile];
    
    newImage = [[[NSImage allocWithZone:[omniImage zone]] init] autorelease];

    [newImage setDataRetained:YES];
    [newImage setCachedSeparately:YES];
    [newImage addRepresentation:imageRep];

    isPlanar = [imageRep isPlanar];
    numberOfPlanes = [imageRep numberOfPlanes];
    OBASSERT(numberOfPlanes <= OIBitmapImageProcessor_MaxPlanes);
    [imageRep getBitmapDataPlanes:(unsigned char **)imageDataPlanes];
    
    // Create CGImageRef
    NSSize size = [imageRep size];
    CGImageRef cgImage = [OIImage createCGImageFromBitmapData:[imageRep bitmapData] width:size.width height:size.height bitsPerSample:[imageRep bitsPerPixel] / [imageRep samplesPerPixel] samplesPerPixel:[imageRep samplesPerPixel]];
    [self updateImage:cgImage];
    CGImageRelease(cgImage);
}

- (NSBitmapImageRep *)imageRep;
{
    return resultImageRep;
}

- (void)setEmbeddedICCProfile:(NSData *)colorProfile;
{
    if (embeddedICCProfile != colorProfile) {
        [embeddedICCProfile release];
        embeddedICCProfile = [colorProfile copy];
    }
    
    if (resultImageRep != nil)
        [resultImageRep setProperty:NSImageColorSyncProfileData withValue:embeddedICCProfile];
}

- (unsigned char **)imageDataPlanes;
{
    return (unsigned char **)imageDataPlanes;
}

// OIImageProcessor subclass

- (BOOL)expectsBitmapResult;
{
    return YES;
}

@end
