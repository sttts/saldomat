// Copyright 2000-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWParameterizedContentType.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWContentType.h>
#import <OWF/OWHeaderDictionary.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWParameterizedContentType.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWParameterizedContentType

+ (OWParameterizedContentType *)contentTypeForString:(NSString *)aString
{
    NSString *bareType;
    OFMultiValueDictionary *contentParameters;
    OWParameterizedContentType *returnValue;

    aString = [aString stringByRemovingSurroundingWhitespace];
    if ([NSString isEmptyString:aString])
        return nil;

    if ([aString containsString:@";"]) {
        contentParameters = [[OFMultiValueDictionary alloc] init];
        bareType = [OWHeaderDictionary parseParameterizedHeader:aString intoDictionary:contentParameters valueChars:nil];
    } else {
        contentParameters = nil;
        bareType = aString;
    }
    
    returnValue = [[OWParameterizedContentType alloc] initWithContentType:[OWContentType contentTypeForString:bareType] parameters:contentParameters];
    
    [contentParameters release];
    
    return [returnValue autorelease];
}

- initWithContentType:(OWContentType *)aType;
{
    return [self initWithContentType:aType parameters:nil];
}

- initWithContentType:(OWContentType *)aType parameters:(OFMultiValueDictionary *)someParameters;
{
    if ([super init] == nil)
        return nil;
    
    contentType = [aType retain];
    _parameterLock = [[NSLock alloc] init];
    if (someParameters != nil)
        _parameters = [someParameters retain];
    else
        _parameters = nil;
    
    return self;
}

- (void)dealloc;
{
    [contentType release];
    [_parameterLock release];
    [_parameters release];
    [super dealloc];
}

// API

- (OWContentType *)contentType;
{
    return contentType;
}

- (OFMultiValueDictionary *)parameters
{
    OFMultiValueDictionary *result;
    
    [_parameterLock lock];
    result = [_parameters mutableCopy];
    [_parameterLock unlock];
    return [result autorelease];
}

- (NSString *)objectForKey:(NSString *)aName;
{
    NSString *object;

    [_parameterLock lock];
    object = [[_parameters lastObjectForKey:aName] retain];
    [_parameterLock unlock];
    return [object autorelease];
}

- (void)setObject:(NSString *)newValue forKey:(NSString *)aName;
{
    [_parameterLock lock];
    if (_parameters == nil)
        _parameters = [[OFMultiValueDictionary alloc] init];
    [_parameters addObject:newValue forKey:aName];
    [_parameterLock unlock];
}

- (NSString *)contentTypeString;
{
    NSString *contentTypeString;

    contentTypeString = [contentType contentTypeString];
    [_parameterLock lock];
    if (_parameters != nil) {
        NSString *parameterString;
        
        parameterString = [OWHeaderDictionary formatHeaderParameters:_parameters onlyLastValue:YES];
        if ([parameterString length] > 0)
            contentTypeString = [NSString stringWithStrings:contentTypeString, @"; ", parameterString, nil];
    }
    [_parameterLock unlock];
    return contentTypeString;
}

- mutableCopyWithZone:(NSZone *)newZone
{
    OWParameterizedContentType *copy;
    OFMultiValueDictionary *copiedParameters;
    
    [_parameterLock lock];
    copiedParameters = [_parameters mutableCopyWithZone:newZone];
    [_parameterLock unlock];
    copy = [[[self class] allocWithZone:newZone] initWithContentType:contentType parameters:copiedParameters];
    [copiedParameters release];
    
    return copy;
}

// OBObject subclass

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    [debugDictionary setObject:[contentType contentTypeString] forKey:@"contentType"];
    if (_parameters != nil)
        [debugDictionary setObject:_parameters forKey:@"parameters"];
    return debugDictionary;
}

@end
