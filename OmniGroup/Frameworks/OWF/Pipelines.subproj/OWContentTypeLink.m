// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWContentTypeLink.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWContentType.h>
#import <OWF/OWProcessorDescription.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWContentTypeLink.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWContentTypeLink

- initWithProcessorDescription:(OWProcessorDescription *)aProcessorDescription sourceContentType:(OWContentType *)fromContentType targetContentType:(OWContentType *)toContentType cost:(float)aCost;
{
    if (![super init])
	return nil;

    processorDescription = [aProcessorDescription retain];
    sourceContentType = fromContentType;
    targetContentType = toContentType;
    cost = aCost;

    return self;
}

- (void)dealloc;
{
    [processorDescription release];
    [super dealloc];
}

//

- (OWContentType *)sourceContentType;
{
    return sourceContentType;
}

- (OWContentType *)targetContentType;
{
    return targetContentType;
}

- (OWProcessorDescription *) processorDescription;
{
    return processorDescription;
}

- (NSString *)processorClassName;
{
    return [processorDescription processorClassName];
}

- (float)cost;
{
    return cost;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];

    [debugDictionary setObject:[sourceContentType contentTypeString] forKey:@"sourceContentType"];
    [debugDictionary setObject:[targetContentType contentTypeString] forKey:@"targetContentType"];
    [debugDictionary setObject:processorDescription forKey:@"processorDescription"];
    [debugDictionary setObject:[NSString stringWithFormat:@"%1.0f", cost] forKey:@"cost"];

    return debugDictionary;
}

@end
