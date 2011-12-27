//
//  FMDatabaseAdditions.m
//  fmkit
//
//  Created by August Mueller on 10/30/05.
//  Copyright 2005 Flying Meat Inc.. All rights reserved.
//

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation FMDatabase (FMDatabaseAdditions)

#define RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(type, sel)             \
va_list args;                                                        \
va_start(args, query);                                               \
FMResultSet *resultSet = [self executeQuery:query withArgumentsInArray:0x00 orVAList:args];   \
va_end(args);                                                        \
if (![resultSet next]) { return (type)0; }                           \
type ret = [resultSet sel:0];                                        \
[resultSet close];                                                   \
[resultSet setParentDB:nil];                                         \
return ret;


- (NSString*)stringForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSString *, stringForColumnIndex);
}

- (int)intForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(int, intForColumnIndex);
}

- (long)longForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(long, longForColumnIndex);
}

- (long long)longLongForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(long long, longLongIntForColumnIndex);
}

- (BOOL)boolForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(BOOL, boolForColumnIndex);
}

- (double)doubleForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(double, doubleForColumnIndex);
}

- (NSData*)dataForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSData *, dataForColumnIndex);
}

- (NSDate*)dateForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSDate *, dateForColumnIndex);
}


//check if table exist in database (patch from OZLB)
- (BOOL)tableExists:(NSString*)tableName {
    
    BOOL returnBool;
    //lower case table name
    tableName = [tableName lowercaseString];
    //search in sqlite_master table if table exists
    FMResultSet *rs = [self executeQuery:@"select [sql] from sqlite_master where [type] = 'table' and lower(name) = ?", tableName];
    //if at least one next exists, table exists
    returnBool = [rs next];
    //close and free object
    [rs close];
    
    return returnBool;
}

//get table with list of tables: result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
//check if table exist in database  (patch from OZLB)
- (FMResultSet*)getSchema {
    
    //result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
    FMResultSet *rs = [self executeQuery:@"SELECT type, name, tbl_name, rootpage, sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE type != 'meta' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, type DESC, name"];
    
    return rs;
}

//get table schema: result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
- (FMResultSet*)getTableSchema:(NSString*)tableName {
    
    //result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
    FMResultSet *rs = [self executeQuery:[NSString stringWithFormat: @"PRAGMA table_info(%@)", tableName]];
    
    return rs;
}


//check if column exist in table
- (BOOL)columnExists:(NSString*)tableName columnName:(NSString*)columnName {
    
    BOOL returnBool = NO;
    //lower case table name
    tableName = [tableName lowercaseString];
    //lower case column name
    columnName = [columnName lowercaseString];
    //get table schema
    FMResultSet *rs = [self getTableSchema: tableName];
    //check if column is present in table schema
    while ([rs next]) {
        if ([[[rs stringForColumn:@"name"] lowercaseString] isEqualToString: columnName]) {
            returnBool = YES;
            break;
        }
    }
    //close and free object
    [rs close];
    
    return returnBool;
}

- (BOOL)validateSQL:(NSString*)sql error:(NSError**)error {
	sqlite3_stmt *pStmt = NULL;
	BOOL validationSucceeded = YES;
	BOOL keepTrying = YES;
    int numberOfRetries = 0;
	
    [self setInUse:YES];
	while (keepTrying == YES) {
		keepTrying = NO;
		int rc = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
		if (rc == SQLITE_BUSY || rc == SQLITE_LOCKED) {
			keepTrying = YES;
			usleep(20);
			
			if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
				NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
				NSLog(@"Database busy");
			}			
		} else if (rc != SQLITE_OK) {
			validationSucceeded = NO;
			if (error) {
				*error = [NSError errorWithDomain:NSCocoaErrorDomain 
											 code:[self lastErrorCode]
										 userInfo:[NSDictionary dictionaryWithObject:[self lastErrorMessage] 
																			  forKey:NSLocalizedDescriptionKey]];
			}
		}
	}
	[self setInUse:NO];
	sqlite3_finalize(pStmt);
	
	return validationSucceeded;
}

@end
