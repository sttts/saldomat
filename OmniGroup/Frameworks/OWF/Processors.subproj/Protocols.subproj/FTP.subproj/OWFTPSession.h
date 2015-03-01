// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/FTP.subproj/OWFTPSession.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniFoundation/OFObject.h>

@class NSData, NSMutableArray;
@class ONSocket, ONSocketStream;
@class OWAddress, OWPipeline, OWProcessor;
@protocol OWProcessorContext;

enum OWFTP_ServerFeature { OWFTP_Yes, OWFTP_No, OWFTP_Maybe };

@interface OWFTPSession : OFObject
{
    NSString *sessionCacheKey;
    ONSocketStream *controlSocketStream;
    NSString *currentPath;
    NSString *currentTransferType;
    NSString *systemType;
    NSDictionary *systemFeatures;
    NSString *lastReply;
    unsigned int lastReplyIntValue;
    NSString *lastMessage;
    
    NSMutableArray *failedCredentials;

    OWAddress *ftpAddress;
    id <OWProcessorContext> nonretainedProcessorContext;
    OWProcessor *nonretainedProcessor;
    ONSocket *abortSocket;
    BOOL abortOperation;

    enum OWFTP_ServerFeature serverSupportsMLST;
    enum OWFTP_ServerFeature serverSupportsUTF8;
    enum OWFTP_ServerFeature serverSupportsTVFS;
}

+ (void)readDefaults;
+ (OWFTPSession *)ftpSessionForAddress:(OWAddress *)anAddress;
+ (OWFTPSession *)ftpSessionForNetLocation:(NSString *)aNetLocation;

- initWithNetLocation:(NSString *)aNetLocation;

// Operations
- (void)fetchForProcessor:(OWProcessor *)aProcessor inContext:(id <OWProcessorContext>)aPipeline;
- (void)abortOperation;

@end
