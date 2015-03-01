// Copyright 2003-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/XML/OFXMLDocument.h 98770 2008-03-17 22:25:33Z kc $

#import <OmniFoundation/OFXMLIdentifierRegistry.h>

#import <CoreFoundation/CFURL.h>
#import <OmniFoundation/OFXMLWhitespaceBehavior.h>

@class OFXMLCursor, OFXMLElement, OFXMLWhitespaceBehavior;
@class NSArray, NSMutableArray, NSDate, NSData, NSURL, NSError;

@interface OFXMLDocument : OFXMLIdentifierRegistry
{
    // For the initial XML PI
    NSString *_versionString;
    BOOL _standalone;
    CFStringEncoding _stringEncoding;

    // Custom PIs
    NSMutableArray         *_processingInstructions;
    
    // DTD declaration
    CFURLRef                _dtdSystemID;
    NSString               *_dtdPublicID;
    
    // Main document content
    OFXMLElement *_rootElement;
    
    // Building
    NSMutableArray *_elementStack;
    
    // Error handling
    NSArray *_loadWarnings; // Array of NSErrors.  Set as we read a document from existing XML.
    
    // Whitespace handling; covering what we could do in DTD with xml:space.
    OFXMLWhitespaceBehavior *_whitespaceBehavior;
    
    // Support for callers to squirrel away state and then extract it again.
    NSMutableDictionary *_userObjects;
}

- initWithRootElement:(OFXMLElement *)rootElement
          dtdSystemID:(CFURLRef)dtdSystemID
          dtdPublicID:(NSString *)dtdPublicID
   whitespaceBehavior:(OFXMLWhitespaceBehavior *)whitespaceBehavior
       stringEncoding:(CFStringEncoding)stringEncoding
                error:(NSError **)outError;

- initWithRootElementName:(NSString *)rootElementName
              dtdSystemID:(CFURLRef)dtdSystemID
              dtdPublicID:(NSString *)dtdPublicID
       whitespaceBehavior:(OFXMLWhitespaceBehavior *)whitespaceBehavior
           stringEncoding:(CFStringEncoding)stringEncoding
                    error:(NSError **)outError;

- initWithRootElementName:(NSString *)rootElementName
             namespaceURL:(NSURL *)rootElementNameSpace
       whitespaceBehavior:(OFXMLWhitespaceBehavior *)whitespaceBehavior
           stringEncoding:(CFStringEncoding)stringEncoding
                    error:(NSError **)outError;

- initWithContentsOfFile:(NSString *)path whitespaceBehavior:(OFXMLWhitespaceBehavior *)whitespaceBehavior error:(NSError **)outError;

- initWithData:(NSData *)xmlData whitespaceBehavior:(OFXMLWhitespaceBehavior *)whitespaceBehavior error:(NSError **)outError;
- initWithData:(NSData *)xmlData whitespaceBehavior:(OFXMLWhitespaceBehavior *)whitespaceBehavior defaultWhitespaceBehavior:(OFXMLWhitespaceBehaviorType)defaultWhitespaceBehavior error:(NSError **)outError;

- (OFXMLWhitespaceBehavior *) whitespaceBehavior;
- (CFURLRef) dtdSystemID;
- (NSString *) dtdPublicID;
- (CFStringEncoding) stringEncoding;

- (NSArray *)loadWarnings;

- (NSData *)xmlData;
- (NSData *)xmlDataWithDefaultWhiteSpaceBehavior:(OFXMLWhitespaceBehaviorType)defaultWhiteSpaceBehavior;
- (NSData *)xmlDataAsFragment;
- (NSData *)xmlDataForElements:(NSArray *)elements asFragment:(BOOL)asFragment;
- (NSData *)xmlDataForElements:(NSArray *)elements asFragment:(BOOL)asFragment defaultWhiteSpaceBehavior:(OFXMLWhitespaceBehaviorType)defaultWhiteSpaceBehavior;
- (BOOL)writeToFile:(NSString *)path;

- (unsigned int)processingInstructionCount;
- (NSString *)processingInstructionNameAtIndex:(unsigned int)piIndex;
- (NSString *)processingInstructionValueAtIndex:(unsigned int)piIndex;
- (void)addProcessingInstructionNamed:(NSString *)piName value:(NSString *)piValue;

- (OFXMLElement *) rootElement;

// User objects
- (id)userObjectForKey:(NSString *)key;
- (void)setUserObject:(id)object forKey:(NSString *)key;

// Writing conveniences
- (OFXMLElement *) pushElement: (NSString *) elementName;
- (void) popElement;
- (OFXMLElement *) topElement;
- (void) appendString: (NSString *) string;
- (void) appendString: (NSString *) string quotingMask: (unsigned int) quotingMask newlineReplacment: (NSString *) newlineReplacment;
- (void) setAttribute: (NSString *) name string: (NSString *) value;
- (void) setAttribute: (NSString *) name value: (id) value;
- (void) setAttribute: (NSString *) name integer: (int) value;
- (void) setAttribute: (NSString *) name real: (float) value;  // "%g"
- (void) setAttribute: (NSString *) name real: (float) value format: (NSString *) formatString;
- (OFXMLElement *)appendElement:(NSString *)elementName;
- (OFXMLElement *)appendElement:(NSString *)elementName containingString:(NSString *) contents;
- (OFXMLElement *)appendElement:(NSString *)elementName containingInteger:(int) contents;
- (OFXMLElement *)appendElement:(NSString *)elementName containingReal:(float) contents; // "%g"
- (OFXMLElement *)appendElement:(NSString *)elementName containingReal:(float) contents format:(NSString *)formatString;
- (OFXMLElement *)appendElement:(NSString *)elementName containingDate:(NSDate *)date; // XML Schema / ISO 8601.

// Reading conveniences
- (OFXMLCursor *) createCursor;

@end
