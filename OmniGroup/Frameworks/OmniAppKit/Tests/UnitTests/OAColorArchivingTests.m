// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OATestCase.h"

#import <OmniBase/rcsid.h>
#import <OmniAppKit/NSColor-OAExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/Tests/UnitTests/OAColorArchivingTests.m 93429 2007-10-25 16:39:40Z kc $")

@interface OAColorArchivingTests : OATestCase
@end

@implementation OAColorArchivingTests

static void _checkFile(OAColorArchivingTests *self, NSString *path, NSData *actualData)
{
    // We expect to be run from the OmniAppKit folder
    path = [@"Tests/UnitTests/OAColorArchivingTests" stringByAppendingPathComponent:path];
    
    NSData *expectedData = [NSData dataWithContentsOfFile:path];
    STAssertNotNil(expectedData, [NSString stringWithFormat:@"should have expected data in %@", path]);
    if (OFNOTEQUAL(expectedData, actualData)) {
        NSString *actualPath = [@"/tmp" stringByAppendingPathComponent:[path lastPathComponent]];
        NSLog(@"Actual data saved in %@", actualPath);
        [actualData writeToFile:actualPath atomically:YES];
    }
    STAssertEqualObjects(expectedData, actualData, @"archived colors should be equal");
}

static BOOL _compareColors(NSColor *a, NSColor *b)
{
    if ([[a colorSpaceName] isEqualToString:NSPatternColorSpace] && [[b colorSpaceName] isEqualToString:NSPatternColorSpace]) {
        // NSImages are only -isEqual: if they are ==, which they won't be after an archive/unarchive.
        NSData *tiffA = [[a patternImage] TIFFRepresentation];
        NSData *tiffB = [[b patternImage] TIFFRepresentation];
        return OFISEQUAL(tiffA, tiffB);
    }
    
    return OFISEQUAL(a, b);
}

static void _checkPlist(OAColorArchivingTests *self, NSColor *color, NSDictionary *plist, NSString *name, SEL sel)
{
    STAssertNotNil(plist, @"shoud have made a plist");
    if (plist == nil)
        return;

    NSString *error = nil;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:plist format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    STAssertNil(error, @"shoud be no error archiving");
    STAssertNotNil(data, @"should get something back from archiving");
    
    if (!data)
        return;
    
    _checkFile(self, [NSString stringWithFormat:@"%@-%@", [NSStringFromSelector(sel) stringByRemovingPrefix:@"test"], name], data);
    
    // Don't add extra spurious failures on an encoding failure
    if (plist) {
        // Reconstitute the color and compare them.
        NSColor *unarchived = [NSColor colorFromPropertyListRepresentation:plist];
        STAssertTrue(_compareColors(color, unarchived), @"plist color archiving/unarchive should be idempotent");
    }
}

static void _checkColor(OAColorArchivingTests *self, NSColor *color, SEL sel)
{
    STAssertNotNil(color, @"shoud have gotten a color");
    if (color == nil)
        return;

    _checkPlist(self, color, [color propertyListRepresentationWithStringComponentsOmittingDefaultValues:YES], @"string-partial.plist", sel);
    _checkPlist(self, color, [color propertyListRepresentationWithStringComponentsOmittingDefaultValues:NO], @"string-full.plist", sel);

    _checkPlist(self, color, [color propertyListRepresentationWithNumberComponentsOmittingDefaultValues:YES], @"number-partial.plist", sel);
    _checkPlist(self, color, [color propertyListRepresentationWithNumberComponentsOmittingDefaultValues:NO], @"number-full.plist", sel);
    
    OFXMLWhitespaceBehavior *whitespace = [[[OFXMLWhitespaceBehavior alloc] init] autorelease];
    OFXMLDocument *doc = [[[OFXMLDocument alloc] initWithRootElementName:@"ignored" namespaceURL:nil whitespaceBehavior:whitespace stringEncoding:kCFStringEncodingUTF8] autorelease];
    
    [color appendXML:doc];
    
    OFXMLElement *colorElement = [[[doc topElement] children] lastObject];
    NSData *xmlData = [colorElement xmlDataAsFragment];
    _checkFile(self, [NSString stringWithFormat:@"%@.xml", [NSStringFromSelector(sel) stringByRemovingPrefix:@"test"]], xmlData);
    
    // Don't add extra spurious failures on an encoding failure
    if (xmlData) {
        // Reconstitute the color and compare them.
        OFXMLCursor *cursor = [[[OFXMLCursor alloc] initWithDocument:doc element:colorElement] autorelease];
        NSColor *unarchived = [NSColor colorFromXML:cursor];
        STAssertTrue(_compareColors(color, unarchived), @"XML color archiving/unarchive should be idempotent");
    }
}

#define CHECK(x) _checkColor(self, x, _cmd)

- (void)testRGB;
{
    CHECK([NSColor colorWithCalibratedRed:0.125 green:0.25 blue:0.5 alpha:1.0]);
}

- (void)testRGBA;
{
    CHECK([NSColor colorWithCalibratedRed:0.125 green:0.25 blue:0.5 alpha:0.75]);
}

- (void)testWhite;
{
    CHECK([NSColor colorWithCalibratedWhite:0.5 alpha:1.0]);
}

- (void)testWhiteAlpha;
{
    CHECK([NSColor colorWithCalibratedWhite:0.5 alpha:0.75]);
}

- (void)testBlack;
{
    // There seems to be no way to *get* a color in NSCalibratedBlackColorSpace.  Let's verify that that is still true.
    NSColor *white = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    NSColor *whiteToBlack = [white colorUsingColorSpaceName:NSCalibratedBlackColorSpace];
    STAssertNil(whiteToBlack, @"converting white->black expected to produce nil");

    float components[2] = {0.25, 1.0};     
    NSColor *gray = [NSColor colorWithColorSpace:[NSColorSpace genericGrayColorSpace] components:components count:2];
    NSColor *grayToBlack = [gray colorUsingColorSpaceName:NSCalibratedBlackColorSpace];
    STAssertNil(grayToBlack, @"converting grey->black expected to produce nil");
    
    NSColor *rgb = [NSColor colorWithCalibratedRed:0.0f green:0.0f blue:0.0f alpha:1.0f];
    NSColor *rgbToBlack = [rgb colorUsingColorSpaceName:NSCalibratedBlackColorSpace];
    STAssertNil(rgbToBlack, @"converting rgb->black expected to produce nil");
}

- (void)testCatalog;
{
    CHECK([NSColor textColor]);
}

- (void)testHSV;
{
    CHECK([NSColor colorWithCalibratedHue:0.75 saturation:0.5 brightness:0.25 alpha:1.0]);
}

- (void)testHSVA;
{
    CHECK([NSColor colorWithCalibratedHue:0.75 saturation:0.5 brightness:0.25 alpha:0.75]);
}

- (void)testCMYK;
{
    float components[5] = {0.125, 0.25, 0.5, 0.625, 1.0};
    CHECK([NSColor colorWithColorSpace:[NSColorSpace genericCMYKColorSpace] components:components count:5]);
}

- (void)testCMYKA;
{
    float components[5] = {0.125, 0.25, 0.5, 0.625, 0.75};
    CHECK([NSColor colorWithColorSpace:[NSColorSpace genericCMYKColorSpace] components:components count:5]);
}

- (void)testPattern;
{
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile:@"Tests/UnitTests/OAColorArchivingTests/pattern.tiff"] autorelease];
    STAssertNotNil(image, @"image should exist");
    CHECK([NSColor colorWithPatternImage:image]);
}

@end
