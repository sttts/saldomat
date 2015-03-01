// Copyright 1997-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSUserDefaults-OAExtensions.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSUserDefaults-OAExtensions.m 91073 2007-09-11 22:58:40Z wiml $")

static NSColor *nsColorFromRGBAString(NSString *value)
{
    float r = 0.0, g = 0.0, b = 0.0, a = 1.0;
    
    if ([NSString isEmptyString:value])
        return nil;
    
    int components = sscanf([value UTF8String], "%f%f%f%f", &r, &g, &b, &a);
    if (components != 3 && components != 4)
        return nil;

    return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
}

static NSString *rgbaStringFromNSColor(NSColor *color)
{
    OBASSERT(color != nil); // Caller should be doing fallback
    
    float r, g, b, a;
    [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
    if (a == 1.0)
	return [NSString stringWithFormat:@"%g %g %g", r, g, b];
    else
	return [NSString stringWithFormat:@"%g %g %g %g", r, g, b, a];
}

@implementation NSUserDefaults (OAExtensions)

- (NSColor *)colorForKey:(NSString *)defaultName;
{
    return nsColorFromRGBAString([self stringForKey:defaultName]);
}

- (NSColor *)grayForKey:(NSString *)defaultName;
{
    return [NSColor colorWithCalibratedWhite:[self floatForKey:defaultName] alpha:1.0];
}

- (void)setColor:(NSColor *)color forKey:(NSString *)defaultName;
{
    if (!color) {
        [self setObject:@"" forKey:defaultName];
    } else {
        [self setObject:rgbaStringFromNSColor(color) forKey:defaultName];
    }
}

- (void)setGray:(NSColor *)gray forKey:(NSString *)defaultName;
{
    float grayFloat;

    [[gray colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] getWhite:&grayFloat alpha:NULL];
    [self setFloat:grayFloat forKey:defaultName];
}

@end


@implementation OFPreference (OAExtensions)

- (NSColor *)colorValue;
{
    return nsColorFromRGBAString([self stringValue]);
}

- (void)setColorValue:(NSColor *)color;
{
    if (color == nil) {
        [self setObjectValue:nil];
    } else {
        [self setStringValue:rgbaStringFromNSColor(color)];
    }
}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
- (NSFontDescriptor *)fontDescriptorValue;
{
    NSDictionary *attributes = [self objectValue];
    return [NSFontDescriptor fontDescriptorWithFontAttributes:attributes];
}

- (void)setFontDescriptorValue:(NSFontDescriptor *)fontDescriptor;
{
    NSDictionary *attributes = [fontDescriptor fontAttributes];
    [self setObjectValue:attributes];
}
#endif

@end

@implementation OFPreferenceWrapper (OAExtensions)

- (NSColor *)colorForKey:(NSString *)defaultName;
{
    return nsColorFromRGBAString([self stringForKey:defaultName]);
}

- (NSColor *)grayForKey:(NSString *)defaultName;
{
    return [NSColor colorWithCalibratedWhite:[self floatForKey:defaultName] alpha:1.0];
}

- (void)setColor:(NSColor *)color forKey:(NSString *)defaultName;
{
    if (!color) {
        [self setObject:@"x" forKey:defaultName];
    } else {
        [self setObject:rgbaStringFromNSColor(color) forKey:defaultName];
    }
}

- (void)setGray:(NSColor *)gray forKey:(NSString *)defaultName;
{
    float grayFloat;

    [[gray colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] getWhite:&grayFloat alpha:NULL];
    [self setFloat:grayFloat forKey:defaultName];
}

@end

