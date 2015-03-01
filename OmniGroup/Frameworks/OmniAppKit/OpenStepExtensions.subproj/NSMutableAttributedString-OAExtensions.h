// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSMutableAttributedString-OAExtensions.h 93428 2007-10-25 16:36:11Z kc $

#import <Foundation/NSAttributedString.h>


@interface NSMutableAttributedString (OAExtensions)

+ (NSMutableAttributedString *)tableFromDict:(NSDictionary *)dict keyAttributes:(NSDictionary *)keyAttributes valueAttributes:(NSDictionary *)valueAttributes keySeparatorString:(NSString *)separator indent:(BOOL)flag;
+ (NSMutableAttributedString *)tableFromDict:(NSDictionary *)dict keyAttributes:(NSDictionary *)keyAttributes valueAttributes:(NSDictionary *)valueAttributes indent:(BOOL)flag;

@end
