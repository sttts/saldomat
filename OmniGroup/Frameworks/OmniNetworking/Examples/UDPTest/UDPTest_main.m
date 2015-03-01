// Copyright 1997-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniNetworking/OmniNetworking.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/Examples/UDPTest/UDPTest_main.m 79079 2006-09-07 22:35:32Z kc $")

volatile void usage(const char *pgm)
{
    fprintf(stderr,
            "usage: %s [-send udp-host | -receive] udp-port\n",
            pgm);
    exit(1);
}

static void _sendLoop(ONPortAddress *portAddress);
static void _receiveLoop(ONHostAddress *hostAddress, unsigned short port);

int main (int argc, const char *argv[])
{
    NSAutoreleasePool *pool;
    BOOL               isSending = NO;
    NSString          *hostName;
    unsigned short     hostPort;
    ONHostAddress     *hostAddress;
    ONPortAddress     *portAddress;
    ONHost            *host;
    
    pool = [[NSAutoreleasePool alloc] init];

    if (argc < 2)
        usage(argv[0]);

    if (!strcmp("-send", argv[1])) {
        if (argc != 4)
            usage(argv[0]);
        
        hostName = [[NSString alloc] initWithCString: argv[2]];
        hostPort   = atoi(argv[3]);
        isSending = YES;
    } else if (!strcmp("-receive", argv[1])) {
        if (argc != 3)
            usage(argv[0]);

        hostName = [ONHost localHostname];
        hostPort   = atoi(argv[2]);
        isSending = NO;
    } else {
        usage(argv[0]);
        return 1;
    }


    
    host = [ONHost hostForHostname: hostName];
    if (![[host addresses] count]) {
        fprintf(stderr, "Cannot determine an address for %s\n", argv[2]);
        exit(1);
    }

    hostAddress = [[host addresses] objectAtIndex: 0];
    portAddress = [[ONPortAddress alloc] initWithHostAddress: hostAddress
                                                  portNumber: hostPort];

    if (isSending)
        _sendLoop(portAddress);
    else
        _receiveLoop(hostAddress, hostPort);
    
    [pool release];
    exit(0);       // insure the process exit status is 0
    return 0;      // ...and make main fit the ANSI spec.
}

static void _sendLoop(ONPortAddress *portAddress)
{
    NSFileHandle      *stdinHandle;
    NSData            *data;
    ONUDPSocket       *udpSocket;

    udpSocket = (ONUDPSocket *)[ONUDPSocket socket];
    [udpSocket setAllowsBroadcast: YES]; // In  case we are sending to the broadcast address
    
    stdinHandle = [NSFileHandle fileHandleWithStandardInput];

    while (YES) {
        NSAutoreleasePool *pool;

        pool = [[NSAutoreleasePool alloc] init];

        data = [stdinHandle availableData];

        // NSFileHandle will return an empty data upon EOF rather than nil.
        // Apparently NSFileHandle has a bug in that if you read on a file handle
        // that has already reached EOF, it will hang in read() forever.
        // (This is of as OpenStep 4.2).
        if (![data length])
            break;
        
        [udpSocket writeBytes: [data length]
                   fromBuffer: [data bytes]
                toPortAddress: portAddress];
        [pool release];
    }
}

static void _receiveLoop(ONHostAddress *hostAddress, unsigned short port)
{
    NSFileHandle      *stdoutHandle;
    NSMutableData     *data;
    ONUDPSocket       *udpSocket;
    unsigned int       maxDataLength;
    
    udpSocket = (ONUDPSocket *)[ONUDPSocket socket];
    [udpSocket setLocalPortNumber: port allowingAddressReuse: YES];
    [udpSocket setAllowsBroadcast: YES]; // In  case we are sending to the broadcast address

    maxDataLength = 256;
    data          = [NSMutableData dataWithLength: maxDataLength];
    stdoutHandle  = [NSFileHandle fileHandleWithStandardOutput];
    while (YES) {
        NSAutoreleasePool *pool;
        unsigned int       length;
        NSString          *note;

        pool = [[NSAutoreleasePool alloc] init];
        
        // Have to set the data to its maximum length.  Otherwise,
        // when we come around this loop multiple times, the setLength:
        // below might be lengthening the data which would cause NSData
        // to zero out all of the bytes between the old length and the
        // new length.
        [data setLength: maxDataLength];
        length = [udpSocket readBytes: maxDataLength
                           intoBuffer: [data mutableBytes]];
        [data setLength: length];

        note = [NSString stringWithFormat: @"Received packet from %@:%d:\n", [udpSocket remoteAddressHost], [udpSocket remoteAddressPort]];
        [stdoutHandle writeData: [note dataUsingEncoding: NSASCIIStringEncoding]];
        [stdoutHandle writeData: data];

        [pool release];
    }
}
