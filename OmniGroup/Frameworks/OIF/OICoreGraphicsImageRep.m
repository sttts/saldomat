// Copyright 2001-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OICoreGraphicsImageRep.h"

#import <Foundation/Foundation.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSGraphicsContext.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OIF/OICoreGraphicsImageRep.m 68913 2005-10-03 19:36:19Z kc $");

@interface OICoreGraphicsImageRep (Private)
@end

@implementation OICoreGraphicsImageRep

+ (void)initialize
{
    OBINITIALIZE;

    [self registerImageRepClass:self];
}

// Init and dealloc

- initWithImageRef:(CGImageRef)myImage colorSpaceName:(NSString *)space;
{
    if ([super init] == nil)
        return nil;

    cgImage = myImage;
    CGImageRetain(cgImage);
    colorSpaceName = [space copy];

    return self;
}

- (void)dealloc;
{
    if (cgImage != NULL)
        CGImageRelease(cgImage);
        
    [colorSpaceName release];
    [heldObject release];
    [super dealloc];
}


// API

- (void)setImage:(CGImageRef)newImage
{
    if (cgImage != newImage) {
        if (cgImage != NULL)
            CGImageRelease(cgImage);
        cgImage = CGImageRetain(newImage);
    }
    
    // mark self for redisplay ?
}

- (void)setColorSpaceHolder:(id <NSObject>)anObject
{
    // The reason for this is a little obscure. We never actually use the color space object (an OIICCProfile instance). It's mainly just a wrapper around a CGColorSpaceRef, and the CGImage holds on to that by itself. However, if we keep the OIICCProfile from being deallocated, it will maintain a map table entry which allows image processors to use the same CGColorSpace for identical color profiles read from different images. Is this actually a performance gain? I have no idea. It seems like it ought to be, though.
    [heldObject autorelease];
    heldObject = [anObject retain];
}

// NSImageRep attributes

- (int)bitsPerSample
{
    if (cgImage)
        return CGImageGetBitsPerComponent(cgImage);
    else
        return 0;
}

- (NSString *)colorSpaceName
{
    return colorSpaceName;
}

- (BOOL)draw
{
    CGRect where;
    
    if (cgImage == NULL)
        return NO;
    
    where.origin.x = 0;
    where.origin.y = 0;
    where.size.width = CGImageGetWidth(cgImage);
    where.size.height = CGImageGetHeight(cgImage);
    
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], where, cgImage);
    
    return YES;
}

- (BOOL)drawAtPoint:(NSPoint)aPoint
{
    CGRect where;
    
    if (cgImage == NULL)
        return NO;
    
    where.origin.x = aPoint.x;
    where.origin.y = aPoint.y;
    where.size.width = CGImageGetWidth(cgImage);
    where.size.height = CGImageGetHeight(cgImage);
    
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], where, cgImage);
    
    return YES;
}

- (BOOL)drawInRect:(NSRect)rect
{
    CGRect where;
    
    if (cgImage == NULL)
        return NO;
    
    where.origin.x = rect.origin.x;
    where.origin.y = rect.origin.y;
    where.size.width = rect.size.width;
    where.size.height = rect.size.height;
    
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], where, cgImage);
    
    return YES;
}

- (BOOL)hasAlpha
{
    if (cgImage == NULL)
        return NO;
    
    switch(CGImageGetAlphaInfo(cgImage)) {
	case kCGImageAlphaNone:
	case kCGImageAlphaNoneSkipLast:
	case kCGImageAlphaNoneSkipFirst:
            return NO;
            
        case kCGImageAlphaPremultipliedLast:
	case kCGImageAlphaPremultipliedFirst:
	case kCGImageAlphaLast:
	case kCGImageAlphaFirst:
#if defined(MAC_OS_X_VERSION_10_3) && (MAC_OS_X_VERSION_10_3 <= MAC_OS_X_VERSION_MAX_ALLOWED)
	case kCGImageAlphaOnly:
#endif
	default:
            return YES;
    }
    
    return NO;
}

- (int)pixelsHigh
{
    if (cgImage == NULL)
        return 0;
    else
        return CGImageGetHeight(cgImage);
}

- (int)pixelsWide
{
    if (cgImage == NULL)
        return 0;
    else
        return CGImageGetWidth(cgImage);
}

@end

@implementation OICoreGraphicsImageRep (NotificationsDelegatesDatasources)
@end

@implementation OICoreGraphicsImageRep (Private)
@end
