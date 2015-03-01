// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <SenTestingKit/SenTestCase.h>
#import <OmniFoundation/NSData-OFExtensions.h>
#import <OmniFoundation/OFScratchFile.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFDataTest.m 93138 2007-10-21 01:47:41Z bungi $");

@interface OFDataTest : SenTestCase
{
}


@end


@implementation OFDataTest

- (void)testPipe
{
    NSData *smallData   = [NSData dataWithBytes:"Just remember ... wherever you go ... there you are." length:52];
    NSData *smallData13 = [NSData dataWithBytes:"Whfg erzrzore ... jurerire lbh tb ... gurer lbh ner." length:52];

    STAssertEqualObjects(([smallData filterDataThroughCommandAtPath:@"/usr/bin/tr" withArguments:[NSArray arrayWithObjects:@"A-Za-z", @"N-ZA-Mn-za-m", nil]]),
                         smallData13, @"Piping through rot13");
    
    int mediumSize = 67890;
    NSData *mediumData = [NSData randomDataOfLength:mediumSize];
    NSData *mediumR = [mediumData filterDataThroughCommandAtPath:@"/usr/bin/wc" withArguments:[NSArray arrayWithObject:@"-c"]];
    STAssertTrue(mediumSize == atoi([mediumR bytes]), @"Piping through wc");
    
    STAssertEqualObjects(([mediumData filterDataThroughCommandAtPath:@"/bin/cat" withArguments:[NSArray array]]),
                         mediumData, @"");
    
    NSError *error = nil;
    OFScratchFile *scratch = [OFScratchFile scratchFileNamed:@"ofdatatest" error:&error];
    STAssertNotNil(scratch, @"scratch file");
    if (!scratch)
        return;
    
    [mediumData writeToFile:[scratch filename] atomically:NO];
    
    STAssertEqualObjects(([[NSData data] filterDataThroughCommandAtPath:@"/bin/cat" withArguments:[NSArray arrayWithObject:[scratch filename]]]),
                         mediumData, @"");
    
    /* Make a big random plist */
    NSData *pldata;
    {
        NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
        NSMutableArray *a = [NSMutableArray array];
        int i;
        for(i = 0; i < 300; i++) {
            NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
            int j;
            for(j = 0; j < 250; j++) {
                NSString *s = [[NSData randomDataOfLength:15] lowercaseHexString];
                [d setObject:[NSData randomDataOfLength:72] forKey:s];
            }
            [a addObject:d];
            [d release];
        }
        pldata = (NSData *)CFPropertyListCreateXMLData(kCFAllocatorDefault, (CFPropertyListRef)a);
        [p release];
    }
    
    NSData *bzipme = [pldata filterDataThroughCommandAtPath:@"/usr/bin/bzip2" withArguments:[NSArray arrayWithObject:@"--compress"]];
    NSData *unzipt = [bzipme filterDataThroughCommandAtPath:@"/usr/bin/bzip2" withArguments:[NSArray arrayWithObject:@"--decompress"]];
    
    STAssertEqualObjects(pldata, unzipt, @"bzip+bunzip");
}

- (void)testPipeFailure
{
    NSData *smallData   = [NSData dataWithBytes:"Just remember ... wherever you go ... there you are." length:52];

    STAssertThrows([smallData filterDataThroughCommandAtPath:@"/usr/bin/false" withArguments:[NSArray array]], @"");
    
    STAssertThrows([smallData filterDataThroughCommandAtPath:@"/bin/quux-nonexist" withArguments:[NSArray array]], @"");
    
    STAssertEqualObjects([NSData data],
                         [smallData filterDataThroughCommandAtPath:@"/usr/bin/true" withArguments:[NSArray array]], @"");
}

- (void)testMergingStdoutAndStderr;
{
    NSError *error = nil;
    NSData *outputData = [[NSData data] filterDataThroughCommandAtPath:@"/bin/sh" withArguments:[NSArray arrayWithObjects:@"-c", @"echo foo; echo bar 1>&2", nil] includeErrorsInOutput:YES errorStream:nil error:&error];
    STAssertEqualObjects(outputData, [@"foo\nbar\n" dataUsingEncoding:NSUTF8StringEncoding], @"");
    STAssertTrue(error == nil, @"");
}

- (void)testSendingStderrToStream;
{
    // Errors go to the stream, output to the output data
    NSError *error = nil;
    NSOutputStream *errorStream = [NSOutputStream outputStreamToMemory];
    [errorStream open]; // Else, an error will result when writing to the stream
    
    NSData *outputData = [[NSData data] filterDataThroughCommandAtPath:@"/bin/sh" withArguments:[NSArray arrayWithObjects:@"-c", @"echo foo; echo bar 1>&2", nil] includeErrorsInOutput:NO errorStream:errorStream error:&error];
    
    STAssertEqualObjects(outputData, [@"foo\n" dataUsingEncoding:NSUTF8StringEncoding], @"");
    STAssertEqualObjects([errorStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey], [@"bar\n" dataUsingEncoding:NSUTF8StringEncoding], @"");
    STAssertTrue(error == nil, @"no error");
}

@end
