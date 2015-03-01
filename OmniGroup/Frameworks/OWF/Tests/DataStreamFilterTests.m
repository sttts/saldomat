// Copyright 2003-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/Foundation.h>
#import <OmniBase/rcsid.h>
#import <OmniFoundation/NSData-OFExtensions.h>
#import <OWF/OWContentType.h>
#import <OWF/OWDataStream.h>
#import <OWF/OWDataStreamCursor.h>
#import <SenTestingKit/SenTestingKit.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Tests/DataStreamFilterTests.m 68913 2005-10-03 19:36:19Z kc $");

static NSDictionary *smalldata, *bigdata;

@interface DataStreamFilterTests : SenTestCase
{
}


@end

@implementation DataStreamFilterTests

// Setup

+ (void)initialize
{
    if (!smalldata)
        smalldata = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"smalldata" ofType:@"plist"]];
    
    if (!bigdata)
        bigdata = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"bigdata" ofType:@"plist"]];
}

// Test cases

- (void)testReadAll:(NSData *)inp bp:(unsigned)writeSome after:(unsigned)readSome giving:(NSData *)outp coder:(OWContentType *)coder
{
    OWDataStream *ds;
    OWDataStreamCursor *reader;
    NSData *some, *rest;
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];

    if (writeSome > [inp length]) {
        ds = [[OWDataStream alloc] initWithLength:[inp length]];
        [ds writeData:inp];
        [ds dataEnd];
    } else {
        ds = [[OWDataStream alloc] init];
        [ds writeData:[inp subdataWithRange:(NSRange){0, writeSome}]];
        [NSThread detachNewThreadSelector:@selector(finishWriting:)
                                 toTarget:self
                               withObject:[NSArray arrayWithObjects:ds, [inp subdataWithRange:(NSRange){writeSome, [inp length]-writeSome}], nil]];
    }

    reader = [OWDataStreamCursor cursorToRemoveEncoding:coder fromCursor:[ds newCursor]];
    [ds release];
    ds = nil;

    should(reader != nil);

    [reader retain];
    [pool release];
    pool = [[NSAutoreleasePool alloc] init];
    [reader autorelease];

    if (readSome > 0) {
        some = [reader readBytes:readSome];
    } else {
        some = [NSData data];
    }

    if (writeSome <= [inp length]) {
        [ds writeData:[inp subdataWithRange:(NSRange){writeSome, [inp length]-writeSome}]];
        [ds dataEnd];
    }

    rest = [reader readAllData];

    shouldBeEqual1(outp, [some dataByAppendingData:rest], ([NSString stringWithFormat:@"coder=%@, writeBreak=%d, readBreak=%d", coder, writeSome, readSome]));
    [pool release];
}

- (void)finishWriting:(NSArray *)args
{
    NSData *d = [args objectAtIndex:1];
    OWDataStream *c = [args objectAtIndex:0];

    usleep(1000);
    [c writeData:d];
    [c dataEnd];
}

- (void)testSmallIn:(NSData *)gzIn smallOut:(NSData *)gzOut coder:(OWContentType *)coder
{
    [self testReadAll:gzIn bp:UINT_MAX after:0 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:1 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:2 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:3 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:4 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:5 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:15 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:16 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:17 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:[gzOut length]-1 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:[gzOut length] giving:gzOut coder:coder];
    
    [self testReadAll:gzIn bp:1 after:2 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:300 after:2 giving:gzOut coder:coder];
}

- (void)testLargeIn:(NSData *)gzIn smallOut:(NSData *)gzOut coder:(OWContentType *)coder
{
    [self testReadAll:gzIn bp:UINT_MAX after:0 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:1 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:6000 after:1 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:4095 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:4096 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:4097 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:[gzOut length]-1 giving:gzOut coder:coder];
    [self testReadAll:gzIn bp:UINT_MAX after:[gzOut length] giving:gzOut coder:coder];
}

- (void)testSmallGunzip
{
    NSData *gzIn, *gzOut;

    gzIn = [smalldata objectForKey:@"gzIn"];
    gzOut = [smalldata objectForKey:@"gzOut"];
    should(gzIn != nil);
    should(gzOut != nil);

    [self testSmallIn:gzIn smallOut:gzOut coder:[OWContentType contentEncodingForString:@"gzip"]];
}

- (void)testLargeGunzip
{
    NSData *gzIn, *gzOut;

    gzIn = [bigdata objectForKey:@"gzIn"];
    gzOut = [bigdata objectForKey:@"out"];
    should(gzIn != nil);
    should(gzOut != nil);

    [self testLargeIn:gzIn smallOut:gzOut coder:[OWContentType contentEncodingForString:@"gzip"]];
}

- (void)testSmallBunzip
{
    NSData *bzIn, *bzOut;

    bzIn = [smalldata objectForKey:@"bzIn"];
    bzOut = [smalldata objectForKey:@"gzOut"];
    should(bzIn != nil);
    should(bzOut != nil);

    [self testSmallIn:bzIn smallOut:bzOut coder:[OWContentType contentEncodingForString:@"bzip2"]];
}

- (void)testLargeBunzip
{
    NSData *bzIn, *bzOut;

    bzIn = [bigdata objectForKey:@"bzIn"];
    bzOut = [bigdata objectForKey:@"out"];
    should(bzIn != nil);
    should(bzOut != nil);

    [self testLargeIn:bzIn smallOut:bzOut coder:[OWContentType contentEncodingForString:@"bzip2"]];
}

@end


