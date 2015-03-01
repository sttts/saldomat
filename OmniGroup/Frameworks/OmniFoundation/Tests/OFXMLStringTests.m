// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/OFXMLString.h>

#import <SenTestingKit/SenTestingKit.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/Tests/OFXMLStringTests.m 93494 2007-10-26 18:43:00Z kc $");

@interface OFXMLStringTests : SenTestCase
@end

#define QUOTE_NEWLINE(src, dest, flags, nl) do { \
    NSString *q = OFXMLCreateStringWithEntityReferencesInCFEncoding(src, flags, nl, kCFStringEncodingUTF8); \
    STAssertEqualObjects(q, dest, @""); \
    [q release]; \
} while (0)
#define QUOTE(src, dest, flags) QUOTE_NEWLINE((src), (dest), (flags), nil)

@implementation OFXMLStringTests

- (void)testDefaultQuoting;
{
    QUOTE(@"&", @"&amp;", OFXMLBasicEntityMask);
    QUOTE(@"<", @"&lt;", OFXMLBasicEntityMask);
    QUOTE(@">", @"&gt;", OFXMLBasicEntityMask);
    QUOTE(@"'", @"&apos;", OFXMLBasicEntityMask);
    QUOTE(@"\"", @"&quot;", OFXMLBasicEntityMask);
    QUOTE(@"\n", @"\n", OFXMLBasicEntityMask);
}

- (void)testHTMLQuoting;
{
    QUOTE(@"&", @"&amp;", OFXMLHTMLEntityMask);
    QUOTE(@"<", @"&lt;", OFXMLHTMLEntityMask);
    QUOTE(@">", @"&gt;", OFXMLHTMLEntityMask);
    QUOTE(@"'", @"&#39;", OFXMLHTMLEntityMask);
    QUOTE(@"\"", @"&quot;", OFXMLHTMLEntityMask);
    QUOTE(@"\n", @"\n", OFXMLHTMLEntityMask);
}

- (void)testCharacterQuoting;
{
    QUOTE(@"'", @"&#39;", (OFXMLCharacterFlagWriteCharacterEntity << OFXMLAposCharacterOptionsShift));
    QUOTE(@"\"", @"&#34;", (OFXMLCharacterFlagWriteCharacterEntity << OFXMLQuotCharacterOptionsShift));
}

- (void)testNoQuoting;
{
    QUOTE(@"'", @"'", (OFXMLCharacterFlagWriteUnquotedCharacter << OFXMLAposCharacterOptionsShift));
    QUOTE(@"\"", @"\"", (OFXMLCharacterFlagWriteUnquotedCharacter << OFXMLQuotCharacterOptionsShift));
}

- (void)testNewlineReplacement;
{
    QUOTE_NEWLINE(@"\n", @"!", OFXMLBasicWithNewlinesEntityMask, @"!");
    QUOTE_NEWLINE(@"\na\nb\n", @"!a!b!", OFXMLBasicWithNewlinesEntityMask, @"!");

    QUOTE_NEWLINE(@"\n", @"!", OFXMLHTMLWithNewlinesEntityMask, @"!");
    QUOTE_NEWLINE(@"\na\nb\n", @"!a!b!", OFXMLHTMLWithNewlinesEntityMask, @"!");
}

@end
