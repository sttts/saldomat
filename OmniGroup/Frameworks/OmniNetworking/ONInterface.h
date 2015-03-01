// Copyright 1999-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/ONInterface.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniBase/OBObject.h>

// ONInterface represents a network interface.  This might be a ethernet card, the loopback interface, a slip or ppp link or the like.

@class ONHostAddress;
@class NSArray;
@class NSData;

typedef enum _ONInterfaceCategory {
    ONUnknownInterfaceCategory,
    ONEtherInterfaceCategory,        // Ethernet, FDDI, 802.11, etc.
    ONPPPInterfaceCategory,          // PPP, SLIP
    ONLoopbackInterfaceCategory,     // loopback interfaces
    ONTunnelInterfaceCategory        // Tunnels and encapsulation interfaces
} ONInterfaceCategory;

@interface ONInterface : OBObject
{
    NSString *name;
    NSArray *interfaceAddresses;
    /* Not sure if this is the right way to represent this. Possibly "destinationAddresses" should be an array instead of a dictionary. Possibly these dictionaries need to be able to represent multiple values for a key. */
    NSDictionary *destinationAddresses; // for point-to-point links
    NSDictionary *broadcastAddresses;   // for shared-medium links, e.g. ethernet
    NSDictionary *netmaskAddresses;

    ONInterfaceCategory interfaceCategory;
    int interfaceType;
    unsigned int maximumTransmissionUnit;
    unsigned int flags;
    unsigned int index;
}

+ (NSArray *)getInterfaces:(BOOL)rescan;
+ (NSArray *)interfaces;

- (NSString *)name;
- (ONHostAddress *)interfaceAddress;  // Returns one IPv4 address, for backwards compatibility
- (ONHostAddress *)linkLayerAddress;  // Returns one ONLinkLayerAddress (or nil...)

- (NSArray *)addresses;
- (ONHostAddress *)destinationAddressForAddress:(ONHostAddress *)localAddress;
- (ONHostAddress *)broadcastAddressForAddress:(ONHostAddress *)localAddress;
- (ONHostAddress *)netmaskAddressForAddress:(ONHostAddress *)localAddress;

- (ONInterfaceCategory)interfaceCategory;
- (int)interfaceType;   // RFC1573-style interface type number, e.g. IFT_ETHER
- (int)index;

- (unsigned int)maximumTransmissionUnit;

- (BOOL)isUp;
- (BOOL)supportsBroadcast;
- (BOOL)isLoopback;
- (BOOL)isPointToPoint;
- (BOOL)supportsAddressResolutionProtocol;
- (BOOL)supportsPromiscuousMode;
- (BOOL)isSimplex;
- (BOOL)supportsMulticast;

@end
