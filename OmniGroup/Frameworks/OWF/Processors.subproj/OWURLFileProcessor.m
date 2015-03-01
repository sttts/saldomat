// Copyright 1999-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWURLFileProcessor.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWContent.h>
#import <OWF/OWContentType.h>
#import <OWF/OWAddress.h>
#import <OWF/OWDataStreamProcessor.h>
#import <OWF/OWDataStreamCharacterCursor.h>
#import <OWF/OWPipeline.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/OWURLFileProcessor.m 68913 2005-10-03 19:36:19Z kc $")

static OWContentType *sourceContentType;

@implementation OWURLFileProcessor

+ (void)initialize;
{
    static BOOL initialized = NO;

    [super initialize];
    if (initialized)
        return;
    initialized = YES;

    sourceContentType = [OWContentType contentTypeForString:@"application/x-url"];
}

+ (void)didLoad;
{
    [self registerProcessorClass:self fromContentType:sourceContentType toContentType:[OWContentType wildcardContentType] cost:1.0 producingSource:NO];
}

+ (OWContentType *)sourceContentType;
{
    return sourceContentType;
}

- (void)process;
{
    NSString *line;
    OWAddress *anAddress;

    line = [characterCursor readLine];

    // Internet Explorer writes .url files that look like this:
    //
    // [InternetShortcut]
    // URL=http://www.omnigroup.com/

    if ([line isEqualToString:@"[InternetShortcut]"]) {
        line = [characterCursor readLine];
        if ([line hasPrefix:@"URL="])
            line = [line substringFromIndex:4];
    }

    anAddress = [OWAddress addressForDirtyString:line];
    [pipeline addContent:[OWContent contentWithAddress:anAddress]
           fromProcessor:self
                   flags:OWProcessorContentNoDiskCache|OWProcessorTypeRetrieval];
}

@end
