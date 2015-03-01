// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/ONSocketStream.h 66168 2005-07-28 17:34:52Z kc $

#import <OmniBase/OBObject.h>

@class NSData, NSMutableData;
@class NSMutableArray;
@class NSString;
@class ONSocket;

#import <Foundation/NSString.h> // For NSStringEncoding

@interface ONSocketStream : OBObject
{
    ONSocket *socket;
    
    NSMutableData *readBuffer;
    BOOL readBufferContainsEOF;

    // BOOL socketPushDisabled;
    unsigned int writeBufferingCount;   // count of nested -beginBuffering / -endBuffering calls
    unsigned int totalBufferedBytes;    // number of bytes in writeBuffer
    unsigned int firstBufferOffset;     // number of bytes from first buffer to ignore (not counted in totalBufferedBytes)
    NSMutableArray *writeBuffer;        // array of NSDatas to write
}

+ streamWithSocket:(ONSocket *)aSocket;
- initWithSocket:(ONSocket *)aSocket;
- (ONSocket *)socket;
- (BOOL)isReadable;

- (void)setReadBuffer:(NSMutableData *)aData;
- (void)clearReadBuffer;
- (void)advanceReadBufferBy:(unsigned int)advanceAmount;

- (NSData *)readData;
- (NSData *)readDataOfLength:(unsigned int)length;
- (NSData *)readDataWithMaxLength:(unsigned int)length;

- (unsigned int)readBytesWithMaxLength:(unsigned int)length intoBuffer:(void *)buffer;
- (void)readBytesOfLength:(unsigned int)length intoBuffer:(void *)buffer;
- (BOOL)skipBytes:(unsigned int)length;

- (void)writeData:(NSData *)theData;

// Write buffering. When buffering is enabled, writes are accumulated by the ONSocketStream until either a threshold has been reached or buffering has been turned off. beginBuffering/endBuffering calls must be properly balanced.
- (void)beginBuffering;
- (void)endBuffering;

// String I/O routines. Technically these don't really belong here, and callers should use the more sophisticated character conversion code in OmniFoundation or OWF. However, it's extremely convenient for many internet protocols to be able to do simple string-oriented operations. Callers should be aware that these routines might not behave correctly when dealing with unusual string encodings (anything which doesn't look much like ASCII).

- (NSString *)readString;
    // Note:  not currently reliable if the stringEncoding is set to a multibyte encoding, because we  don't know if a character is split across a buffer boundary.

- (unsigned)getLengthOfNextLine:(unsigned int *)eolBytes;
    // Low-level line parsing routine. This returns the number of bytes in the next line, blocking if necessary to read a full EOL marker. If eolBytes is not NULL, it is filled in with the length of the EOL marker; in any case, the EOL marker is included in the return value of this method. This routine is quite liberal in its interpretation of EOL, and should accept most EOL markers seen in practice. It should work with ASCII, the ISO 8859 character sets, and UTF-8 (but not UTF-16 or EBCDIC). Returns 0 at EOF.

- (NSString *)readLineAndAdvance:(BOOL)shouldAdvance;  // Reads a line and interprets it as a string according to the current string encoding, returning the result. Does not include any trailing EOL characters. Returns nil at EOF.
- (NSString *)readLine;  // equivalent to readLineAndAdvance:YES
- (NSString *)peekLine;  // equivalent to readLineAndAdvance:NO

- (void)writeString:(NSString *)aString;
- (void)writeFormat:(NSString *)aFormat, ...;

- (NSStringEncoding)stringEncoding;
- (void)setStringEncoding:(NSStringEncoding)aStringEncoding;

@end
