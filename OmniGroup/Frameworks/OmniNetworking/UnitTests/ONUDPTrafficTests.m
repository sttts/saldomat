// Copyright 2003-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniNetworking/OmniNetworking.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <SenTestingKit/SenTestingKit.h>
#include <unistd.h>
#include <sys/socket.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/UnitTests/ONUDPTrafficTests.m 75916 2006-06-01 16:16:00Z bungi $");

const char *s1 = "This is some test data.";
const char *s2 = "This is also some test data. It's a bit longer.";
#define S3_LEN (1040)
const char *s4 = "Would you like another packet? It is WAFFER THIN!";

@interface ONUDPTrafficTests : SenTestCase
{
    int addressFamily;
    
    ONUDPSocket *huey, *dewie, *louie;

    char s3[S3_LEN];
}

@end

@implementation ONUDPTrafficTests

// Init and dealloc

- (id) initWithInvocation:(NSInvocation *) anInvocation;
{
    self = [super initWithInvocation:anInvocation];
    addressFamily = AF_UNSPEC;
    return self;
}

- (void)setUp;
{
    huey = [[ONUDPSocket socket] retain];
    dewie = [[ONUDPSocket socket] retain];
    louie = [[ONUDPSocket socket] retain];

    if (addressFamily != AF_UNSPEC) {
        [huey setAddressFamily:addressFamily];
        [dewie setAddressFamily:addressFamily];
        [louie setAddressFamily:addressFamily];
    }
}

- (void)dealloc;
{
    [huey release];
    [dewie release];
    [louie release];
    [super dealloc];
}

- (ONHostAddress *)loopback
{
    if (addressFamily == AF_UNSPEC)
        return [ONHostAddress loopbackAddress];
    else if (addressFamily == AF_INET)
        return [ONHostAddress hostAddressWithNumericString:@"127.0.0.1"];
    else if (addressFamily == AF_INET6)
        return [ONHostAddress hostAddressWithNumericString:@"::1"];
    else
        return nil;
}

- (void)testUDPLoopback
{
    ONPortAddress *addrD, *addrDLoop;
    unsigned len;
    NSData *rd;
    
    shouldnt([dewie isConnected]);
    [dewie setLocalPortNumber];

    addrD = [[ONPortAddress alloc] initWithHostAddress:[self loopback] portNumber:[dewie localAddressPort]];
    should(addrD != nil);
    [addrD autorelease];

    shouldnt([dewie isConnected]);
    should([dewie remoteAddress] == nil);

    len = [dewie writeBytes:strlen(s4) fromBuffer:s4 toPortAddress:addrD];
    should(len == strlen(s4));

    shouldnt([dewie isConnected]);
    should([dewie remoteAddress] == nil);

    rd = [dewie readData];
    shouldnt([dewie isConnected]);
    should([dewie remoteAddress] != nil);
    addrDLoop = [dewie remoteAddress];

    should(rd != nil);
    should([rd length] == len);
    should(memcmp([rd bytes], s4, len) == 0);

    // NSLog(@"Sent to: %@ Received from: %@", addrD, addrDLoop);
    should([addrDLoop isEqual:addrD]);
}

- (void)testConnectedUDP
{
    ONPortAddress *addrH, *addrL;
    unsigned int len, res;
    NSData *rd;

    should(huey != nil);
    should(louie != nil);

    [huey setLocalPortNumber];
    [louie setLocalPortNumber];
    addrH = [huey localAddress];
    addrL = [louie localAddress];

    shouldnt(addrH == nil);
    shouldnt(addrL == nil);
    shouldnt([addrH isEqual:addrL]);
    shouldnt([huey localAddressPort] == [louie localAddressPort]);

    shouldnt([huey isConnected]);
    [huey connectToAddress:[self loopback] port:[louie localAddressPort]];
    should([huey isConnected]);
    shouldnt([louie isConnected]);
    [louie connectToAddress:[self loopback] port:[huey localAddressPort]];
    should([louie isConnected]);
    should([huey isConnected]);
    /* The host parts won't typically be the same because they'll be bound to the wildcard address locally and the loopback address remotely. So just check the port numbers. */
    should([huey localAddressPort] == [louie remoteAddressPort]);
    should([louie localAddressPort] == [huey remoteAddressPort]);
    // NSLog(@"Huey: local=%@ remote=%@", [huey localAddress], [huey remoteAddress]);
    // NSLog(@"Louie: local=%@ remote=%@", [louie localAddress], [louie remoteAddress]);

    len = strlen(s1);
    res = [huey writeBytes:len fromBuffer:s1];
    should(res == len);

    len = strlen(s2);
    res = [louie writeBytes:len fromBuffer:s2];
    should(res == len);

    rd = [huey readData];
    should(rd != nil);
    should([rd length] == strlen(s2));
    should(memcmp([rd bytes], s2, strlen(s2)) == 0);

    rd = [louie readData];
    should(rd != nil);
    should([rd length] == strlen(s1));
    should(memcmp([rd bytes], s1, strlen(s1)) == 0);
}

- (void)setAddressFamily:(int)af
{
    addressFamily = af;
}

+ (id) defaultTestSuite
{
    SenTestSuite *all = [SenTestSuite /* emptyTestSuiteForTestCaseClass:self */ testSuiteWithName:[self description]];
    struct { int af; char *n; } variations[3] = { { AF_UNSPEC, "AF_UNSPEC" }, { AF_INET, "AF_INET" }, { AF_INET6, "AF_INET6" } };
    int i;
    
    for(i = 0; i < 3; i++) {
        SenTestSuite *some;
        NSArray *invocations;
        unsigned int invocationIndex;
        int af = variations[i].af;
        
        invocations = [self testInvocations];
        some = [SenTestSuite testSuiteWithName:[NSString stringWithFormat:@"%@ (%s)", [all name], variations[i].n]];
        for(invocationIndex = 0; invocationIndex < [invocations count]; invocationIndex ++) {
            ONUDPTrafficTests *test = [self testCaseWithInvocation:[invocations objectAtIndex:invocationIndex]];
            if (af != AF_UNSPEC)
                [test setAddressFamily:af];
            [some addTest:test];
        }
        [all addTest:some];
    }
    
    return all;
}

@end
