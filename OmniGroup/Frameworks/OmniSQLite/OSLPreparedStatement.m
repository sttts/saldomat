// Copyright 2004-2005, 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSLPreparedStatement.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>

#import "OSLDatabaseController.h"
#import "sqlite3.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSQLite/OSLPreparedStatement.m 98218 2008-03-04 20:59:21Z kc $")

@interface OSLDatabaseController (Private)
- (void *)_database;
@end

@implementation OSLPreparedStatement

- initWithSQL:(NSString *)someSQL statement:(void *)preparedStatement databaseController:(OSLDatabaseController *)aDatabaseController;
{
    [super init];
    sql = [someSQL retain];
    statement = preparedStatement;
    databaseController = [aDatabaseController retain];
    
    return self;
}

- (void)dealloc;
{
    sqlite3_finalize(statement);
    [databaseController release];
    [super dealloc];
}

- (void)reset;
{
    bindIndex = 0;
    sqlite3_reset(statement);
}

#ifdef DEBUG_kc
#define DebugLog NSLog
#else
#define DebugLog(...) {}
#endif

- (NSDictionary *)step;
{
    DebugLog(@"STEP %@", sql);
    int errorCode = sqlite3_step(statement);
    
    if (errorCode == SQLITE_ROW) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        unsigned int columnIndex = sqlite3_data_count(statement);
        id value;
        
        while (columnIndex--) {
            switch(sqlite3_column_type(statement, columnIndex)) {
                case SQLITE_INTEGER:
                    value = [NSNumber numberWithLongLong:sqlite3_column_int64(statement, columnIndex)];
                    break;
                case SQLITE_FLOAT:
                    value = [NSNumber numberWithDouble:sqlite3_column_double(statement, columnIndex)];
                    break;
                case SQLITE_TEXT:
                case SQLITE_BLOB:
                    value = [NSData dataWithBytes:sqlite3_column_blob(statement, columnIndex) length:sqlite3_column_bytes(statement, columnIndex)];
                    break;
                case SQLITE_NULL:
                default:
                    continue;
            }
            NSString *key = [NSString stringWithUTF8String:sqlite3_column_name(statement, columnIndex)];
            [dictionary setObject:value forKey:key];
        }
#ifdef DEBUG0
	DebugLog(@"-> %@", dictionary);
#else
        DebugLog(@"-> %u columns", sqlite3_data_count(statement));
#endif
        return dictionary;
    }
    if (errorCode != SQLITE_DONE)
        NSLog(@"ERROR executing sql %@: %s", sql, sqlite3_errmsg([databaseController _database]));
    
    return nil;
}

- (void)bindInt:(int)integer;
{
    sqlite3_bind_int(statement, ++bindIndex, integer);
}

- (void)bindString:(NSString *)string;
{
    const char *value = [string UTF8String];
    sqlite3_bind_text(statement, ++bindIndex, value, strlen(value), SQLITE_TRANSIENT);
}

- (void)bindBlob:(NSData *)data;
{
    sqlite3_bind_text(statement, ++bindIndex, [data bytes], [data length], SQLITE_TRANSIENT);
}

- (void)bindLongLongInt:(long long)longLong;
{
    sqlite3_bind_int64(statement, ++bindIndex, longLong);
}

- (void)bindNull;
{
    sqlite3_bind_null(statement, ++bindIndex);
}

// Convenience methods

- (void)bindPropertyList:(id)propertyList;
{
    NSData *propertyListXMLData = (NSData *)CFPropertyListCreateXMLData(kCFAllocatorDefault, propertyList);
    [self bindBlob:propertyListXMLData];
    [propertyListXMLData release];
}

@end
