// Copyright 2001-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWAuthSchemeHTTPBasic.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/HTTP.subproj/OWAuthSchemeHTTPBasic.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWAuthSchemeHTTPBasic

- (NSString *)httpHeaderStringForProcessor:(OWHTTPProcessor *)aProcessor;
{
    NSMutableString *buffer;
    NSData *bytes;
    NSString *headerName;
    
//    lastUsedTimeInterval = [NSDate timeIntervalSinceReferenceDate];
    
    buffer = [[NSMutableString alloc] init];
    if (username)
        [buffer appendString:username];
    [buffer appendString:@":"];
    if (password)
        [buffer appendString:password];
        
    
#warning Encoding breakage is possible here
    // TODO: Find out what we're supposed to do if someone has kanji in their username or something
    
    bytes = [buffer dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO];
    [buffer release];
    if (bytes == nil) {
        [NSException raise:@"Can't Authorize" format:NSLocalizedStringFromTableInBundle(@"Username or password contains characters which cannot be encoded", @"OWF", [OWAuthSchemeHTTPBasic bundle], @"authorization error")];
    }
    
    if (type == OWAuth_HTTP)
        headerName = @"Authorization";
    else if (type == OWAuth_HTTP_Proxy)
        headerName = @"Proxy-Authorization";
    else
        headerName = @"X-Bogus-Header"; // TODO
        
    return [NSString stringWithFormat:@"%@: Basic %@",
            headerName,
            [bytes base64String]];
}

- (BOOL)appliesToHTTPChallenge:(NSDictionary *)challenge
{
    // Correct scheme?
    if ([[challenge objectForKey:@"scheme"] caseInsensitiveCompare:@"basic"] != NSOrderedSame)
        return NO;
    
    // Correct realm?
    if (realm && [realm caseInsensitiveCompare:[challenge objectForKey:@"realm"]] != NSOrderedSame)
        return NO;
    
    return YES;
}
        
@end
