// Copyright 2004-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFAlias.h>

#define STEnableDeprecatedAssertionMacros
#import <SenTestingKit/SenTestingKit.h>
#import <OmniBase/rcsid.h>

#import <OmniFoundation/NSData-OFExtensions.h>
#import <OmniFoundation/NSFileManager-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFAliasTests.m 98770 2008-03-17 22:25:33Z kc $")

@interface OFAliasTest : SenTestCase
{
}
@end

@implementation OFAliasTest

- (void)testAlias
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [fileManager tempFilenameFromHashesTemplate:@"/tmp/OFAliasTest-######"];
    should(path != nil);
    if (!path)
        return;
    
    should([[NSData data] writeToFile:path atomically:NO]);
    
    OFAlias *originalAlias = [[OFAlias alloc] initWithPath:path];
    NSString *resolvedPath = [originalAlias path];
    
    shouldBeEqual([path stringByStandardizingPath], [resolvedPath stringByStandardizingPath]);
    
    NSData *aliasData = [originalAlias data];
    OFAlias *restoredAlias = [[OFAlias alloc] initWithData:aliasData];
    
    NSString *moveToPath1 = [fileManager tempFilenameFromHashesTemplate:@"/tmp/OFAliasTest-######"];
    should([fileManager movePath:path toPath:moveToPath1 handler:nil]);
    
    NSString *resolvedMovedPath = [restoredAlias path];
    
    shouldBeEqual([moveToPath1 stringByStandardizingPath], [resolvedMovedPath stringByStandardizingPath]);
    
    NSString *moveToPath2 = [fileManager tempFilenameFromHashesTemplate:@"/tmp/OFAliasTest-######"];
    should([fileManager movePath:moveToPath1 toPath:moveToPath2 handler:nil]);
    
    NSData *movedAliasData = [[NSData alloc] initWithBase64String:[[restoredAlias data] base64String]];
    OFAlias *movedAliasFromData = [[OFAlias alloc] initWithData:aliasData];
    should([movedAliasFromData path] != nil);
    
    should([fileManager removeFileAtPath:moveToPath2 handler:nil]);
    
    [originalAlias release];
    [restoredAlias release];
    [movedAliasData release];
    [movedAliasFromData release];
}

@end
