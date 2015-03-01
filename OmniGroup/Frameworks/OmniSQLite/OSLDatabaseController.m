// Copyright 2004-2005, 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSLDatabaseController.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniBase/OmniBase.h>

#import "OSLPreparedStatement.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSQLite/OSLDatabaseController.m 98768 2008-03-17 21:55:59Z bungi $")

@interface OSLDatabaseController (Private)
- (void *)_database;
- (BOOL)_openDatabase:(NSError **)outError;
- (void)_deleteDatabase;
- (void)_closeDatabase;
- (void)_executeSQL:(NSString *)sql withCallback:(OSLDatabaseCallback)callbackFunction context:(void *)callbackContext;
- (OSLPreparedStatement *)_prepareStatement:(NSString *)sql;
- (unsigned long long int)_lastInsertRowID;
@end

@implementation OSLDatabaseController

- initWithDatabasePath:(NSString *)aPath error:(NSError **)outError;
{
    if ([super init] == nil)
        return nil;
    
    databasePath = [aPath retain];    
    if (![self _openDatabase:outError])
        return nil;
    
    return self;
}

- (void)dealloc;
{
    [self _closeDatabase];
    [databasePath release];
    
    [super dealloc];
}

- (NSString *)databasePath;
{
    return databasePath;
}

- (void)deleteDatabase;
{
    [self _deleteDatabase];
}

- (void)executeSQL:(NSString *)sql withCallback:(OSLDatabaseCallback)callbackFunction context:(void *)callbackContext;
{
    [self _executeSQL:sql withCallback:callbackFunction context:callbackContext];
}

- (OSLPreparedStatement *)prepareStatement:(NSString *)sql;
{
    return [self _prepareStatement:sql];
}

- (unsigned long long int)lastInsertRowID;
{
    return [self _lastInsertRowID];
}

// Convenience methods

- (void)beginTransaction;
{
    [self executeSQL:@"BEGIN;\n" withCallback:NULL context:NULL];
}

- (void)commitTransaction;
{
    [self executeSQL:@"COMMIT;\n" withCallback:NULL context:NULL];
}

- (void)rollbackTransaction;
{
    [self executeSQL:@"ROLLBACK;\n" withCallback:NULL context:NULL];
}

@end

#import "sqlite3.h"

@implementation OSLDatabaseController (Private)

- (void *)_database;
{
    return sqliteDatabase;
}

#ifdef DEBUG_kc
#define DebugLog NSLog
#else
#define DebugLog(...) {}
#endif

- (BOOL)_openDatabase:(NSError **)outError;
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSLog(@"Opening %@", databasePath);
    if (![fileManager createPathToFile:databasePath attributes:nil error:outError])
        return NO;
    
    sqlite3 *db;
    int errorCode = sqlite3_open([fileManager fileSystemRepresentationWithPath:databasePath], &db);
    if (errorCode != SQLITE_OK) {
        NSLog(@"Failed to open %@: %d -- %@", databasePath, errorCode, [NSString stringWithUTF8String:sqlite3_errmsg(db)]);
        sqlite3_close(db);
        
        // try deleting and starting over
        [self _deleteDatabase];
        
        int errorCode = sqlite3_open([fileManager fileSystemRepresentationWithPath:databasePath], &db);
        if (errorCode != SQLITE_OK) {
            NSLog(@"Failed to open %@: %d -- %@", databasePath, errorCode, [NSString stringWithUTF8String:sqlite3_errmsg(db)]);
            sqlite3_close(db);
            
            exit(1);
        }
    }

    sqliteDatabase = db;
    unsigned long long count;
    
    [self executeSQL:@"select count(*) from sqlite_master" withCallback:SingleUnsignedLongLongCallback context:&count];
    DebugLog(@"sqlite_master count = %llu", count);
    [self executeSQL:
	@"PRAGMA synchronous = OFF;\n"
	@"PRAGMA temp_store = MEMORY;\n" 
	withCallback:NULL context:NULL];
    return YES;
}

- (void)_deleteDatabase;
{
    NSString *journalPath = [databasePath stringByAppendingString:@"-journal"];
    
    [[NSFileManager defaultManager] removeFileAtPath:databasePath handler:nil];
    [[NSFileManager defaultManager] removeFileAtPath:journalPath handler:nil];
}

- (void)_closeDatabase;
{
    sqlite3_close(sqliteDatabase);
}

- (void)_executeSQL:(NSString *)sql withCallback:(OSLDatabaseCallback)callbackFunction context:(void *)callbackContext;
{
    char *errorMessage = NULL;
    int errorCode = sqlite3_exec(
                                 sqliteDatabase, /* An open database */
                                 [sql UTF8String], /* SQL to be executed */
                                 callbackFunction, /* Callback function */
                                 callbackContext, /* 1st argument to callback function */
                                 &errorMessage /* Error msg written here */
                                 );
    if (errorCode != SQLITE_OK)
        NSLog(@"%@: %s (%d)", sql, errorMessage, errorCode);
    else
        DebugLog(@"EXEC: %@", sql);
}

- (OSLPreparedStatement *)_prepareStatement:(NSString *)sql;
{
    const char *remainder;
    sqlite3_stmt *statement;
    int errorCode = 
	sqlite3_prepare(
			sqliteDatabase, /* Database handle */
			[sql UTF8String], /* SQL statement, UTF-8 encoded */
			-1, /* ... up to the first NUL */
			&statement, /* OUT: Statement handle */
			&remainder /* OUT: Pointer to unused portion of zSql */               
			);
    
    if (errorCode != SQLITE_OK) {
        const char *errorMessage = sqlite3_errmsg(sqliteDatabase);
        NSLog(@"%@: %s (%d)", sql, errorMessage, errorCode);
	return nil;
    } else {
        DebugLog(@"PREPARE: %@", sql);
    }
    return [[[OSLPreparedStatement alloc] initWithSQL:sql statement:statement databaseController:self] autorelease];
}

- (unsigned long long int)_lastInsertRowID;
{
    return sqlite3_last_insert_rowid(sqliteDatabase);
}

@end

int ReadDictionaryCallback(void *callbackContext, int columnCount, char **columnValues, char **columnNames)
{
    NSMutableDictionary *dictionary = callbackContext;
    int columnIndex = columnCount;
    
    [dictionary removeAllObjects];
    while (columnIndex--) {
        if (columnValues[columnIndex] != NULL) {
            NSString *key = [NSString stringWithUTF8String:columnNames[columnIndex]];
            NSString *value = [NSString stringWithUTF8String:columnValues[columnIndex]];
            [dictionary setObject:value forKey:key];
        }
    }
    return 0;
}

int ReadDictionariesCallback(void *callbackContext, int columnCount, char **columnValues, char **columnNames)
{
    NSMutableArray *array = callbackContext;
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    int columnIndex = columnCount;
    while (columnIndex--) {
        if (columnValues[columnIndex] != NULL) {
            NSString *key = [NSString stringWithUTF8String:columnNames[columnIndex]];
            NSString *value = [NSString stringWithUTF8String:columnValues[columnIndex]];
            [dictionary setObject:value forKey:key];
        }
    }
    [array addObject:dictionary];
    return 0;
}

int SingleUnsignedLongLongCallback(void *callbackContext, int columnCount, char **columnValues, char **columnNames)
{
    unsigned long long int *countPtr = callbackContext;
    OBASSERT(columnCount == 1);
    if (columnValues[0] != NULL && *columnValues[0] != '\0')
        *countPtr = strtoull(columnValues[0], NULL, 10);
    else
        *countPtr = -1LL;
    
    return 0;
}

int SingleIntCallback(void *callbackContext, int columnCount, char **columnValues, char **columnNames)
{
    int *countPtr = callbackContext;
    OBASSERT(columnCount == 1);
    if (columnValues[0] != NULL && *columnValues[0] != '\0') {
        *countPtr = atoi(columnValues[0]);
        return 0;
    }
    return 1; // Null is an error
}

int SingleStringCallback(void *callbackContext, int columnCount, char **columnValues, char **columnNames)
{
    NSString **stringPtr = callbackContext;
    OBASSERT(columnCount == 1);
    if (columnValues[0] != NULL)
        *stringPtr = [NSString stringWithUTF8String:columnValues[0]];
    else
        *stringPtr = nil;
    return 0;
}

