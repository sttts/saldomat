// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWAbstractContent.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWContentInfo.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWAbstractContent.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWAbstractContent

// Init and dealloc

- init;
{
    NSString *className, *displayName;

    // TODO: should we localize this hack? Arguably there should be a class name -> displayName mapping in the localizable .strings tables.

    className = NSStringFromClass(isa);
    if ([className hasPrefix:@"OW"] ||
        [className hasPrefix:@"OI"] ||
        [className hasPrefix:@"OH"])
        displayName = [className substringFromIndex:2];
    else
        displayName = className;

    return [self initWithName:displayName];
}

- initWithName:(NSString *)name;
{
    if (![super init])
        return nil;

//    contentInfo = [[OWContentInfo alloc] initWithContent:self typeString:name];

    return self;
}

- (void)dealloc;
{
//    [contentInfo nullifyContent];
//    [contentInfo release];

    [super dealloc];
}


// OWContent protocol

- (BOOL)endOfData;
{
    OBRequestConcreteImplementation(self, _cmd);
}

//- (OWContentInfo *)contentInfo;
//{
//    return contentInfo;
//}

- (BOOL)contentIsValid;
{
    OBRequestConcreteImplementation(self, _cmd);
}

@end
