// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWObjectStreamProcessor.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWContent.h>
#import <OWF/OWObjectStreamCursor.h>
#import <OWF/OWPipeline.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/OWObjectStreamProcessor.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWObjectStreamProcessor

- initWithContent:(OWContent *)initialContent context:(id <OWProcessorContext>)aPipeline;
{
    if (![super initWithContent:initialContent context:aPipeline])
	return nil;

    objectCursor = [[initialContent objectCursor] retain];

    return self;
}

- (void)dealloc;
{
    [objectCursor release];
    [super dealloc];
}

// OWProcessor subclass

- (void)abortProcessing;
{
    [objectCursor abort];
    [super abortProcessing];
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];

    if (objectCursor)
        [debugDictionary setObject:objectCursor forKey:@"objectCursor"];

    return debugDictionary;
}

@end
