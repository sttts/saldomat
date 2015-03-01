// Copyright 1999-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/ONTCPDatagramSocket.h 68913 2005-10-03 19:36:19Z kc $

#import "ONSocket.h"

// This class has the same semantics as ONUDPSocket or ONMulticastSocket, but can use any underlying socket as its transport mechanism.
// For example, you might initialize this with a non-blocking TCP socket and use this as a substitute for an ONMulticastSocket if you want to be able to have the same unreliable non-blocking semantics as a multicast or UDP socket (because you're doing a real-time server) but want a somewhat more reliable underlying transport mechanism (because your network connection is otherwise too lossy).

@class ONSocket;

@interface ONTCPDatagramSocket : ONSocket
{
    ONSocket *socket;
    void *writeRemainder;
    unsigned int writeLength;
    unsigned int writePosition;
    void *readRemainder;
    unsigned int readPacketLength;
    unsigned int readLength;   
}

- initWithTCPSocket:(ONSocket *)aSocket;

@end

#import "FrameworkDefines.h"

// Exceptions which may be raised by this class
OmniNetworking_EXTERN NSString *ONTCPDatagramSocketPacketTooLargeExceptionName;
