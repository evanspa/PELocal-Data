//
//  PELMUtils.m
//  PELocal-Data
//
// Copyright (c) 2014-2015 PELocal-Data

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <CocoaLumberjack/DDLog.h>
#import <FMDB/FMDatabase.h>
#import <FMDB/FMDatabaseQueue.h>
#import <PEHateoas-Client/HCResource.h>
#import <PEHateoas-Client/HCMediaType.h>
#import <PEHateoas-Client/HCRelation.h>
#import <PEObjc-Commons/PEUtils.h>

#import "PELMUtils.h"
#import "PELMDDL.h"
#import "PELMNotificationUtils.h"
#import "PELMMainSupport.h"
#import "PELMNotificationNames.h"

void (^PELMCannotBe)(BOOL, NSString *) = ^(BOOL invariantViolation, NSString *msg) {
  if (invariantViolation) {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:msg
                                 userInfo:nil];
  }
};

id (^PELMOrNil)(id) = ^ id (id someObj) {
  return [PEUtils orNil:someObj];
};

PELMMainSupport * (^toMainSupport)(FMResultSet *, NSString *, NSDictionary *) = ^PELMMainSupport *(FMResultSet *rs, NSString *mainTable, NSDictionary *relations) {
  return [[PELMMainSupport alloc] initWithLocalMainIdentifier:[rs objectForColumnName:COL_LOCAL_ID]
                                        localMasterIdentifier:nil // NA (this is a master entity-only column)
                                             globalIdentifier:[rs stringForColumn:COL_GLOBAL_ID]
                                              mainEntityTable:mainTable
                                            masterEntityTable:nil
                                                    mediaType:[HCMediaType MediaTypeFromString:[rs stringForColumn:COL_MEDIA_TYPE]]
                                                    relations:relations
                                                    createdAt:nil // NA (this is a master entity-only column)
                                                    deletedAt:nil // NA (this is a master entity-only column)
                                                    updatedAt:[PELMUtils dateFromResultSet:rs columnName:COL_MAN_MASTER_UPDATED_AT]
                                         dateCopiedFromMaster:[PELMUtils dateFromResultSet:rs columnName:COL_MAN_DT_COPIED_DOWN_FROM_MASTER]
                                               editInProgress:[rs boolForColumn:COL_MAN_EDIT_IN_PROGRESS]
                                               syncInProgress:[rs boolForColumn:COL_MAN_SYNC_IN_PROGRESS]
                                                       synced:[rs boolForColumn:COL_MAN_SYNCED]
                                                    editCount:[rs intForColumn:COL_MAN_EDIT_COUNT]
                                             syncHttpRespCode:[rs objectForColumnName:COL_MAN_SYNC_HTTP_RESP_CODE]
                                                  syncErrMask:[rs objectForColumnName:COL_MAN_SYNC_ERR_MASK]
                                                  syncRetryAt:[PELMUtils dateFromResultSet:rs columnName:COL_MAN_SYNC_RETRY_AT]];
};

@implementation PELMUtils

#pragma mark - Initializers

- (id)initWithDatabaseQueue:(FMDatabaseQueue *)databaseQueue {
  self = [super init];
  if (self) {
    _databaseQueue = databaseQueue;
  }
  return self;
}

#pragma mark - Notifications

+ (void)postDbUpdateNotification {
  [[NSNotificationCenter defaultCenter] postNotificationName:PELMNotificationDbUpdate object:self];
}

#pragma mark - Completion Handler Makers

+ (PELMRemoteMasterCompletionHandler)complHandlerToFlushUnsyncedChangesToEntity:(PELMMainSupport *)entity
                                                            remoteStoreErrorBlk:(void(^)(NSError *, NSNumber *))remoteStoreErrorBlk
                                                              entityNotFoundBlk:(void(^)(void))entityNotFoundBlk
                                                              markAsConflictBlk:(void(^)(id))markAsConflictBlk
                                              markAsSyncCompleteForNewEntityBlk:(void(^)(void))markAsSyncCompleteForNewEntityBlk
                                         markAsSyncCompleteForExistingEntityBlk:(void(^)(void))markAsSyncCompleteForExistingEntityBlk
                                                                newAuthTokenBlk:(void(^)(NSString *))newAuthTokenBlk {
  void (^successfulSync)(PELMMainSupport *, BOOL) = ^(PELMMainSupport *respEntity, BOOL wasPut) {
    if (respEntity) {
      NSString *unsyncedEntityGlobalId = [entity globalIdentifier];
      [entity overwrite:respEntity];
      if (wasPut) {
        // we do this because, in an HTTP PUT, the typical response is 200,
        // and, with 200, the "location" header is usually absent; this means
        // that the entity parsed from the response will have its 'globalIdentifier'
        // property empty.  Well, we want to keep our existing global identity
        // property, so, we have to re-set it onto unsyncedEntity after doing
        // the "overwrite" step above
        [entity setGlobalIdentifier:unsyncedEntityGlobalId];
      }
    }
    if (wasPut) {
      markAsSyncCompleteForExistingEntityBlk();
    } else {
      markAsSyncCompleteForNewEntityBlk();
    }
  };
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler;
  if ([entity globalIdentifier]) { // PUT
    remoteStoreComplHandler =
    ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
      NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
      BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
      newAuthTokenBlk(newAuthTkn);
      if (movedPermanently) { // this block will get executed again
        [entity setGlobalIdentifier:globalId];
      } else if (isConflict) {
        markAsConflictBlk(resourceModel);
      } else if (gone) {
        entityNotFoundBlk();
      } else if (notFound) {
        entityNotFoundBlk();
      } else if (notModified) {
        // this is only relevant on a GET
      } else if (err) {
        if (httpResp) { // will deduce that error is from server
          remoteStoreErrorBlk(err, [NSNumber numberWithInteger:[httpResp statusCode]]);
        } else {  // will deduce that error is connecton-related
          remoteStoreErrorBlk(err, nil);
        }
      } else {
        successfulSync(resourceModel, YES);
      }
    };
  } else { // POST
    remoteStoreComplHandler =
    ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
      NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
      BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
      newAuthTokenBlk(newAuthTkn);
      if (movedPermanently) { // this block will get executed again
        [entity setGlobalIdentifier:globalId];
      } else if (isConflict) {
        markAsConflictBlk(resourceModel); // weird - this should not happen on a POST
      } else if (gone) {
        entityNotFoundBlk(); // weird - this should not happen on a POST
      } else if (notFound) {
        entityNotFoundBlk(); // weird - this should not happen on a POST
      } else if (notModified) {
        // this is only relevant on a GET
      } else if (err) {
        if (httpResp) { // will deduce that error is from server
          remoteStoreErrorBlk(err, [NSNumber numberWithInteger:[httpResp statusCode]]);
        } else {  // will deduce that error is connecton-related
          remoteStoreErrorBlk(err, nil);
        }
      } else {
        successfulSync(resourceModel, NO);
      }
    };
  }
  return remoteStoreComplHandler;
}

+ (PELMRemoteMasterCompletionHandler)complHandlerToDeleteEntity:(PELMMainSupport *)entity
                                            remoteStoreErrorBlk:(void(^)(NSError *, NSNumber *))remoteStoreErrorBlk
                                              entityNotFoundBlk:(void(^)(void))entityNotFoundBlk
                                              markAsConflictBlk:(void(^)(id))markAsConflictBlk
                                               deleteSuccessBlk:(void(^)(void))deleteSuccessBlk
                                                newAuthTokenBlk:(void(^)(NSString *))newAuthTokenBlk {
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    newAuthTokenBlk(newAuthTkn);
    if (movedPermanently) {
      [entity setGlobalIdentifier:globalId];
    } else if (isConflict) {
      markAsConflictBlk(resourceModel);
    } else if (gone) {
      entityNotFoundBlk();
    } else if (notFound) {
      entityNotFoundBlk();
    } else if (notModified) {
      // should not happen since we're doing a DELETE
    } else if (err) {
      if (httpResp) { // will deduce that error is from server
        remoteStoreErrorBlk(err, [NSNumber numberWithInteger:[httpResp statusCode]]);
      } else {  // will deduce that error is connecton-related
        remoteStoreErrorBlk(err, nil);
      }
    } else {
      deleteSuccessBlk();
    }
  };
  return remoteStoreComplHandler;
}

+ (PELMRemoteMasterCompletionHandler)complHandlerToFetchEntityWithGlobalId:(NSString *)globalId
                                                       remoteStoreErrorBlk:(void(^)(NSError *, NSNumber *))remoteStoreErrorBlk
                                                         entityNotFoundBlk:(void(^)(void))entityNotFoundBlk
                                                          fetchCompleteBlk:(void(^)(id))fetchCompleteBlk
                                                           newAuthTokenBlk:(void(^)(NSString *))newAuthTokenBlk {
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler =
    ^(NSString *newAuthTkn, NSString *relativeGlobalId, id resourceModel, NSDictionary *rels,
      NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
      BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    newAuthTokenBlk(newAuthTkn);
    if (movedPermanently) { // this block will get executed again
      // ?
    } else if (gone) {
      entityNotFoundBlk();
    } else if (notFound) {
      entityNotFoundBlk();
    } else if (err) {
      if (httpResp) { // will deduce that error is from server
        remoteStoreErrorBlk(err, [NSNumber numberWithInteger:[httpResp statusCode]]);
      } else {  // will deduce that error is connecton-related
        remoteStoreErrorBlk(err, nil);
      }
    } else {
      [resourceModel setGlobalIdentifier:globalId];
      fetchCompleteBlk(resourceModel);
    }
  };
  return remoteStoreComplHandler;
}

+ (void)cancelSyncInProgressForEntityTable:(NSString *)mainEntityTable
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)error {
  [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ = 0", mainEntityTable, COL_MAN_SYNC_IN_PROGRESS]];
  [PELMUtils postDbUpdateNotification];
}

#pragma mark - Result Set Helpers

+ (NSNumber *)numberFromResultSet:(FMResultSet *)rs
                       columnName:(NSString *)columnName {
  return [PEUtils nullSafeNumberFromString:[rs stringForColumn:columnName]];
}

+ (NSDecimalNumber *)decimalNumberFromResultSet:(FMResultSet *)rs
                                     columnName:(NSString *)columnName {
  return [PEUtils nullSafeDecimalNumberFromString:[rs stringForColumn:columnName]];
}

+ (NSDecimalNumber *)decimalNumberFromResultSet:(FMResultSet *)rs
                                    columnIndex:(int)columnIndex {
  return [PEUtils nullSafeDecimalNumberFromString:[rs stringForColumnIndex:columnIndex]];
}

+ (NSDate *)dateFromResultSet:(FMResultSet *)rs
                    isNullBlk:(BOOL(^)(FMResultSet *))isNullBlk
           doubleForColumnBlk:(double(^)(FMResultSet *))doubleForColumnBlk {
  NSDate *date = nil;
  if (!isNullBlk(rs)) {
    date = [NSDate dateWithTimeIntervalSince1970:(doubleForColumnBlk(rs) / 1000)];
  }
  return date;
}

+ (NSDate *)dateFromResultSet:(FMResultSet *)rs
                  columnIndex:(int)columnIndex {
  return [PELMUtils dateFromResultSet:rs
                            isNullBlk:^ BOOL (FMResultSet *rs) { return [rs columnIndexIsNull:columnIndex]; }
                   doubleForColumnBlk:^ double (FMResultSet *rs) { return [rs doubleForColumnIndex:columnIndex]; }];
}

+ (NSDate *)dateFromResultSet:(FMResultSet *)rs
                   columnName:(NSString *)columnName {
  return [PELMUtils dateFromResultSet:rs
                            isNullBlk:^ BOOL (FMResultSet *rs) { return [rs columnIsNull:columnName]; }
                   doubleForColumnBlk:^ double (FMResultSet *rs) { return [rs doubleForColumn:columnName]; }];
}

+ (BOOL)boolFromResultSet:(FMResultSet *)rs columnName:(NSString *)columnName boolIfNull:(BOOL)boolIfNull {
  if ([rs columnIsNull:columnName]) {
    return boolIfNull;
  }
  return [rs boolForColumn:columnName];
}

#pragma mark - Utils

- (void)cancelSyncForEntity:(PELMMainSupport *)entity
             httpRespCode:(NSNumber *)httpRespCode
                errorMask:(NSNumber *)errorMask
                  retryAt:(NSDate *)retryAt
           mainUpdateStmt:(NSString *)mainUpdateStmt
        mainUpdateArgsBlk:(NSArray *(^)(PELMMainSupport *))mainUpdateArgsBlk
                    error:(PELMDaoErrorBlk)errorBlk {
  [entity setSyncInProgress:NO];
  [entity setSyncErrMask:errorMask];
  [entity setSyncHttpRespCode:httpRespCode];
  [entity setSyncRetryAt:retryAt];
  [self doUpdateInTxn:mainUpdateStmt
            argsArray:mainUpdateArgsBlk(entity)
                error:errorBlk];
}

- (void)cancelEditOfEntity:(PELMMainSupport *)entity
                 mainTable:(NSString *)mainTable
            mainUpdateStmt:(NSString *)mainUpdateStmt
         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
               masterTable:(NSString *)masterTable
               rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                     error:(PELMDaoErrorBlk)errorBlk {
  [entity setEditInProgress:NO];
  NSInteger newEditCount = [entity decrementEditCount];
  BOOL shouldPrune = (newEditCount == 0);
  __block BOOL pruneSuccess = YES;
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    if (shouldPrune) {
      [PELMUtils deleteRelationsFromEntityTable:mainTable
                                localIdentifier:[entity localMainIdentifier]
                                             db:db
                                          error:errorBlk];
      [PELMUtils deleteFromTable:mainTable
                    whereColumns:@[COL_LOCAL_ID]
                     whereValues:@[[entity localMainIdentifier]]
                              db:db
                           error:^ (NSError *err, int code, NSString *msg) {
                             errorBlk(err, code, msg);
                             pruneSuccess = NO;
                             *rollback = YES;
                           }];
      if (pruneSuccess) {
        [entity setLocalMainIdentifier:nil];
      }
    } else {
      [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ = 0, %@ = ? WHERE %@ = ?", mainTable, COL_MAN_EDIT_IN_PROGRESS, COL_MAN_EDIT_COUNT, COL_LOCAL_ID]
   withArgumentsInArray:@[@([entity editCount]), [entity localMainIdentifier]]];
      [PELMUtils postDbUpdateNotification];
    }
  }];
  if (shouldPrune && !pruneSuccess) {
    // Okay, so we couldn't prune.  Maybe because a child entity of it is sitting
    // in a main table, so entity HAS to exist in its main table.  That is not a
    // surprising situation.  However, we should mark it as "synced" and save it.
    [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
      [entity setSynced:YES];
      [PELMUtils doUpdate:mainUpdateStmt
                argsArray:mainUpdateArgsBlk(entity)
                       db:db
                    error:errorBlk];
    }];
  }
}

- (void)saveEntity:(PELMMainSupport *)entity
         mainTable:(NSString *)mainTable
    mainUpdateStmt:(NSString *)mainUpdateStmt
 mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
             error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [PELMUtils doUpdate:mainUpdateStmt
              argsArray:mainUpdateArgsBlk(entity)
                     db:db
                  error:errorBlk];
  }];
}

- (void)markAsDoneEditingEntity:(PELMMainSupport *)entity
                      mainTable:(NSString *)mainTable
                 mainUpdateStmt:(NSString *)mainUpdateStmt
              mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                          error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [entity setSyncHttpRespCode:nil];
    [entity setSyncErrMask:nil];
    [entity setEditInProgress:NO];
    [PELMUtils doUpdate:mainUpdateStmt
              argsArray:mainUpdateArgsBlk(entity)
                     db:db
                  error:errorBlk];
  }];
}

- (void)markAsDoneEditingImmediateSyncEntity:(PELMMainSupport *)entity
                                   mainTable:(NSString *)mainTable
                              mainUpdateStmt:(NSString *)mainUpdateStmt
                           mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                                       error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [entity setSyncHttpRespCode:nil];
    [entity setSyncErrMask:nil];
    [entity setEditInProgress:NO];
    [entity setSyncInProgress:YES];
    [PELMUtils doUpdate:mainUpdateStmt
              argsArray:mainUpdateArgsBlk(entity)
                     db:db
                  error:errorBlk];
  }];
}

- (PELMSaveNewOrExistingCode)saveNewOrExistingMasterEntity:(PELMMainSupport *)masterEntity
                                               masterTable:(NSString *)masterTable
                                           masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                                          masterUpdateStmt:(NSString *)masterUpdateStmt
                                       masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                                 mainTable:(NSString *)mainTable
                                   mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
                                            mainUpdateStmt:(NSString *)mainUpdateStmt
                                         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                                                     error:(PELMDaoErrorBlk)errorBlk {
  __block PELMSaveNewOrExistingCode returnCode;
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    returnCode = [PELMUtils saveNewOrExistingMasterEntity:masterEntity
                                              masterTable:masterTable
                                          masterInsertBlk:masterInsertBlk
                                         masterUpdateStmt:masterUpdateStmt
                                      masterUpdateArgsBlk:masterUpdateArgsBlk
                                                mainTable:mainTable
                                  mainEntityFromResultSet:mainEntityFromResultSet
                                           mainUpdateStmt:mainUpdateStmt
                                        mainUpdateArgsBlk:mainUpdateArgsBlk
                                                       db:db
                                                    error:errorBlk];
  }];
  return returnCode;
}

+ (PELMSaveNewOrExistingCode)saveNewOrExistingMasterEntity:(PELMMainSupport *)masterEntity
                                               masterTable:(NSString *)masterTable
                                           masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                                          masterUpdateStmt:(NSString *)masterUpdateStmt
                                       masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                                 mainTable:(NSString *)mainTable
                                   mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
                                            mainUpdateStmt:(NSString *)mainUpdateStmt
                                         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                                                        db:(FMDatabase *)db
                                                     error:(PELMDaoErrorBlk)errorBlk {
  PELMSaveNewOrExistingCode returnCode = PELMSaveNewOrExistingCodeDidNothing;
  NSNumber *localMasterId = [PELMUtils masterLocalIdFromEntityTable:masterTable
                                                   globalIdentifier:masterEntity.globalIdentifier
                                                                 db:db
                                                              error:errorBlk];
  if (localMasterId) {
    if ([PELMUtils saveMasterEntity:masterEntity
                        masterTable:masterTable
                   masterUpdateStmt:masterUpdateStmt
                masterUpdateArgsBlk:masterUpdateArgsBlk
                          mainTable:mainTable
            mainEntityFromResultSet:mainEntityFromResultSet
                     mainUpdateStmt:mainUpdateStmt
                  mainUpdateArgsBlk:mainUpdateArgsBlk
                                 db:db
                              error:errorBlk]) {
      returnCode = PELMSaveNewOrExistingCodeDidUpdate;
    }
  } else {
    [PELMUtils saveNewMasterEntity:masterEntity
                       masterTable:masterTable
                   masterInsertBlk:masterInsertBlk
                                db:db
                             error:errorBlk];
    returnCode = PELMSaveNewOrExistingCodeDidInsert;
  }
  return returnCode;
}

- (void)saveNewMasterEntity:(PELMMainSupport *)entity
                masterTable:(NSString *)masterTable
            masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                      error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [PELMUtils saveNewMasterEntity:entity
                       masterTable:masterTable
                   masterInsertBlk:masterInsertBlk
                                db:db
                             error:errorBlk];
  }];
}

+ (void)saveNewMasterEntity:(PELMMainSupport *)entity
                masterTable:(NSString *)masterTable
            masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                         db:(FMDatabase *)db
                      error:(PELMDaoErrorBlk)errorBlk {
  masterInsertBlk(entity, db);
  [PELMUtils insertRelations:[entity relations]
                   forEntity:entity
                 entityTable:masterTable
             localIdentifier:[entity localMasterIdentifier]
                          db:db
                       error:errorBlk];
}

- (BOOL)saveMasterEntity:(PELMMainSupport *)masterEntity
             masterTable:(NSString *)masterTable
        masterUpdateStmt:(NSString *)masterUpdateStmt
     masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
               mainTable:(NSString *)mainTable
 mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
          mainUpdateStmt:(NSString *)mainUpdateStmt
       mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                   error:(PELMDaoErrorBlk)errorBlk {
  __block BOOL didUpdateDatabase;
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    didUpdateDatabase = [PELMUtils saveMasterEntity:masterEntity
                                        masterTable:masterTable
                                   masterUpdateStmt:masterUpdateStmt
                                masterUpdateArgsBlk:masterUpdateArgsBlk
                                          mainTable:mainTable
                            mainEntityFromResultSet:mainEntityFromResultSet
                                     mainUpdateStmt:mainUpdateStmt
                                  mainUpdateArgsBlk:mainUpdateArgsBlk
                                                 db:db
                                              error:errorBlk];
  }];
  return didUpdateDatabase;
}

+ (BOOL)saveMasterEntity:(PELMMainSupport *)entity
             masterTable:(NSString *)masterTable
        masterUpdateStmt:(NSString *)masterUpdateStmt
     masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
               mainTable:(NSString *)mainTable
 mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
          mainUpdateStmt:(NSString *)mainUpdateStmt
       mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk {
  BOOL didUpdateDatabase = NO;
  // entity is presumed to ONLY have its domain properties populated, and
  // its globalIdentifier populated.  That's it.
  // First, we'll get the entity's master local ID and set it on it.
  NSNumber *localMasterId = [PELMUtils numberFromTable:masterTable
                                          selectColumn:COL_LOCAL_ID
                                           whereColumn:COL_GLOBAL_ID
                                            whereValue:[entity globalIdentifier]
                                                    db:db
                                                 error:errorBlk];
  if (localMasterId) {
    NSDate *localMasterEntityUpdatedAt = [PELMUtils dateFromTable:masterTable
                                                       dateColumn:COL_MST_UPDATED_AT
                                                      whereColumn:COL_LOCAL_ID
                                                       whereValue:localMasterId
                                                               db:db
                                                            error:errorBlk];
    if ([entity.updatedAt compare:localMasterEntityUpdatedAt] == NSOrderedDescending) {
      [entity setLocalMasterIdentifier:localMasterId];
      [PELMUtils doUpdate:masterUpdateStmt
                argsArray:masterUpdateArgsBlk(entity)
                       db:db
                    error:errorBlk];
      didUpdateDatabase = YES;
      NSNumber *localMainId = [PELMUtils localMainIdentifierForEntity:entity
                                                            mainTable:mainTable
                                                                   db:db
                                                                error:errorBlk];
      if (localMainId) {
        PELMMainSupport *mainEntity = [PELMUtils entityFromQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?", mainTable, COL_LOCAL_ID]
                                                     entityTable:mainTable
                                                   localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMainIdentifier]; }
                                                       argsArray:@[localMainId]
                                                     rsConverter:mainEntityFromResultSet
                                                              db:db
                                                           error:errorBlk];
        // obviously we should only update the main-instance if it is currently
        // synced; because if it is not synced, that means the user is currently
        // editing it and therefore we don't want to overwrite their changes.
        if ([mainEntity synced]) {
          [mainEntity overwriteDomainProperties:entity];
          [mainEntity setUpdatedAt:[entity updatedAt]];
          [mainEntity setDateCopiedFromMaster:[entity updatedAt]];
          [PELMUtils doUpdate:mainUpdateStmt
                    argsArray:mainUpdateArgsBlk(mainEntity)
                           db:db
                        error:errorBlk];
        }
      }
    }
  }
  return didUpdateDatabase;
}

- (void)markAsSyncCompleteForNewEntity:(PELMMainSupport *)entity
                             mainTable:(NSString *)mainTable
                           masterTable:(NSString *)masterTable
                        mainUpdateStmt:(NSString *)mainUpdateStmt
                     mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                       masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                                 error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [entity setSyncInProgress:NO];
    [entity setSynced:YES];
    [PELMUtils updateRelationsForEntity:entity
                            entityTable:mainTable
                        localIdentifier:[entity localMainIdentifier]
                                     db:db
                                  error:errorBlk];
    [PELMUtils doUpdate:mainUpdateStmt
              argsArray:mainUpdateArgsBlk(entity)
                     db:db
                  error:errorBlk];
    masterInsertBlk(entity, db);
    [PELMUtils insertRelations:[entity relations]
                     forEntity:entity
                   entityTable:masterTable
               localIdentifier:[entity localMasterIdentifier]
                            db:db
                         error:errorBlk];
  }];
}

- (void)markAsSyncCompleteForUpdatedEntityInTxn:(PELMMainSupport *)entity
                                      mainTable:(NSString *)mainTable
                                    masterTable:(NSString *)masterTable
                                 mainUpdateStmt:(NSString *)mainUpdateStmt
                              mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                               masterUpdateStmt:(NSString *)masterUpdateStmt
                            masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                          error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [self markAsSyncCompleteForUpdatedEntity:entity
                                   mainTable:mainTable
                                 masterTable:masterTable
                              mainUpdateStmt:mainUpdateStmt
                           mainUpdateArgsBlk:mainUpdateArgsBlk
                            masterUpdateStmt:masterUpdateStmt
                         masterUpdateArgsBlk:masterUpdateArgsBlk
                                          db:db
                                       error:errorBlk];
  }];
}

- (void)markAsSyncCompleteForUpdatedEntity:(PELMMainSupport *)entity
                                 mainTable:(NSString *)mainTable
                               masterTable:(NSString *)masterTable
                            mainUpdateStmt:(NSString *)mainUpdateStmt
                         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                          masterUpdateStmt:(NSString *)masterUpdateStmt
                       masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk {
  [entity setSyncInProgress:NO];
  [entity setSynced:YES];
  [PELMUtils updateRelationsForEntity:entity
                          entityTable:mainTable
                      localIdentifier:[entity localMainIdentifier]
                                   db:db
                                error:errorBlk];
  [PELMUtils doUpdate:mainUpdateStmt
            argsArray:mainUpdateArgsBlk(entity)
                   db:db
                error:errorBlk];
  [entity setLocalMasterIdentifier:[PELMUtils masterLocalIdFromEntityTable:masterTable
                                                          globalIdentifier:[entity globalIdentifier]
                                                                        db:db
                                                                     error:errorBlk]];
  [PELMUtils updateRelationsForEntity:entity
                          entityTable:masterTable
                      localIdentifier:[entity localMasterIdentifier]
                                   db:db
                                error:errorBlk];
  [PELMUtils doUpdate:masterUpdateStmt
            argsArray:masterUpdateArgsBlk(entity)
                   db:db
                error:errorBlk];
}

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
      addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
         parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                   pageBoundaryWhere:(NSString *)pageBoundaryWhere
                     pageBoundaryArg:(id)pageBoundaryArg
                   entityMasterTable:(NSString *)entityMasterTable
          addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
      masterEntityResultSetConverter:(PELMEntityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
            addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
        mainEntityResultSetConverter:(PELMEntityFromResultSetBlk)mainEntityResultSetConverter
                   comparatorForSort:(NSComparisonResult(^)(id, id))comparatorForSort
                 orderByDomainColumn:(NSString *)orderByDomainColumn
        orderByDomainColumnDirection:(NSString *)orderByDomainColumnDirection
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  NSString *(^masterQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (pageBoundaryArg) {
      qry = [qry stringByAppendingFormat:@" AND mstr.%@ ", pageBoundaryWhere];
    }
    return [qry stringByAppendingFormat:@" ORDER BY mstr.%@ %@", orderByDomainColumn, orderByDomainColumnDirection];
  };
  NSArray *(^argsArrayTransformer)(NSArray *) = ^ NSArray *(NSArray *argsArray) {
    if (pageBoundaryArg) {
      return [argsArray arrayByAddingObject:pageBoundaryArg];
    }
    return argsArray;
  };
  NSString *(^mainQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (pageBoundaryArg) {
      qry = [qry stringByAppendingFormat:@" AND %@ ", pageBoundaryWhere];
    }
    return [qry stringByAppendingFormat:@" ORDER BY %@ %@", orderByDomainColumn, orderByDomainColumnDirection];
  };
  NSArray *(^entitiesFilter)(NSArray *) = nil;
  if (pageSize) {
    NSInteger pageSizeInt = [pageSize integerValue];
    entitiesFilter = ^ NSArray *(NSArray *entities) {
      NSArray *sortedEntities = [entities sortedArrayUsingComparator:comparatorForSort];
      if ([sortedEntities count] > pageSizeInt) {
        NSMutableArray *truncatedEntities = [NSMutableArray arrayWithCapacity:pageSizeInt];
        for (int i = 0; i < pageSizeInt; i++) {
          [truncatedEntities addObject:sortedEntities[i]];
        }
        sortedEntities = truncatedEntities;
      }
      return sortedEntities;
    };
  }
  return [PELMUtils entitiesForParentEntity:parentEntity
                      parentEntityMainTable:parentEntityMainTable
             addlJoinParentEntityMainTables:addlJoinParentEntityMainTables
                parentEntityMainRsConverter:parentEntityMainRsConverter
                 parentEntityMasterIdColumn:parentEntityMasterIdColumn
                   parentEntityMainIdColumn:parentEntityMainIdColumn
                                   pageSize:pageSize
                          entityMasterTable:entityMasterTable
                 addlJoinEntityMasterTables:addlJoinEntityMasterTables
             masterEntityResultSetConverter:masterEntityResultSetConverter
                            entityMainTable:entityMainTable
                   addlJoinEntityMainTables:addlJoinEntityMainTables
               mainEntityResultSetConverter:mainEntityResultSetConverter
                     masterQueryTransformer:masterQueryTransformer
                 masterArgsArrayTransformer:argsArrayTransformer
                       mainQueryTransformer:mainQueryTransformer
                   mainArgsArrayTransformer:argsArrayTransformer
                             entitiesFilter:entitiesFilter
                                         db:db
                                      error:errorBlk];
}

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
      addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
         parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                            whereBlk:(NSString *(^)(NSString *))whereBlk
                           whereArgs:(NSArray *)whereArgs
                   entityMasterTable:(NSString *)entityMasterTable
          addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
      masterEntityResultSetConverter:(PELMEntityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
            addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
        mainEntityResultSetConverter:(PELMEntityFromResultSetBlk)mainEntityResultSetConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils entitiesForParentEntity:parentEntity
                      parentEntityMainTable:parentEntityMainTable
             addlJoinParentEntityMainTables:addlJoinParentEntityMainTables
                parentEntityMainRsConverter:parentEntityMainRsConverter
                 parentEntityMasterIdColumn:parentEntityMasterIdColumn
                   parentEntityMainIdColumn:parentEntityMainIdColumn
                                   pageSize:pageSize
                                   whereBlk:whereBlk
                                  whereArgs:whereArgs
                          entityMasterTable:entityMasterTable
                 addlJoinEntityMasterTables:addlJoinEntityMasterTables
             masterEntityResultSetConverter:masterEntityResultSetConverter
                            entityMainTable:entityMainTable
                   addlJoinEntityMainTables:addlJoinEntityMainTables
               mainEntityResultSetConverter:mainEntityResultSetConverter
                          comparatorForSort:nil
                        orderByDomainColumn:nil
               orderByDomainColumnDirection:nil
                                         db:db
                                      error:errorBlk];
}

+ (NSArray *)unsyncedEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                       parentEntityMainTable:(NSString *)parentEntityMainTable
              addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
                 parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
                  parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
                    parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                                    pageSize:(NSNumber *)pageSize
                           entityMasterTable:(NSString *)entityMasterTable
                  addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
              masterEntityResultSetConverter:(PELMEntityFromResultSetBlk)masterEntityResultSetConverter
                             entityMainTable:(NSString *)entityMainTable
                    addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
                mainEntityResultSetConverter:(PELMEntityFromResultSetBlk)mainEntityResultSetConverter
                           comparatorForSort:(NSComparisonResult(^)(id, id))comparatorForSort
                         orderByDomainColumn:(NSString *)orderByDomainColumn
                orderByDomainColumnDirection:(NSString *)orderByDomainColumnDirection
                                          db:(FMDatabase *)db
                                       error:(PELMDaoErrorBlk)errorBlk {
  NSArray *(^argsArrayTransformer)(NSArray *) = ^ NSArray *(NSArray *argsArray) {
    return argsArray;
  };
  NSString *(^mainQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (orderByDomainColumn) {
      qry = [qry stringByAppendingFormat:@" ORDER BY %@", orderByDomainColumn];
      if (orderByDomainColumnDirection) {
        qry = [qry stringByAppendingFormat:@" %@", orderByDomainColumnDirection];
      }
    }
    return qry;
  };
  NSArray *(^entitiesFilter)(NSArray *) = nil;
  if (comparatorForSort) {
    entitiesFilter = ^ NSArray *(NSArray *entities) {
      return [entities sortedArrayUsingComparator:comparatorForSort];
    };
  }
  return [PELMUtils unsyncedEntitiesForParentEntity:parentEntity
                              parentEntityMainTable:parentEntityMainTable
                     addlJoinParentEntityMainTables:addlJoinParentEntityMainTables
                        parentEntityMainRsConverter:parentEntityMainRsConverter
                           parentEntityMainIdColumn:parentEntityMainIdColumn
                                           pageSize:pageSize
                                  entityMasterTable:entityMasterTable
                         addlJoinEntityMasterTables:addlJoinEntityMasterTables
                                    entityMainTable:entityMainTable
                           addlJoinEntityMainTables:addlJoinEntityMainTables
                       mainEntityResultSetConverter:mainEntityResultSetConverter
                               mainQueryTransformer:mainQueryTransformer
                           mainArgsArrayTransformer:argsArrayTransformer
                                     entitiesFilter:entitiesFilter
                                                 db:db
                                              error:errorBlk];
}

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
      addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
         parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                            whereBlk:(NSString *(^)(NSString *))whereBlk
                           whereArgs:(NSArray *)whereArgs
                   entityMasterTable:(NSString *)entityMasterTable
          addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
      masterEntityResultSetConverter:(PELMEntityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
            addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
        mainEntityResultSetConverter:(PELMEntityFromResultSetBlk)mainEntityResultSetConverter
                   comparatorForSort:(NSComparisonResult(^)(id, id))comparatorForSort
                 orderByDomainColumn:(NSString *)orderByDomainColumn
        orderByDomainColumnDirection:(NSString *)orderByDomainColumnDirection
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  NSString *(^masterQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (whereBlk) {
      qry = [qry stringByAppendingFormat:@" AND %@ ", whereBlk(@"mstr.")];
    }
    if (orderByDomainColumn) {
      qry = [qry stringByAppendingFormat:@" ORDER BY mstr.%@", orderByDomainColumn];
      if (orderByDomainColumnDirection) {
        qry = [qry stringByAppendingFormat:@" %@", orderByDomainColumnDirection];
      }
    }
    return qry;
  };
  NSArray *(^argsArrayTransformer)(NSArray *) = ^ NSArray *(NSArray *argsArray) {
    if (whereArgs) {
      return [argsArray arrayByAddingObjectsFromArray:whereArgs];
    }
    return argsArray;
  };
  NSString *(^mainQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (whereBlk) {
      qry = [qry stringByAppendingFormat:@" AND %@ ", whereBlk(@"")];
    }
    if (orderByDomainColumn) {
      qry = [qry stringByAppendingFormat:@" ORDER BY %@", orderByDomainColumn];
      if (orderByDomainColumnDirection) {
        qry = [qry stringByAppendingFormat:@" %@", orderByDomainColumnDirection];
      }
    }
    return qry;
  };
  NSArray *(^entitiesFilter)(NSArray *) = nil;
  if (comparatorForSort) {
    entitiesFilter = ^ NSArray *(NSArray *entities) {
      return [entities sortedArrayUsingComparator:comparatorForSort];
    };
  }
  return [PELMUtils entitiesForParentEntity:parentEntity
                      parentEntityMainTable:parentEntityMainTable
             addlJoinParentEntityMainTables:addlJoinParentEntityMainTables
                parentEntityMainRsConverter:parentEntityMainRsConverter
                 parentEntityMasterIdColumn:parentEntityMasterIdColumn
                   parentEntityMainIdColumn:parentEntityMainIdColumn
                                   pageSize:pageSize
                          entityMasterTable:entityMasterTable
                 addlJoinEntityMasterTables:addlJoinEntityMasterTables
             masterEntityResultSetConverter:masterEntityResultSetConverter
                            entityMainTable:entityMainTable
                   addlJoinEntityMainTables:addlJoinEntityMainTables
               mainEntityResultSetConverter:mainEntityResultSetConverter
                     masterQueryTransformer:masterQueryTransformer
                 masterArgsArrayTransformer:argsArrayTransformer
                       mainQueryTransformer:mainQueryTransformer
                   mainArgsArrayTransformer:argsArrayTransformer
                             entitiesFilter:entitiesFilter
                                         db:db
                                      error:errorBlk];
}

+ (void)incorporateJoinTables:(NSArray *)joinTables
             intoSelectClause:(NSMutableString *)selectClause
                   fromClause:(NSMutableString *)fromClause
                  whereClause:(NSMutableString *)whereClause
            entityTablePrefix:(NSString *)entityTablePrefix {
  if (joinTables) {
    for (NSArray *joinTable in joinTables) {
      NSString *joinTablePrefix = joinTable[0];
      NSString *joinTableName = joinTable[1];
      NSString *joinEntityColumnName = joinTable[2];
      NSString *joinTargetColumnName = joinTable[3];
      [selectClause appendFormat:@", %@.*", joinTablePrefix];
      [fromClause appendFormat:@", %@ %@", joinTableName, joinTablePrefix];
      if (![PEUtils isNil:entityTablePrefix]) {
        [whereClause appendFormat:@" AND %@.%@ = %@.%@",
         entityTablePrefix,
         joinEntityColumnName,
         joinTablePrefix,
         joinTargetColumnName];
      } else {
        [whereClause appendFormat:@" AND %@ = %@.%@",
         joinEntityColumnName,
         joinTablePrefix,
         joinTargetColumnName];
      }
    }
  }
}

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
      addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
         parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                   entityMasterTable:(NSString *)entityMasterTable
          addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
      masterEntityResultSetConverter:(PELMEntityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
            addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
        mainEntityResultSetConverter:(PELMEntityFromResultSetBlk)mainEntityResultSetConverter
              masterQueryTransformer:(NSString *(^)(NSString *))masterQueryTransformer
          masterArgsArrayTransformer:(NSArray *(^)(NSArray *))masterArgsArrayTransformer
                mainQueryTransformer:(NSString *(^)(NSString *))mainQueryTransformer
            mainArgsArrayTransformer:(NSArray *(^)(NSArray *))mainArgsArrayTransformer
                      entitiesFilter:(NSArray *(^)(NSArray *))entitiesFilter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  [PELMUtils reloadEntity:parentEntity
            fromMainTable:parentEntityMainTable
           addlJoinTables:addlJoinParentEntityMainTables
              rsConverter:parentEntityMainRsConverter
                       db:db
                    error:errorBlk];
  NSMutableArray *entities = [NSMutableArray array];
  if ([parentEntity localMasterIdentifier]) {
    NSArray *argsArray = @[[parentEntity localMasterIdentifier]];
    NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT mstr.*"];
    NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ mstr", entityMasterTable];
    NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE mstr.%@ = ? AND mstr.%@ IS NULL", parentEntityMasterIdColumn, COL_MST_DELETED_DT];
    if ([parentEntity localMainIdentifier]) {
      whereClause = [NSMutableString stringWithFormat:@" WHERE mstr.%@ = ? AND \
mstr.%@ NOT IN (SELECT man.%@ \
                FROM %@ man \
                WHERE man.%@ = ? AND \
                     man.%@ IS NOT NULL) AND mstr.%@ IS NULL",
                     parentEntityMasterIdColumn,
                     COL_GLOBAL_ID,
                     COL_GLOBAL_ID,
                     entityMainTable,
                     parentEntityMainIdColumn,
                     COL_GLOBAL_ID,
                     COL_MST_DELETED_DT];
      argsArray = @[[parentEntity localMasterIdentifier], [parentEntity localMainIdentifier]];
    }
    [PELMUtils incorporateJoinTables:addlJoinEntityMasterTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"mstr"];
    NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
    qry = masterQueryTransformer(qry);
    argsArray = masterArgsArrayTransformer(argsArray);
    NSArray *masterEntities =
    [PELMUtils masterEntitiesFromQuery:qry
                            numAllowed:pageSize
                           entityTable:entityMasterTable
                             argsArray:argsArray
                           rsConverter:masterEntityResultSetConverter
                                    db:db
                                 error:errorBlk];
    /*
     The following is needed to filter the result set.  Although we have our sub-select
     in the SQL query to filter out master entities that are sitting in main, this
     sub-select won't catch them all.  I.e., it won't catch those entities that have been
     edited to be associated with a different parent entity.  I.e., imagine the following:
     1. FPLog-1 belongs to V-1.  They are both in master, and neither are in main.
     2. FPLog-1 is marked for edit.  This brings FPLog-1 and V-1 into their main tables.
     3. FPLog-1 is edited to be associated to V-2 and saved.
     4. Remote sync has not ocurred.
     5. Prune has not ocurred.
     6. FPLog-1 has a row in master, and a row in main.  Its row in main is linked
     to V-2.  Its row in master however is still linked to V-1 (because remote sync
     has not ocurred yet).
     7. In this situation, the query above would include FPLog-1 when V-1's fplogs are
     asked for.  This would be incorrect because FPLog-1 REALLY belongs to V-2, it's
     just that this fact is only reflected in FPLog-1 main.  The following code
     rectifies this by checking to see if FPLog-1 exists in main (by looking it
     up via its global identifier), and if it does, it will not be included in
     the array.
     */
    NSInteger numMasterEntities = [masterEntities count];
    int count = 0;
    for (int i = 0; i < numMasterEntities; i++) {
      PELMModelSupport *masterEntity = masterEntities[i];
      if ([masterEntity globalIdentifier]) {
        NSNumber *localMainIdentifier =
        [PELMUtils numberFromTable:entityMainTable
                      selectColumn:COL_LOCAL_ID
                       whereColumn:COL_GLOBAL_ID
                        whereValue:[masterEntity globalIdentifier]
                                db:db
                             error:errorBlk];
        if (!localMainIdentifier) {
          count++;
          [entities addObject:masterEntity];
        }
      }
    }
  }
  if ([parentEntity localMainIdentifier]) {
    NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT man.*"];
    NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ man", entityMainTable];
    NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE man.%@ = ?", parentEntityMainIdColumn];
    [PELMUtils incorporateJoinTables:addlJoinEntityMainTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"man"];
    NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
    NSArray *argsArray = @[[parentEntity localMainIdentifier]];
    qry = mainQueryTransformer(qry);
    argsArray = mainArgsArrayTransformer(argsArray);
    NSArray *mainEntities = [PELMUtils mainEntitiesFromQuery:qry
                                                  numAllowed:pageSize
                                                 entityTable:entityMainTable
                                                   argsArray:argsArray
                                                 rsConverter:mainEntityResultSetConverter
                                                          db:db
                                                       error:errorBlk];
    NSInteger numMainEntities = [mainEntities count];
    for (int i = 0; i < numMainEntities; i++) {
      PELMMainSupport *mainEntity = mainEntities[i];
      if ([mainEntity globalIdentifier]) {
        NSNumber *masterLocalIdentifier = [PELMUtils numberFromTable:entityMasterTable
                                                        selectColumn:COL_LOCAL_ID
                                                         whereColumn:COL_GLOBAL_ID
                                                          whereValue:[mainEntity globalIdentifier]
                                                                  db:db
                                                               error:errorBlk];
        [mainEntity setCreatedAt:[PELMUtils dateFromTable:entityMasterTable
                                               dateColumn:COL_MST_CREATED_AT
                                              whereColumn:COL_GLOBAL_ID
                                               whereValue:[mainEntity globalIdentifier]
                                                       db:db
                                                    error:errorBlk]];
        [mainEntity setDeletedAt:[PELMUtils dateFromTable:entityMasterTable
                                               dateColumn:COL_MST_DELETED_DT
                                              whereColumn:COL_GLOBAL_ID
                                               whereValue:[mainEntity globalIdentifier]
                                                       db:db
                                                    error:errorBlk]];
        [mainEntity setUpdatedAt:[PELMUtils dateFromTable:entityMasterTable
                                               dateColumn:COL_MST_UPDATED_AT
                                              whereColumn:COL_GLOBAL_ID
                                               whereValue:[mainEntity globalIdentifier]
                                                       db:db
                                                    error:errorBlk]];
        if (masterLocalIdentifier) {
          [mainEntity setLocalMasterIdentifier:masterLocalIdentifier];
        }
      }
    }
    [entities addObjectsFromArray:mainEntities];
  }
  if (entitiesFilter) {
    return entitiesFilter(entities);
  } else {
    return entities;
  }
}

+ (NSArray *)unsyncedEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                       parentEntityMainTable:(NSString *)parentEntityMainTable
              addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
                 parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
                    parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                                    pageSize:(NSNumber *)pageSize
                           entityMasterTable:(NSString *)entityMasterTable
                  addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
                             entityMainTable:(NSString *)entityMainTable
                    addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
                mainEntityResultSetConverter:(PELMEntityFromResultSetBlk)mainEntityResultSetConverter
                        mainQueryTransformer:(NSString *(^)(NSString *))mainQueryTransformer
                    mainArgsArrayTransformer:(NSArray *(^)(NSArray *))mainArgsArrayTransformer
                              entitiesFilter:(NSArray *(^)(NSArray *))entitiesFilter
                                          db:(FMDatabase *)db
                                       error:(PELMDaoErrorBlk)errorBlk {
  [PELMUtils reloadEntity:parentEntity
            fromMainTable:parentEntityMainTable
           addlJoinTables:addlJoinParentEntityMainTables
              rsConverter:parentEntityMainRsConverter
                       db:db
                    error:errorBlk];
  NSMutableArray *entities = [NSMutableArray array];
  if ([parentEntity localMainIdentifier]) {
    NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT man.*"];
    NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ man", entityMainTable];
    NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE man.%@ = ? AND man.%@ = 0", parentEntityMainIdColumn, COL_MAN_SYNCED];
    [PELMUtils incorporateJoinTables:addlJoinEntityMainTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"man"];
    NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
    NSArray *argsArray = @[[parentEntity localMainIdentifier]];
    qry = mainQueryTransformer(qry);
    argsArray = mainArgsArrayTransformer(argsArray);
    NSArray *mainEntities = [PELMUtils mainEntitiesFromQuery:qry
                                                  numAllowed:pageSize
                                                 entityTable:entityMainTable
                                                   argsArray:argsArray
                                                 rsConverter:mainEntityResultSetConverter
                                                          db:db
                                                       error:errorBlk];
    NSInteger numMainEntities = [mainEntities count];
    for (int i = 0; i < numMainEntities; i++) {
      PELMMainSupport *mainEntity = mainEntities[i];
      if ([mainEntity globalIdentifier]) {
        NSNumber *masterLocalIdentifier =
        [PELMUtils numberFromTable:entityMasterTable
                      selectColumn:COL_LOCAL_ID
                       whereColumn:COL_GLOBAL_ID
                        whereValue:[mainEntity globalIdentifier]
                                db:db
                             error:errorBlk];
        if (masterLocalIdentifier) {
          [mainEntity setLocalMasterIdentifier:masterLocalIdentifier];
        }
      }
    }
    [entities addObjectsFromArray:mainEntities];
  }
  if (entitiesFilter) {
    return entitiesFilter(entities);
  } else {
    return entities;
  }
}

+ (NSInteger)numEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                  parentEntityMainTable:(NSString *)parentEntityMainTable
         addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
            parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
             parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
               parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                      entityMasterTable:(NSString *)entityMasterTable
             addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
                        entityMainTable:(NSString *)entityMainTable
               addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
                                  where:(NSString *)where
                               whereArg:(id)whereArg
                                     db:(FMDatabase *)db
                                  error:(PELMDaoErrorBlk)errorBlk {
  NSString *(^masterQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (where) {
      return [qry stringByAppendingFormat:@" AND mstr.%@ ", where];
    }
    return qry;
  };
  NSArray *(^argsArrayTransformer)(NSArray *) = ^ NSArray *(NSArray *argsArray) {
    if (whereArg) {
      return [argsArray arrayByAddingObject:whereArg];
    }
    return argsArray;
  };
  NSString *(^mainQueryTransformer)(NSString *) = ^ NSString *(NSString *qry) {
    if (where) {
      return [qry stringByAppendingFormat:@" AND %@ ", where];
    }
    return qry;
  };
  return [PELMUtils numEntitiesForParentEntity:parentEntity
                         parentEntityMainTable:parentEntityMainTable
                addlJoinParentEntityMainTables:addlJoinParentEntityMainTables
                   parentEntityMainRsConverter:parentEntityMainRsConverter
                    parentEntityMasterIdColumn:parentEntityMasterIdColumn
                      parentEntityMainIdColumn:parentEntityMainIdColumn
                             entityMasterTable:entityMasterTable
                    addlJoinEntityMasterTables:addlJoinEntityMasterTables
                               entityMainTable:entityMainTable
                      addlJoinEntityMainTables:addlJoinEntityMainTables
                        masterQueryTransformer:masterQueryTransformer
                    masterArgsArrayTransformer:argsArrayTransformer
                          mainQueryTransformer:mainQueryTransformer
                      mainArgsArrayTransformer:argsArrayTransformer
                                            db:db
                                         error:errorBlk];
}

+ (NSInteger)numEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                  parentEntityMainTable:(NSString *)parentEntityMainTable
         addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
            parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
             parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
               parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                      entityMasterTable:(NSString *)entityMasterTable
             addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
                        entityMainTable:(NSString *)entityMainTable
               addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
                                     db:(FMDatabase *)db
                                  error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils numEntitiesForParentEntity:parentEntity
                         parentEntityMainTable:parentEntityMainTable
                addlJoinParentEntityMainTables:addlJoinParentEntityMainTables
                   parentEntityMainRsConverter:parentEntityMainRsConverter
                    parentEntityMasterIdColumn:parentEntityMasterIdColumn
                      parentEntityMainIdColumn:parentEntityMainIdColumn
                             entityMasterTable:entityMasterTable
                    addlJoinEntityMasterTables:addlJoinEntityMasterTables
                               entityMainTable:entityMainTable
                      addlJoinEntityMainTables:addlJoinEntityMainTables
                        masterQueryTransformer:^NSString *(NSString *qry){return qry;}
                    masterArgsArrayTransformer:^NSArray *(NSArray *args){return args;}
                          mainQueryTransformer:^NSString *(NSString *qry){return qry;}
                      mainArgsArrayTransformer:^NSArray *(NSArray *args){return args;}
                                            db:db
                                         error:errorBlk];
}

+ (NSInteger)numEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                  parentEntityMainTable:(NSString *)parentEntityMainTable
         addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
            parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
             parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
               parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                      entityMasterTable:(NSString *)entityMasterTable
             addlJoinEntityMasterTables:(NSArray *)addlJoinEntityMasterTables
                        entityMainTable:(NSString *)entityMainTable
               addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
                 masterQueryTransformer:(NSString *(^)(NSString *))masterQueryTransformer
             masterArgsArrayTransformer:(NSArray *(^)(NSArray *))masterArgsArrayTransformer
                   mainQueryTransformer:(NSString *(^)(NSString *))mainQueryTransformer
               mainArgsArrayTransformer:(NSArray *(^)(NSArray *))mainArgsArrayTransformer
                                     db:(FMDatabase *)db
                                  error:(PELMDaoErrorBlk)errorBlk {
  [PELMUtils reloadEntity:parentEntity
            fromMainTable:parentEntityMainTable
           addlJoinTables:addlJoinParentEntityMainTables
              rsConverter:parentEntityMainRsConverter
                       db:db
                    error:errorBlk];
  NSInteger numEntities = 0;
  if ([parentEntity localMasterIdentifier]) {
    NSArray *argsArray = @[[parentEntity localMasterIdentifier]];
    NSString *qry = [NSString stringWithFormat:@"SELECT count(mstr.%@) FROM %@ mstr WHERE mstr.%@ = ? AND mstr.%@ IS NULL",
                     COL_LOCAL_ID,
                     entityMasterTable,
                     parentEntityMasterIdColumn,
                     COL_MST_DELETED_DT];
    qry = masterQueryTransformer(qry);
    BOOL didJoinWithMain = NO;
    NSString *mainMasterQrySansSelectClause =
    [NSString stringWithFormat:@"\
     FROM %@ mstr \
     WHERE mstr.%@ = ? AND \
           mstr.%@ NOT IN (SELECT innerman.%@ \
                           FROM %@ innerman \
                           WHERE innerman.%@ = ? AND \
                                 innerman.%@ IS NOT NULL) AND \
           mstr.%@ IS NULL",
     entityMasterTable,
     parentEntityMasterIdColumn,
     COL_GLOBAL_ID,
     COL_GLOBAL_ID,
     entityMainTable,
     parentEntityMainIdColumn,
     COL_GLOBAL_ID,
     COL_MST_DELETED_DT];
    mainMasterQrySansSelectClause = masterQueryTransformer(mainMasterQrySansSelectClause);
    if ([parentEntity localMainIdentifier]) {
      didJoinWithMain = YES;
      qry = [NSString stringWithFormat:@"SELECT count(mstr.%@) %@",
             COL_GLOBAL_ID,
             mainMasterQrySansSelectClause];
      argsArray = @[[parentEntity localMasterIdentifier], [parentEntity localMainIdentifier]];
    }
    argsArray = masterArgsArrayTransformer(argsArray);
    numEntities += [PELMUtils intFromQuery:qry args:argsArray db:db];
    if (didJoinWithMain) {
      qry = [NSString stringWithFormat:@"SELECT count(outman.%@) from %@ outman WHERE outman.%@ IN (SELECT mstr.%@ %@)",
             COL_LOCAL_ID,
             entityMainTable,
             COL_GLOBAL_ID,
             COL_GLOBAL_ID,
             mainMasterQrySansSelectClause];
      NSInteger numMainMasterEntities = [PELMUtils intFromQuery:qry args:argsArray db:db];
      numEntities -= numMainMasterEntities;
    }
  }
  if ([parentEntity localMainIdentifier]) {
    NSString *qry = [NSString stringWithFormat:@"\
                     SELECT count(%@) \
                     FROM %@ \
                     WHERE %@ = ?",
                     COL_LOCAL_ID,
                     entityMainTable,
                     parentEntityMainIdColumn];
    qry = mainQueryTransformer(qry);
    NSArray *argsArray = @[[parentEntity localMainIdentifier]];
    argsArray = mainArgsArrayTransformer(argsArray);
    numEntities += [PELMUtils intFromQuery:qry args:argsArray db:db];
  }
  return numEntities;
}

+ (PELMMainSupport *)parentForChildEntity:(PELMMainSupport *)childEntity
                    parentEntityMainTable:(NSString *)parentEntityMainTable
           addlJoinParentEntityMainTables:(NSArray *)addlJoinParentEntityMainTables
                  parentEntityMasterTable:(NSString *)parentEntityMasterTable
         addlJoinParentEntityMasterTables:(NSArray *)addlJoinParentEntityMasterTables
                 parentEntityMainFkColumn:(NSString *)parentEntityMainFkColumn
               parentEntityMasterFkColumn:(NSString *)parentEntityMasterFkColumn
              parentEntityMainRsConverter:(PELMEntityFromResultSetBlk)parentEntityMainRsConverter
            parentEntityMasterRsConverter:(PELMEntityFromResultSetBlk)parentEntityMasterRsConverter
                     childEntityMainTable:(NSString *)childEntityMainTable
            addlJoinChildEntityMainTables:(NSArray *)addlJoinChildEntityMainTables
               childEntityMainRsConverter:(PELMEntityFromResultSetBlk)childEntityMainRsConverter
                   childEntityMasterTable:(NSString *)childEntityMasterTable
                                       db:(FMDatabase *)db
                                    error:(PELMDaoErrorBlk)errorBlk {
  [PELMUtils reloadEntity:childEntity
            fromMainTable:childEntityMainTable
           addlJoinTables:addlJoinChildEntityMainTables
              rsConverter:childEntityMainRsConverter
                       db:db
                    error:errorBlk];
  if ([childEntity localMainIdentifier]) {
    NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT manparent.*"];
    NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ manparent", parentEntityMainTable];
    NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE manparent.%@ IN (SELECT child.%@ FROM %@ child WHERE child.%@ = ?)",
                                     COL_LOCAL_ID,
                                     parentEntityMainFkColumn,
                                     childEntityMainTable,
                                     COL_LOCAL_ID];
    [PELMUtils incorporateJoinTables:addlJoinParentEntityMainTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"manparent"];
    NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
    PELMMainSupport *parentMainEntity = [PELMUtils entityFromQuery:qry
                                                       entityTable:parentEntityMainTable
                                                     localIdGetter:^NSNumber *(PELMModelSupport *entity){return [entity localMainIdentifier];}
                                                         argsArray:@[[childEntity localMainIdentifier]]
                                                       rsConverter:parentEntityMainRsConverter
                                                                db:db
                                                             error:errorBlk];
    if (parentMainEntity) {
      if ([parentMainEntity globalIdentifier]) {
        NSNumber *localMasterIdentifier = [PELMUtils numberFromTable:parentEntityMasterTable
                                                        selectColumn:COL_LOCAL_ID
                                                         whereColumn:COL_GLOBAL_ID
                                                          whereValue:[parentMainEntity globalIdentifier]
                                                                  db:db
                                                               error:errorBlk];
        [parentMainEntity setCreatedAt:[PELMUtils dateFromTable:parentEntityMasterTable
                                               dateColumn:COL_MST_CREATED_AT
                                              whereColumn:COL_GLOBAL_ID
                                               whereValue:[parentMainEntity globalIdentifier]
                                                       db:db
                                                    error:errorBlk]];
        [parentMainEntity setDeletedAt:[PELMUtils dateFromTable:parentEntityMasterTable
                                                     dateColumn:COL_MST_DELETED_DT
                                                    whereColumn:COL_GLOBAL_ID
                                                     whereValue:[parentMainEntity globalIdentifier]
                                                             db:db
                                                          error:errorBlk]];
        [parentMainEntity setUpdatedAt:[PELMUtils dateFromTable:parentEntityMasterTable
                                               dateColumn:COL_MST_UPDATED_AT
                                              whereColumn:COL_GLOBAL_ID
                                               whereValue:[parentMainEntity globalIdentifier]
                                                       db:db
                                                    error:errorBlk]];
        if (localMasterIdentifier) {
          [parentMainEntity setLocalMasterIdentifier:localMasterIdentifier];
        }
      }
    }
    return parentMainEntity;
  } else if ([childEntity localMasterIdentifier]) {
    NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT masparent.*"];
    NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ masparent", parentEntityMasterTable];
    NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE masparent.%@ IN (SELECT child.%@ FROM %@ child WHERE child.%@ = ?)",
                                     COL_LOCAL_ID,
                                     parentEntityMasterFkColumn,
                                     childEntityMasterTable,
                                     COL_LOCAL_ID];
    [PELMUtils incorporateJoinTables:addlJoinParentEntityMasterTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"masparent"];
    NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
    PELMMainSupport *masterEntity = [PELMUtils entityFromQuery:qry
                                                   entityTable:parentEntityMasterTable
                                                 localIdGetter:^NSNumber *(PELMModelSupport *entity){return [entity localMasterIdentifier];}
                                                     argsArray:@[[childEntity localMasterIdentifier]]
                                                   rsConverter:parentEntityMasterRsConverter
                                                            db:db
                                                         error:errorBlk];
    if (masterEntity) {
      if ([masterEntity globalIdentifier]) {
        NSNumber *localMainIdentifier = [PELMUtils numberFromTable:parentEntityMainTable
                                                      selectColumn:COL_LOCAL_ID
                                                       whereColumn:COL_GLOBAL_ID
                                                        whereValue:[masterEntity globalIdentifier]
                                                                db:db
                                                             error:errorBlk];
        if (localMainIdentifier) {
          [masterEntity setLocalMainIdentifier:localMainIdentifier];
        }
      }
    }
    return masterEntity;
  } else {
    return nil;
  }
}

+ (PELMMainSupport *)masterParentForMasterChildEntity:(PELMMainSupport *)childEntity
                              parentEntityMasterTable:(NSString *)parentEntityMasterTable
                     addlJoinParentEntityMasterTables:(NSArray *)addlJoinParentEntityMasterTables
                           parentEntityMasterFkColumn:(NSString *)parentEntityMasterFkColumn
                        parentEntityMasterRsConverter:(PELMEntityFromResultSetBlk)parentEntityMasterRsConverter
                               childEntityMasterTable:(NSString *)childEntityMasterTable
                                                   db:(FMDatabase *)db
                                                error:(PELMDaoErrorBlk)errorBlk {
  if ([childEntity localMasterIdentifier]) {
    NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT masparent.*"];
    NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ masparent", parentEntityMasterTable];
    NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE masparent.%@ IN (SELECT child.%@ FROM %@ child WHERE child.%@ = ?)",
                                     COL_LOCAL_ID,
                                     parentEntityMasterFkColumn,
                                     childEntityMasterTable,
                                     COL_LOCAL_ID];
    [PELMUtils incorporateJoinTables:addlJoinParentEntityMasterTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"masparent"];
    NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
    return [PELMUtils entityFromQuery:qry
                          entityTable:parentEntityMasterTable
                        localIdGetter:^NSNumber *(PELMModelSupport *entity){return [entity localMasterIdentifier];}
                            argsArray:@[[childEntity localMasterIdentifier]]
                          rsConverter:parentEntityMasterRsConverter
                                   db:db
                                error:errorBlk];
  }
  return nil;
}

+ (NSNumber *)localMainIdentifierForEntity:(PELMModelSupport *)entity
                                 mainTable:(NSString *)mainTable
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk {
  void (^consistencyCheck)(NSNumber *, NSNumber *) = ^(NSNumber *foundLocalId, NSNumber *localId) {
    if (localId && foundLocalId) {
      if (![foundLocalId isEqualToNumber:localId]) {
        @throw [NSException
                exceptionWithName:NSInternalInconsistencyException
                reason:[NSString stringWithFormat:@"Inside \
localMainIdentifierForEntity:mainTable:db:error: - found local main ID [%@] is \
different from the local main ID [%@] on the in-memory entity with global \
ID: [%@].", foundLocalId, localId, [entity globalIdentifier]]
                userInfo:nil];
      }
    }
  };
  NSNumber *foundMainLocalIdentifier = nil;
  if ([entity globalIdentifier]) {
    // our first choice is to lookup the entity by global ID
    foundMainLocalIdentifier = [PELMUtils numberFromTable:mainTable
                                             selectColumn:COL_LOCAL_ID
                                              whereColumn:COL_GLOBAL_ID
                                               whereValue:[entity globalIdentifier]
                                                       db:db
                                                    error:errorBlk];
    // we do this to help weed-out bugs in the design
    consistencyCheck(foundMainLocalIdentifier, [entity localMainIdentifier]);
  }
  if (!foundMainLocalIdentifier) {
    if ([entity localMainIdentifier]) {
      // our second choice is to lookup the entity using its in-memory local main id
      foundMainLocalIdentifier = [PELMUtils numberFromTable:mainTable
                                               selectColumn:COL_LOCAL_ID
                                                whereColumn:COL_LOCAL_ID
                                                 whereValue:[entity localMainIdentifier]
                                                         db:db
                                                      error:errorBlk];
      // we do this to help weed-out bugs in the design
      consistencyCheck(foundMainLocalIdentifier, [entity localMainIdentifier]);
    }
  }
  return foundMainLocalIdentifier;
}

- (void)reloadEntity:(PELMModelSupport *)entity
       fromMainTable:(NSString *)mainTable
      addlJoinTables:(NSArray *)addlJoinTables
         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
               error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    [PELMUtils reloadEntity:entity
              fromMainTable:mainTable
             addlJoinTables:addlJoinTables
                rsConverter:rsConverter
                         db:db
                      error:errorBlk];
  }];
}

+ (void)reloadEntity:(PELMModelSupport *)entity
       fromMainTable:(NSString *)mainTable
      addlJoinTables:(NSArray *)addlJoinTables
         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                  db:db
               error:(PELMDaoErrorBlk)errorBlk {
  NSString *globalIdentifier = [entity globalIdentifier];
  if (globalIdentifier) {
    NSNumber *foundMainLocalIdentifier = [PELMUtils numberFromTable:mainTable
                                                       selectColumn:COL_LOCAL_ID
                                                        whereColumn:COL_GLOBAL_ID
                                                         whereValue:globalIdentifier
                                                                 db:db
                                                              error:errorBlk];
    if (foundMainLocalIdentifier) {
      
      NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT *"];
      NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@ man", mainTable];
      NSMutableString *whereClause  = [NSMutableString stringWithFormat:@" WHERE man.%@ = ?", COL_LOCAL_ID];
      [PELMUtils incorporateJoinTables:addlJoinTables intoSelectClause:selectClause fromClause:fromClause whereClause:whereClause entityTablePrefix:@"man"];
      NSString *qry = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, whereClause];
      PELMModelSupport *foundEntity = [PELMUtils entityFromQuery:qry
                                                     entityTable:mainTable
                                                   localIdGetter:^NSNumber *(PELMModelSupport *entity){return [entity localMainIdentifier];}
                                                       argsArray:@[foundMainLocalIdentifier]
                                                     rsConverter:rsConverter
                                                              db:db
                                                           error:errorBlk];
      if (foundEntity) {
        [entity overwrite:foundEntity];
        [entity setLocalMainIdentifier:[foundEntity localMainIdentifier]];
      }
    }
  }
}

+ (void)copyMasterEntity:(PELMMainSupport *)entity
             toMainTable:(NSString *)mainTable
    mainTableInserterBlk:(void(^)(PELMMasterSupport *))mainTableInserter
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk {
  void (^copyToMainAction)(void) = ^{
    [entity setSynced:YES];
    [entity setDateCopiedFromMaster:[NSDate date]];
    mainTableInserter(entity);
    [PELMUtils insertRelations:[entity relations]
                     forEntity:entity
                   entityTable:mainTable
               localIdentifier:[entity localMainIdentifier]
                            db:db
                         error:errorBlk];
  };
  NSNumber *foundLocalMainId = [PELMUtils localMainIdentifierForEntity:entity
                                                             mainTable:mainTable
                                                                    db:db
                                                                 error:errorBlk];
  if (!foundLocalMainId) {
    if (![entity globalIdentifier]) {
      @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                     reason:[NSString stringWithFormat:@"Inside \
copyMasterEntity:toMainTable:..., we couldn't find the main entity associated \
with the in-memory localMainIdentifier in the main table, so the assumption is \
that 'entity' is a master entity, and that we need to copy it into its main \
table.  The problem is, it doesn't have a global ID, so this is bad (i.e., we \
have a consistency violation; our database is in an inconsistent state).  \
Entity: %@", entity]
                                   userInfo:nil];
    }
    copyToMainAction();
  } else {
    [entity setLocalMainIdentifier:foundLocalMainId];
  }
}

+ (NSNumber *)masterLocalIdFromEntityTable:(NSString *)masterEntityTable
                          globalIdentifier:(NSString *)globalIdentifier
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils numberFromTable:masterEntityTable
                       selectColumn:COL_LOCAL_ID
                        whereColumn:COL_GLOBAL_ID
                         whereValue:globalIdentifier
                                 db:db
                              error:errorBlk];
}

+ (NSDictionary *)relationsForEntity:(PELMModelSupport *)entity
                         entityTable:(NSString *)entityTable
                     localIdentifier:(NSNumber *)localIdentifier
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  NSString *relsTable = [PELMDDL relTableForEntityTable:entityTable];
  NSString *whereColumn = [PELMDDL relFkColumnForEntityTable:entityTable
                                              entityPkColumn:COL_LOCAL_ID];
  NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?",
                     relsTable, whereColumn];
  FMResultSet *rs = [db executeQuery:query
                withArgumentsInArray:@[localIdentifier]];
  NSMutableDictionary *relations = [NSMutableDictionary dictionary];
  while ([rs next]) {
    HCRelation *relation = [PELMUtils relationFromResultSet:rs
                                       subjectResourceModel:entity];
    [relations setObject:relation forKey:[relation name]];
  }
  [rs close];
  return relations;
}

+ (void)setRelationsForEntity:(PELMModelSupport *)entity
                  entityTable:(NSString *)entityTable
              localIdentifier:(NSNumber *)localIdentifier
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk {
  [entity setRelations:[PELMUtils relationsForEntity:entity
                                         entityTable:entityTable
                                     localIdentifier:localIdentifier
                                                  db:db
                                               error:errorBlk]];
}

+ (void)updateRelationsForEntity:(PELMModelSupport *)entity
                     entityTable:(NSString *)entityTable
                 localIdentifier:(NSNumber *)localIdentifier
                              db:(FMDatabase *)db
                           error:(PELMDaoErrorBlk)errorBlk {
  [PELMUtils deleteRelationsFromEntityTable:entityTable
                            localIdentifier:localIdentifier
                                         db:db
                                      error:errorBlk];
  [PELMUtils insertRelations:[entity relations]
                   forEntity:entity
                 entityTable:entityTable
             localIdentifier:localIdentifier
                          db:db
                       error:errorBlk];
}

+ (void)insertRelations:(NSDictionary *)relations
              forEntity:(PELMModelSupport *)entity
            entityTable:(NSString *)entityTable
        localIdentifier:(NSNumber *)localIdentifier
                     db:(FMDatabase *)db
                  error:(PELMDaoErrorBlk)errorBlk {
  NSString *relsTable = [PELMDDL relTableForEntityTable:entityTable];
  NSString *fkColumn = [PELMDDL relFkColumnForEntityTable:entityTable
                                           entityPkColumn:COL_LOCAL_ID];
  NSString *stmt = [NSString stringWithFormat:@"INSERT INTO %@(%@, %@, %@, %@) \
                    VALUES (?, ?, ?, ?)", relsTable, fkColumn, COL_REL_NAME, COL_REL_URI,
                    COL_REL_MEDIA_TYPE];
  [relations enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    HCRelation *relation = (HCRelation *)obj;
    [PELMUtils doUpdate:stmt
              argsArray:@[localIdentifier,
                          [relation name],
                          [[[relation target] uri] absoluteString],
                          [[[relation target] mediaType] description]]
                     db:db
                  error:errorBlk];
  }];
}

- (NSArray *)markEntitiesAsSyncInProgressInMainTable:(NSString *)mainTable
                                          usingQuery:(NSString *)query
                                 entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
                                          updateStmt:(NSString *)updateStmt
                                       updateArgsBlk:(NSArray *(^)(PELMMainSupport *))updateArgsBlk
                                           filterBlk:(BOOL(^)(PELMMainSupport *))filterBlk
                                               error:(PELMDaoErrorBlk)errorBlk {
  void (^markSyncInProgressAction)(PELMMainSupport *, FMDatabase *) = ^ (PELMMainSupport *entity, FMDatabase *db) {
    [entity setSyncInProgress:YES];
    [PELMUtils doUpdate:updateStmt
              argsArray:updateArgsBlk(entity)
                     db:db
                  error:errorBlk];
  };
  __block NSArray *resultEntities = nil;
  NSMutableArray *entitesToSync = [NSMutableArray array];
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    resultEntities =
    [PELMUtils mainEntitiesFromQuery:query
                         entityTable:mainTable
                           argsArray:@[]
                         rsConverter:entityFromResultSet
                                  db:db
                               error:errorBlk];
    for (PELMMainSupport *entity in resultEntities) {
      if (![entity editInProgress] &&
          ![entity syncInProgress] &&
          ![entity synced] &&
          (([entity syncErrMask] == nil) ||
           ([entity syncErrMask].integerValue <= 0)) && // less than zero means it represents a system connectivity-related issue (thus temporary); zero occurs if no explicit err-mask header was in response
          (([entity syncHttpRespCode] == nil) ||
           ([entity syncHttpRespCode].integerValue == 401) ||
           ([entity syncHttpRespCode].integerValue == 409) ||
           ([entity syncHttpRespCode].integerValue == 503) ||
           ([entity syncHttpRespCode].integerValue == 502) ||
           ([entity syncHttpRespCode].integerValue == 504) ||
           ([entity syncHttpRespCode].integerValue == 500)) && // each of these err codes can be temporary, so even if the previous sync attempt yielded one of these, we can still try again on the next attempt
          (([entity syncRetryAt] == nil) ||
           ([[NSDate date] compare:[entity syncRetryAt]] == NSOrderedDescending))) {
            if (filterBlk) {
              if (filterBlk(entity)) {
                markSyncInProgressAction(entity, db);
                [entitesToSync addObject:entity];
              }
            } else {
              markSyncInProgressAction(entity, db); // no filter provided, therefore we do action
              [entitesToSync addObject:entity];
            }
          }
    }
  }];
  return entitesToSync;
}

- (NSArray *)markEntitiesAsSyncInProgressInMainTable:(NSString *)mainTable
                                 entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
                                          updateStmt:(NSString *)updateStmt
                                       updateArgsBlk:(NSArray *(^)(PELMMainSupport *))updateArgsBlk
                                               error:(PELMDaoErrorBlk)errorBlk {
  return [self markEntitiesAsSyncInProgressInMainTable:mainTable
                                            usingQuery:[NSString stringWithFormat:@"SELECT * FROM %@", mainTable]
                                   entityFromResultSet:entityFromResultSet
                                            updateStmt:updateStmt
                                         updateArgsBlk:updateArgsBlk
                                             filterBlk:nil
                                                 error:errorBlk];
}

+ (BOOL)prepareEntityForEdit:(PELMMainSupport *)entity
                          db:(FMDatabase *)db
                   mainTable:(NSString *)mainTable
         entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
          mainEntityInserter:(PELMMainEntityInserterBlk)mainEntityInserter
           mainEntityUpdater:(PELMMainEntityUpdaterBlk)mainEntityUpdater
                       error:(PELMDaoErrorBlk)errorBlk {
  void (^actionIfEntityNotInMain)(void) = ^{
    [entity setEditInProgress:YES];
    [entity setSynced:NO];
    [entity setDateCopiedFromMaster:[NSDate date]];
    [entity setEditCount:1];
    mainEntityInserter(entity, db, errorBlk);
    [PELMUtils insertRelations:[entity relations]
                     forEntity:entity
                   entityTable:mainTable
               localIdentifier:[entity localMainIdentifier]
                            db:db
                         error:errorBlk];
  };
  void (^actionIfEntityAlreadyInMain)(void) = ^{
    [entity setEditInProgress:YES];
    [entity setSynced:NO];
    [entity incrementEditCount];
    mainEntityUpdater(entity, db, errorBlk);
  };
  NSString *(^mainEntityFetchQueryBlk)(NSString *) = ^NSString *(NSString *whereCol) {
    return [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?", mainTable, whereCol];
  };
  NSString *mainEntityFetchQuery;
  NSArray *mainEntityFetchQueryArgs;
  if ([entity globalIdentifier]) {
    mainEntityFetchQuery = mainEntityFetchQueryBlk(COL_GLOBAL_ID);
    mainEntityFetchQueryArgs = @[[entity globalIdentifier]];
  } else {
    mainEntityFetchQuery = mainEntityFetchQueryBlk(COL_LOCAL_ID);
    mainEntityFetchQueryArgs = @[[entity localMainIdentifier]];
  }
  PELMMainSupport *fetchedEntity = (PELMMainSupport *)
    [PELMUtils entityFromQuery:mainEntityFetchQuery
                   entityTable:mainTable
                 localIdGetter:^NSNumber *(PELMModelSupport *entity) {return [entity localMainIdentifier];}
                     argsArray:mainEntityFetchQueryArgs
                   rsConverter:entityFromResultSet
                            db:db
                         error:errorBlk];
  if (!fetchedEntity) {
    actionIfEntityNotInMain();
  } else {
    [entity setLocalMainIdentifier:[fetchedEntity localMainIdentifier]];
    [entity overwrite:fetchedEntity];
    actionIfEntityAlreadyInMain();
  }
  return YES;
}

- (BOOL)prepareEntityForEditInTxn:(PELMMainSupport *)entity
                        mainTable:(NSString *)mainTable
              entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
               mainEntityInserter:(PELMMainEntityInserterBlk)mainEntityInserter
                mainEntityUpdater:(PELMMainEntityUpdaterBlk)mainEntityUpdater
                            error:(PELMDaoErrorBlk)errorBlk {
  NSAssert([entity localMainIdentifier], @"Entity does not have a localMainIdentifier.");
  __block BOOL returnVal;
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    returnVal = [PELMUtils prepareEntityForEdit:entity
                                             db:db
                                      mainTable:mainTable
                            entityFromResultSet:entityFromResultSet
                             mainEntityInserter:mainEntityInserter
                              mainEntityUpdater:mainEntityUpdater
                                          error:errorBlk];
  }];
  return returnVal;
}

+ (void)invokeError:(PELMDaoErrorBlk)errorBlk db:(FMDatabase *)db {
  errorBlk([db lastError], [db lastErrorCode], [db lastErrorMessage]);
}

+ (void)deleteEntity:(PELMModelSupport *)entity
     entityMainTable:(NSString *)entityMainTable
   entityMasterTable:(NSString *)entityMasterTable
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk {
  [self deleteFromEntityTable:entityMainTable
              localIdentifier:[entity localMainIdentifier]
                           db:db
                        error:errorBlk];
  [self deleteFromEntityTable:entityMasterTable
              localIdentifier:[entity localMasterIdentifier]
                           db:db
                        error:errorBlk];
}

+ (void)deleteFromEntityTable:(NSString *)entityTable
              localIdentifier:(NSNumber *)localIdentifier
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk {
  if (localIdentifier) {
    [PELMUtils deleteRelationsFromEntityTable:entityTable
                              localIdentifier:localIdentifier
                                           db:db
                                        error:errorBlk];
    [self deleteFromTable:entityTable
             whereColumns:@[COL_LOCAL_ID]
              whereValues:@[localIdentifier]
                       db:db
                    error:errorBlk];
  }
}

+ (void)deleteRelationsFromEntityTable:(NSString *)entityTable
                       localIdentifier:(NSNumber *)localIdentifier
                                    db:(FMDatabase *)db
                                 error:(PELMDaoErrorBlk)errorBlk {
  NSString *relsTable = [PELMDDL relTableForEntityTable:entityTable];
  NSString *delWhereColumn = [PELMDDL relFkColumnForEntityTable:entityTable
                                                 entityPkColumn:COL_LOCAL_ID];
  [self deleteFromTable:relsTable
           whereColumns:@[delWhereColumn]
            whereValues:@[localIdentifier]
                     db:db
                  error:errorBlk];
}

+ (void)deleteFromTable:(NSString *)table
           whereColumns:(NSArray *)whereColumns
            whereValues:(NSArray *)whereValues
                     db:(FMDatabase *)db
                  error:(PELMDaoErrorBlk)errorBlk {
  NSMutableString *stmt = [NSMutableString stringWithFormat:@"DELETE FROM %@", table];
  NSUInteger numColumns = [whereColumns count];
  if (numColumns > 0) {
    [stmt appendString:@" WHERE "];
  }
  for (int i = 0; i < numColumns; i++) {
    [stmt appendFormat:@"%@ = ?", [whereColumns objectAtIndex:i]];
    if ((i + 1) < numColumns) {
      [stmt appendString:@" AND "];
    }
  }
  [self doUpdate:stmt argsArray:whereValues db:db error:errorBlk];
}

- (void)deleteFromTableInTxn:(NSString *)table
                whereColumns:(NSArray *)whereColumns
                 whereValues:(NSArray *)whereValues
                       error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [PELMUtils deleteFromTable:table
                  whereColumns:whereColumns
                   whereValues:whereValues
                            db:db
                         error:errorBlk];
  }];
}

+ (void)deleteFromTables:(NSArray *)tables
            whereColumns:(NSArray *)whereColumns
             whereValues:(NSArray *)whereValues
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk {
  for (NSString *table in tables) {
    [self deleteFromTable:table
             whereColumns:whereColumns
              whereValues:whereValues
                       db:db
                    error:errorBlk];
  }
}

- (void)deleteFromTablesInTxn:(NSArray *)tables
                 whereColumns:(NSArray *)whereColumns
                  whereValues:(NSArray *)whereValues
                        error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [PELMUtils deleteFromTables:tables
                   whereColumns:whereColumns
                    whereValues:whereValues
                             db:db
                          error:errorBlk];
  }];
}

- (void)pruneAllSyncedFromMainTables:(NSArray *)tableNames
                               error:(PELMDaoErrorBlk)errorBlk {
  NSString *entityKey = @"entity";
  NSString *tableKey = @"table";
  NSMutableArray *syncedEntitiesDicts = [NSMutableArray array];
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    for (NSString *table in tableNames) {
      FMResultSet *rs =
      [PELMUtils doQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = 1", table, COL_MAN_SYNCED]
               argsArray:@[]
                      db:db
                   error:errorBlk];
      while ([rs next]) {
        [syncedEntitiesDicts addObject:[NSDictionary dictionaryWithObjects:@[toMainSupport(rs, table, nil), table] forKeys:@[entityKey, tableKey]]];
      }
      [rs close];
    }
  }];
  for (NSDictionary *syncedEntityDict in syncedEntitiesDicts) {
    PELMMainSupport *syncedEntity = [syncedEntityDict objectForKey:entityKey];
    if ([syncedEntity localMainIdentifier]) { // it shouldn't be possible for localMainIdentifier to be nil here, but, just 'cause
      NSString *table = [syncedEntityDict objectForKey:tableKey];
      [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [PELMUtils deleteRelationsFromEntityTable:table
                                  localIdentifier:[syncedEntity localMainIdentifier]
                                               db:db
                                            error:errorBlk];
        [PELMUtils doUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?", table, COL_LOCAL_ID]
                  argsArray:@[[syncedEntity localMainIdentifier]]
                         db:db
                      error:^ (NSError *err, int code, NSString *msg) {
                        *rollback = YES;
                        errorBlk(err, code, msg);
                      }];
      }];
    }
  }
}

+ (void)doMainInsert:(NSString *)stmt
           argsArray:(NSArray *)argsArray
              entity:(PELMMainSupport *)entity
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk {
  [self doInsert:stmt
       argsArray:argsArray
          entity:entity
      idAssigner:^(PELMModelSupport *entity, NSNumber *newId) { [entity setLocalMainIdentifier:newId]; }
              db:db
           error:errorBlk];
}

+ (void)doMasterInsert:(NSString *)stmt
             argsArray:(NSArray *)argsArray
                entity:(PELMModelSupport *)entity
                    db:(FMDatabase *)db
                 error:(PELMDaoErrorBlk)errorBlk {
  [self doInsert:stmt
       argsArray:argsArray
          entity:entity
      idAssigner:^(PELMModelSupport *entity, NSNumber *newId) { [entity setLocalMasterIdentifier:newId]; }
              db:db
           error:errorBlk];
}

+ (void)doInsert:(NSString *)stmt
       argsArray:(NSArray *)argsArray
          entity:(PELMModelSupport *)entity
      idAssigner:(void(^)(PELMModelSupport *, NSNumber *))idAssigner
              db:(FMDatabase *)db
           error:(PELMDaoErrorBlk)errorBlk {
  if ([db executeUpdate:stmt withArgumentsInArray:argsArray]) {
    idAssigner(entity, [NSNumber numberWithLongLong:[db lastInsertRowId]]);
    [PELMUtils postDbUpdateNotification];
  } else {
    [self invokeError:errorBlk db:db];
  }
}

+(void)doUpdate:(NSString *)stmt
             db:(FMDatabase *)db
          error:(PELMDaoErrorBlk)errorBlk {
  [self doUpdate:stmt argsArray:nil db:db error:errorBlk];
}

+ (void)doUpdate:(NSString *)stmt
       argsArray:(NSArray *)argsArray
              db:(FMDatabase *)db
           error:(PELMDaoErrorBlk)errorBlk {
  if ([db executeUpdate:stmt withArgumentsInArray:argsArray]) {
    [PELMUtils postDbUpdateNotification];
  } else {
    [self invokeError:errorBlk db:db];
  }
}

- (void)doUpdateInTxn:(NSString *)stmt
            argsArray:(NSArray *)argsArray
                error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [PELMUtils doUpdate:stmt argsArray:argsArray db:db error:errorBlk];
  }];
}

+ (FMResultSet *)doQuery:(NSString *)query
               argsArray:(NSArray *)argsArray
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk {
  FMResultSet *rs = [db executeQuery:query withArgumentsInArray:argsArray];
  if (!rs) {
    [self invokeError:errorBlk db:db];
  }
  return rs;
}

+ (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                   db:(FMDatabase *)db
                error:(PELMDaoErrorBlk)errorBlk {
  return [self entityFromQuery:query
                   entityTable:entityTable
                 localIdGetter:localIdGetter
                     argsArray:@[]
                   rsConverter:rsConverter
                            db:db
                         error:errorBlk];
}

+ (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
            argsArray:(NSArray *)argsArray
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                   db:(FMDatabase *)db
                error:(PELMDaoErrorBlk)errorBlk {
  id entity = nil;
  FMResultSet *rs = [self doQuery:query argsArray:argsArray db:db error:errorBlk];
  if (rs) {
    while ([rs next]) {
      entity = rsConverter(rs);
    }
    [rs close];
  }
  if (entity) {
    [PELMUtils setRelationsForEntity:entity
                         entityTable:entityTable
                     localIdentifier:localIdGetter(entity)
                                  db:db
                               error:errorBlk];
  }
  return entity;
}

- (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                error:(PELMDaoErrorBlk)errorBlk {
  return [self entityFromQuery:query
                   entityTable:entityTable
                 localIdGetter:localIdGetter
                     argsArray:@[]
                   rsConverter:rsConverter
                         error:errorBlk];
}

- (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
            argsArray:(NSArray *)argsArray
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                error:(PELMDaoErrorBlk)errorBlk {
  __block id entity = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    entity = [PELMUtils entityFromQuery:query
                            entityTable:entityTable
                          localIdGetter:localIdGetter
                              argsArray:argsArray
                            rsConverter:rsConverter
                                     db:db
                                  error:errorBlk];
  }];
  return entity;
}

+ (NSArray *)mainEntitiesFromQuery:(NSString *)query
                       entityTable:(NSString *)entityTable
                         argsArray:(NSArray *)argsArray
                       rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                db:(FMDatabase *)db
                             error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils mainEntitiesFromQuery:query
                               numAllowed:nil
                              entityTable:entityTable
                                argsArray:argsArray
                              rsConverter:rsConverter
                                       db:db
                                    error:errorBlk];
}

+ (NSArray *)masterEntitiesFromQuery:(NSString *)query
                         entityTable:(NSString *)entityTable
                           argsArray:(NSArray *)argsArray
                         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils masterEntitiesFromQuery:query
                                 numAllowed:nil
                                entityTable:entityTable
                                  argsArray:argsArray
                                rsConverter:rsConverter
                                         db:db
                                      error:errorBlk];
}

+ (NSArray *)mainEntitiesFromQuery:(NSString *)query
                        numAllowed:(NSNumber *)numAllowed
                       entityTable:(NSString *)entityTable
                         argsArray:(NSArray *)argsArray
                       rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                db:(FMDatabase *)db
                             error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils entitiesFromQuery:query
                           numAllowed:numAllowed
                          entityTable:entityTable
                        localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMainIdentifier]; }
                            argsArray:argsArray
                          rsConverter:rsConverter
                                   db:db
                                error:errorBlk];
}

+ (NSArray *)masterEntitiesFromQuery:(NSString *)query
                          numAllowed:(NSNumber *)numAllowed
                         entityTable:(NSString *)entityTable
                           argsArray:(NSArray *)argsArray
                         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils entitiesFromQuery:query
                           numAllowed:numAllowed
                          entityTable:entityTable
                        localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMasterIdentifier]; }
                            argsArray:argsArray
                          rsConverter:rsConverter
                                   db:db
                                error:errorBlk];
}

+ (NSArray *)entitiesFromQuery:(NSString *)query
                    numAllowed:(NSNumber *)numAllowed
                   entityTable:(NSString *)entityTable
                 localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
                     argsArray:(NSArray *)argsArray
                   rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                            db:(FMDatabase *)db
                         error:(PELMDaoErrorBlk)errorBlk {
  NSMutableArray *entities = [NSMutableArray array];
  FMResultSet *rs = [self doQuery:query argsArray:argsArray db:db error:errorBlk];
  BOOL closedResultSet = NO;
  if (rs) {
    int count = 0;
    while ([rs next]) {
      if (numAllowed && (count == [numAllowed intValue])) {
        [rs close];
        closedResultSet = YES;
        break;
      }
      [entities addObject:rsConverter(rs)];
      count++;
    }
    if (!closedResultSet) {
      [rs close];
    }
  }
  for (PELMModelSupport *entity in entities) {
    [PELMUtils setRelationsForEntity:entity
                         entityTable:entityTable
                     localIdentifier:localIdGetter(entity)
                                  db:db
                               error:errorBlk];
  }
  return entities;
}

+ (NSArray *)entitiesFromEntityTable:(NSString *)entityTable
                      addlJoinTables:(NSArray *)addlJoinTables
                         whereClause:(NSString *)whereClause
                       localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
                           argsArray:(NSArray *)argsArray
                         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk {
  NSMutableString *selectClause = [NSMutableString stringWithString:@"SELECT *"];
  NSMutableString *fromClause   = [NSMutableString stringWithFormat:@" FROM %@", entityTable];
  NSMutableString *theWhereClause  = [NSMutableString stringWithFormat:@" WHERE %@", whereClause];
  [PELMUtils incorporateJoinTables:addlJoinTables intoSelectClause:selectClause fromClause:fromClause whereClause:theWhereClause entityTablePrefix:nil];
  NSString *query = [NSString stringWithFormat:@"%@%@%@", selectClause, fromClause, theWhereClause];
  return [PELMUtils entitiesFromQuery:query
                           numAllowed:nil
                          entityTable:entityTable
                        localIdGetter:localIdGetter
                            argsArray:argsArray
                          rsConverter:rsConverter
                                   db:db
                                error:errorBlk];
}

#pragma mark - Result set -> Model helpers (private)

+ (HCRelation *)relationFromResultSet:(FMResultSet *)rs
                 subjectResourceModel:(PELMModelSupport *)subjectResourceModel {
  HCResource *subjectResource =
  [[HCResource alloc]
   initWithMediaType:[subjectResourceModel mediaType]
   uri:[NSURL URLWithString:[subjectResourceModel globalIdentifier]]];
  HCResource *targetResource =
  [[HCResource alloc]
   initWithMediaType:[HCMediaType MediaTypeFromString:[rs stringForColumn:COL_REL_MEDIA_TYPE]]
   uri:[NSURL URLWithString:[rs stringForColumn:COL_REL_URI]]];
  return [[HCRelation alloc]
          initWithName:[rs stringForColumn:COL_REL_NAME]
          subjectResource:subjectResource
          targetResource:targetResource];
}

#pragma mark - Helpers

+ (NSDate *)maxDateFromTable:(NSString *)table
                  dateColumn:(NSString *)dateColumn
                 whereColumn:(NSString *)whereColumn
                  whereValue:(id)whereValue
                          db:(FMDatabase *)db
                       error:(PELMDaoErrorBlk)errorBlk {
  NSDate *date = nil;
  FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT MAX(%@) FROM %@ WHERE %@ = ?", dateColumn, table, whereColumn]
                withArgumentsInArray:@[whereValue]];
  while ([rs next]) {
     date = [PELMUtils dateFromResultSet:rs columnIndex:0];
  }
  [rs close];
  return date;
}

+ (NSDate *)dateFromTable:(NSString *)table
               dateColumn:(NSString *)dateColumn
              whereColumn:(NSString *)whereColumn
               whereValue:(id)whereValue
                       db:(FMDatabase *)db
                    error:(PELMDaoErrorBlk)errorBlk {
  NSDate *date = nil;
  FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?", dateColumn, table, whereColumn]
                withArgumentsInArray:@[whereValue]];
  while ([rs next]) {
    date = [PELMUtils dateFromResultSet:rs columnIndex:0];
  }
  [rs close];
  return date;
}

+ (NSInteger)intFromQuery:(NSString *)query args:(NSArray *)args db:(FMDatabase *)db {
  NSInteger num = 0;
  FMResultSet *rs = [db executeQuery:query withArgumentsInArray:args];
  while ([rs next]) {
    num = [rs intForColumnIndex:0];
  }
  [rs close];
  return num;
}

- (NSInteger)numEntitiesFromTable:(NSString *)table
                            error:(PELMDaoErrorBlk)errorBlk {
  __block NSInteger numEntities = 0;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    numEntities = [PELMUtils numEntitiesFromTable:table db:db error:errorBlk];
  }];
  return numEntities;
}

+ (NSInteger)numEntitiesFromTable:(NSString *)table
                               db:(FMDatabase *)db
                            error:(PELMDaoErrorBlk)errorBlk {
  FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", table]];
  NSInteger numEntities = 0;
  while ([rs next]) {
    numEntities = [rs intForColumnIndex:0];
  }
  [rs close];
  return numEntities;
}

- (NSNumber *)numberFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                        error:(PELMDaoErrorBlk)errorBlk {
  __block id value = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    value =  [PELMUtils numberFromTable:table
                           selectColumn:selectColumn
                            whereColumn:whereColumn
                             whereValue:whereValue
                                     db:db
                                  error:errorBlk];
  }];
  return value;
}

+ (NSNumber *)numberFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils valueFromTable:table
                      selectColumn:selectColumn
                       whereColumn:whereColumn
                        whereValue:whereValue
                       rsExtractor:^id(FMResultSet *rs, NSString *selectColum){return [NSNumber numberWithInt:[rs intForColumn:selectColumn]];}
                                db:db
                             error:errorBlk];
}

- (NSNumber *)boolFromTable:(NSString *)table
               selectColumn:(NSString *)selectColumn
                whereColumn:(NSString *)whereColumn
                 whereValue:(id)whereValue
                      error:(PELMDaoErrorBlk)errorBlk {
  __block id value = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    value =  [PELMUtils boolFromTable:table
                         selectColumn:selectColumn
                          whereColumn:whereColumn
                           whereValue:whereValue
                                   db:db
                                error:errorBlk];
  }];
  return value;
}

+ (NSNumber *)boolFromTable:(NSString *)table
               selectColumn:(NSString *)selectColumn
                whereColumn:(NSString *)whereColumn
                 whereValue:(id)whereValue
                         db:(FMDatabase *)db
                      error:(PELMDaoErrorBlk)errorBlk {
  id (^rsExtractor)(FMResultSet *, NSString *) = ^ id (FMResultSet *rs, NSString *selectColum) {
    return [NSNumber numberWithBool:[rs boolForColumn:selectColum]];
  };
  return [self valueFromTable:table
                 selectColumn:selectColumn
                  whereColumn:whereColumn
                   whereValue:whereValue
                  rsExtractor:rsExtractor
                           db:db
                        error:errorBlk];
}



- (NSString *)stringFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                        error:(PELMDaoErrorBlk)errorBlk {
  __block id value = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    value =  [PELMUtils stringFromTable:table
                           selectColumn:selectColumn
                            whereColumn:whereColumn
                             whereValue:whereValue
                                     db:db
                                  error:errorBlk];
  }];
  return value;
}

+ (NSString *)stringFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk {
  return [self valueFromTable:table
                 selectColumn:selectColumn
                  whereColumn:whereColumn
                   whereValue:whereValue
                  rsExtractor:^id(FMResultSet *rs,NSString *selectColum){return [rs stringForColumn:selectColumn];}
                           db:db
                        error:errorBlk];
}

+ (id)valueFromTable:(NSString *)table
        selectColumn:(NSString *)selectColumn
         whereColumn:(NSString *)whereColumn
          whereValue:(id)whereValue
         rsExtractor:(id(^)(FMResultSet *, NSString *))rsExtractor
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk {
  id value = nil;
  FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?", selectColumn, table, whereColumn]
                withArgumentsInArray:@[whereValue]];
  while ([rs next]) {
    value = rsExtractor(rs, selectColumn);
  }
  [rs close];
  return value;
}

@end
