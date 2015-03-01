// Copyright 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <SenTestingKit/SenTestingKit.h>
#import <OmniBase/OmniBase.h>

#import <OmniFoundation/NSFileManager-OFExtensions.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFFileTests.m 98770 2008-03-17 22:25:33Z kc $");

@interface OFFileTests : SenTestCase
{
    NSString *scratchDir;
}

@end


@implementation OFFileTests

- (void)setUp
{
    if (!scratchDir) {
        scratchDir = [[[NSFileManager defaultManager] scratchDirectoryPath] copy];
        NSLog(@"%@: Scratch directory is %@", OBShortObjectDescription(self), scratchDir);
    }
}

- (void)tearDown
{
    if (scratchDir) {
        NSLog(@"%@: Deleting directory %@", OBShortObjectDescription(self), scratchDir);
        [[NSFileManager defaultManager] removeFileAtPath:scratchDir handler:nil];
        [scratchDir release];
        scratchDir = nil;
    }
}

- (void)testMakeDirectories
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *e;
    BOOL isD;
    
    e = nil;
    BOOL ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"doo/dah/day"] attributes:nil error:&e];
    STAssertTrue(ok, @"createPathToFile:... err=%@", e);
    
    STAssertTrue([fm fileExistsAtPath:[scratchDir stringByAppendingPathComponent:@"doo/dah"] isDirectory:&isD] && isD, nil);
    STAssertFalse([fm fileExistsAtPath:[scratchDir stringByAppendingPathComponent:@"doo/dah/day"]], nil);
    
    
    [@"bletcherous" writeToFile:[scratchDir stringByAppendingPathComponent:@"doo/dah/day"] atomically:NO];
    STAssertTrue([fm fileExistsAtPath:[scratchDir stringByAppendingPathComponent:@"doo/dah/day"] isDirectory:&isD] && !isD, nil);
    
    e = nil;
    ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"doo/dah/day/ding/dong"] attributes:nil error:&e];
    STAssertTrue(!ok, @"createPathToFile:... err=%@", e);
    STAssertEqualObjects([e domain], NSPOSIXErrorDomain, nil);
    NSLog(@"Failure message as expected (file in the way): %@", [e description]);
    
    e = nil;
    ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"doo/dah/day"] attributes:nil error:&e];
    STAssertTrue(ok, @"createPathToFile:... err=%@", e);
    
    [fm removeFileAtPath:[scratchDir stringByAppendingPathComponent:@"doo/dah/day"] handler:nil];
    [fm changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0111] forKey:NSFilePosixPermissions] atPath:[scratchDir stringByAppendingPathComponent:@"doo/dah"]];
    
    e = nil;
    ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"doo/dah/day/ding/dong"] attributes:nil error:&e];
    STAssertTrue(!ok, @"createPathToFile:... err=%@", e);
    STAssertEqualObjects([e domain], NSPOSIXErrorDomain, nil);
    NSLog(@"Failure message as expected (no write permission): %@", [e description]);
}

- (void)testMakeDirectoriesWithMode
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *e;
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0700]
                                                           forKey:NSFilePosixPermissions];
    
    e = nil;
    BOOL ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo"] attributes:attributes error:&e];
    STAssertTrue(ok, @"createPathToFile:... err=%@", e);
    
    STAssertEqualObjects([NSNumber numberWithInt:0700], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertEqualObjects([NSNumber numberWithInt:0700], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertFalse([fm fileExistsAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo"]], nil);
    
    
    attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0750] forKey:NSFilePosixPermissions];
    ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo/fum/fiddle!sticks/goo"] attributes:attributes error:&e];
    STAssertTrue(ok, @"createPathToFile:... err=%@", e);
    
    STAssertEqualObjects([NSNumber numberWithInt:0700], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertEqualObjects([NSNumber numberWithInt:0700], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertEqualObjects([NSNumber numberWithInt:0750], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertEqualObjects([NSNumber numberWithInt:0750], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo/fum"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertEqualObjects([NSNumber numberWithInt:0750], [[fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo/fum/fiddle!sticks"] traverseLink:NO] objectForKey:NSFilePosixPermissions], @"file mode");
    STAssertFalse([fm fileExistsAtPath:[scratchDir stringByAppendingPathComponent:@"fee/fie/fo/fum/fiddle!sticks/goo"]], nil);
}

#if 0

// Directories can't have HFS type/creator info, so this test fails.
// Should replace it with something that directories can have (other than POSIX mode).

- (void)testMakeDirectoriesWithAttr
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *e;
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:NSFileTypeForHFSTypeCode('t3sT')
                                                           forKey:NSFileHFSTypeCode];
    
    e = nil;
    BOOL ok = [fm createPathToFile:[scratchDir stringByAppendingPathComponent:@"ping/pong"] attributes:attributes error:&e];
    STAssertTrue(ok, @"createPathToFile:... err=%@", e);
    
    NSDictionary *ratts = [fm fileAttributesAtPath:[scratchDir stringByAppendingPathComponent:@"ping"] traverseLink:NO];
    STAssertFalse([fm fileExistsAtPath:[scratchDir stringByAppendingPathComponent:@"ping/pong"]], nil);
    
    STAssertEqualObjects([ratts fileType], NSFileTypeDirectory, nil);
    STAssertEquals([ratts fileHFSTypeCode], ((OSType)'t3st'), nil);
}

#endif

@end
