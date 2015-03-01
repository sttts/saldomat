// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/HTTP.subproj/OWHTTPProcessor.h 68913 2005-10-03 19:36:19Z kc $

#import "OWAddressProcessor.h"
#import "OWHTTPSession.h" // For HTTPStatus

@class OWAuthorizationCredential;
@class OWContent;
@class OWDataStream;
@class OWHTTPSessionQueue;

@interface OWHTTPProcessor : OWAddressProcessor
{
    OWHTTPSessionQueue *queue;
    OWDataStream *dataStream;
    OWContent *httpContent;
    unsigned httpContentFlags;
    NSArray *credentials;
    HTTPStatus httpStatusCode;
}

- (Class)sessionQueueClass;
- (void)startProcessingInHTTPSessionQueue:(OWHTTPSessionQueue *)queue;

- (void)handleSessionException:(NSException *)anException;

- (OWContent *)content;
- (OWDataStream *)dataStream;
- (void)setDataStream:(OWDataStream *)aDataStream;
- (void)invalidateForHeaders:(OWHeaderDictionary *)headerDict;
- (void)addHeaders:(OWHeaderDictionary *)headerDict;
- (void)markEndOfHeaders;
- (void)addContent;
- (void)flagResult:(unsigned)someFlags;
- (unsigned)flags;

- (NSArray *)credentials;
- (void)addCredential:(OWAuthorizationCredential *)newCredential;

- (void)setHTTPStatusCode:(HTTPStatus)newStatusCode;

@end

