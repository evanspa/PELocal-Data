//
// PELocalDao.m
// PELocal-Data
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

#import "PELocalDaoImpl.h"
#import <FMDB/FMDatabase.h>
#import "PELMDDL.h"
#import <PEObjc-Commons/PEUtils.h>

@implementation PELocalDaoImpl {
  Class _concreteUserClass;
  FMDatabaseQueue *_databaseQueue;
  PELMUtils *_localModelUtils;
}

#pragma mark - Initializers

- (id)initWithSqliteDataFilePath:(NSString *)sqliteDataFilePath
               concreteUserClass:(Class)concreteUserClass {
  return [self initWithDatabaseQueue:[FMDatabaseQueue databaseQueueWithPath:sqliteDataFilePath]
                   concreteUserClass:concreteUserClass];
}

- (id)initWithDatabaseQueue:(FMDatabaseQueue *)databaseQueue
          concreteUserClass:(Class)concreteUserClass {
  self = [super init];
  if (self) {
    _concreteUserClass = concreteUserClass;
    _databaseQueue = databaseQueue;
    _localModelUtils = [[PELMUtils alloc] initWithDatabaseQueue:_databaseQueue];
    [_databaseQueue inDatabase:^(FMDatabase *db) {
      // for some reason, this has to be done in a "inDatabase" block for it to
      // work.  I guess we'll just assume that FKs are enabled as a universal
      // truth of the system, regardless of 'required schema version' val.
      [db executeUpdate:@"PRAGMA foreign_keys = ON"];
    }];
  }
  return self;
}

#pragma mark - Master Entity Table Names

- (NSArray *)masterEntityTableNames { return @[]; }

#pragma mark - Pre-Delete User Hook

- (PEUserDbOpBlk)preDeleteUserHook { return nil; }

#pragma mark - Post-Deep Save User Hook

- (PEUserDbOpBlk)postDeepSaveUserHook { return nil; }

#pragma mark - Main Entity Table Names (child -> parent order)

- (NSArray *)mainEntityTableNamesChildToParentOrder { return @[]; }

#pragma mark - Change Log Processors

- (NSArray *)changelogProcessorsWithUser:(PELMUser *)user
                               changelog:(PEChangelog *)changelog
                                      db:(FMDatabase *)db
                         processingBlock:(PELMProcessChangelogEntitiesBlk)processingBlk
                                errorBlk:(PELMDaoErrorBlk)errorBlk {
  return @[];
}


#pragma mark - Getters

- (PELMUtils *)localModelUtils { return _localModelUtils; }

- (FMDatabaseQueue *)databaseQueue { return _databaseQueue; }

#pragma mark - System Functions

- (void)pruneAllSyncedEntitiesWithError:(PELMDaoErrorBlk)errorBlk {
  NSMutableArray *mainTables = [NSMutableArray arrayWithArray:[self mainEntityTableNamesChildToParentOrder]];
  [mainTables addObject:TBL_MAIN_USER];
  [self.localModelUtils pruneAllSyncedFromMainTables:mainTables error:errorBlk];
}

- (void)globalCancelSyncInProgressWithError:(PELMDaoErrorBlk)error {
  NSMutableArray *mainTables = [NSMutableArray arrayWithObject:TBL_MAIN_USER];
  [mainTables addObjectsFromArray:[[[self mainEntityTableNamesChildToParentOrder] reverseObjectEnumerator] allObjects]];
  [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    for (NSString *mainEntityTableName in mainTables) {
      [PELMUtils cancelSyncInProgressForEntityTable:mainEntityTableName db:db error:error];
    }
  }];
}

#pragma mark - Change Log Operations

- (NSArray *)saveChangelog:(PEChangelog *)changelog forUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  __block NSInteger numDeletes = 0;
  __block NSInteger numUpdates = 0;
  __block NSInteger numInserts = 0;
  [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    PELMProcessChangelogEntitiesBlk processChangelogEntities =
    ^(NSArray *entities, NSString *masterTable, NSString *mainTable, void(^deleteBlk)(id), PELMSaveNewOrExistingCode(^saveNewOrExistingBlk)(id)) {
      for (PELMMainSupport *entity in entities) {
        if (![PEUtils isNil:entity.deletedAt]) {
          NSNumber *masterLocalId = [PELMUtils masterLocalIdFromEntityTable:masterTable
                                                           globalIdentifier:entity.globalIdentifier
                                                                         db:db
                                                                      error:errorBlk];
          if (![PEUtils isNil:masterLocalId]) {
            [entity setLocalMasterIdentifier:masterLocalId];
            NSNumber *mainLocalId = [PELMUtils localMainIdentifierForEntity:entity
                                                                  mainTable:mainTable
                                                                         db:db
                                                                      error:errorBlk];
            [entity setLocalMainIdentifier:mainLocalId];
            deleteBlk(entity);
            numDeletes++;
          } else {
            // the entity never existed on our device (i.e., it was created and deleted
            // before it could ever be downloaded to this device)
          }
        } else {
          PELMSaveNewOrExistingCode returnCode = saveNewOrExistingBlk(entity);
          switch (returnCode) {
            case PELMSaveNewOrExistingCodeDidUpdate:
              numUpdates++;
              break;
            case PELMSaveNewOrExistingCodeDidInsert:
              numInserts++;
              break;
            case PELMSaveNewOrExistingCodeDidNothing:
              // do nothing
              break;
          }
        }
      }
    };
    PELMUser *updatedUser = [changelog user];
    if (![PEUtils isNil:updatedUser]) {
      if ([updatedUser.updatedAt compare:user.updatedAt] == NSOrderedDescending) {
        if ([self saveMasterUser:updatedUser db:db error:errorBlk]) {
          [user overwriteDomainProperties:updatedUser];
          numUpdates++;
        }
      }
    }
    NSArray *changelogProcessors = [self changelogProcessorsWithUser:user
                                                           changelog:changelog
                                                                  db:db
                                                     processingBlock:processChangelogEntities
                                                            errorBlk:errorBlk];
    void (^changelogProcessor)(void);
    for (changelogProcessor in changelogProcessors) {
      changelogProcessor();
    }
  }];
  return @[@(numDeletes), @(numUpdates), @(numInserts)];
}

#pragma mark - User Operations

- (void)saveNewRemoteUser:(PELMUser *)remoteUser
       andLinkToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                    error:(PELMDaoErrorBlk)errorBlk {
  // user is special in that, upon insertion, it should have a global-ID (this
  // is because as part of user-creation, we FIRST save to remote master, which
  // returns us back a global-ID, then we insert into local master, hence this
  // invariant check)
  NSAssert([remoteUser globalIdentifier] != nil, @"globalIdentifier is nil");
  [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [self saveNewRemoteUser:remoteUser
         andLinkToLocalUser:localUser
preserveExistingLocalEntities:preserveExistingLocalEntities
                         db:db
                      error:errorBlk];
  }];
}

- (void)saveNewRemoteUser:(PELMUser *)newRemoteUser
       andLinkToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                       db:(FMDatabase *)db
                    error:(PELMDaoErrorBlk)errorBlk {
  [self insertIntoMasterUser:newRemoteUser db:db error:errorBlk];
  [PELMUtils insertRelations:[newRemoteUser relations]
                   forEntity:newRemoteUser
                 entityTable:TBL_MASTER_USER
             localIdentifier:[newRemoteUser localMasterIdentifier]
                          db:db
                       error:errorBlk];
  [self linkMainUser:localUser toMasterUser:newRemoteUser db:db error:errorBlk];
  if (!preserveExistingLocalEntities) {
    PEUserDbOpBlk preDeleteUserHook = [self preDeleteUserHook];
    if (preDeleteUserHook) {
      preDeleteUserHook(localUser, db, errorBlk);
    }
  }
}

- (void)deepSaveNewRemoteUser:(PELMUser *)remoteUser
           andLinkToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                        error:(PELMDaoErrorBlk)errorBlk {
  NSAssert([remoteUser globalIdentifier] != nil, @"globalIdentifier is nil");
  [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [self saveNewRemoteUser:remoteUser
         andLinkToLocalUser:localUser
preserveExistingLocalEntities:preserveExistingLocalEntities
                         db:db
                      error:errorBlk];
    PEUserDbOpBlk postDeepSaveUserHook = [self postDeepSaveUserHook];
    if (postDeepSaveUserHook) {
      postDeepSaveUserHook(remoteUser, db, errorBlk);
    }
  }];
}

- (void)deleteUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [self deleteUser:user db:db error:errorBlk];
  }];
}

- (void)deleteUser:(PELMUser *)user db:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk {
  PEUserDbOpBlk preDeleteHook = [self preDeleteUserHook];
  if (preDeleteHook) {
    preDeleteHook(user, db, errorBlk);
  }
  [PELMUtils deleteEntity:user
          entityMainTable:TBL_MAIN_USER
        entityMasterTable:TBL_MASTER_USER
                       db:db
                    error:errorBlk];
}

- (NSDate *)mostRecentMasterUpdateForUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  __block NSDate *overallMostRecent = nil;
  [self.databaseQueue inDatabase:^(FMDatabase *db) {
    NSDate *(^mostRecentDate)(NSString *) = ^ NSDate * (NSString *table) {
      return [PELMUtils maxDateFromTable:table
                              dateColumn:COL_MST_UPDATED_AT
                             whereColumn:COL_MASTER_USER_ID
                              whereValue:user.localMasterIdentifier
                                      db:db
                                   error:errorBlk];
    };
    overallMostRecent = [PELMUtils maxDateFromTable:TBL_MASTER_USER
                                         dateColumn:COL_MST_UPDATED_AT
                                        whereColumn:COL_LOCAL_ID
                                         whereValue:user.localMasterIdentifier
                                                 db:db
                                              error:errorBlk];
    NSArray *masterEntityTableNames = [self masterEntityTableNames];
    for (NSString *tableName in masterEntityTableNames) {
      overallMostRecent = [PEUtils largerOfDate:overallMostRecent
                                        andDate:mostRecentDate(tableName)];
    }
  }];
  return overallMostRecent;
}

- (PELMUser *)masterUserWithId:(NSNumber *)userId error:(PELMDaoErrorBlk)errorBlk {
  __block PELMUser *user = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    user = [PELMUtils entityFromQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?", TBL_MASTER_USER, COL_LOCAL_ID]
                          entityTable:TBL_MASTER_USER
                        localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMasterIdentifier]; }
                            argsArray:@[userId]
                          rsConverter:^(FMResultSet *rs) { return [self masterUserFromResultSet:rs]; }
                                   db:db
                                error:errorBlk];
  }];
  return user;
}

- (PELMUser *)masterUserWithGlobalId:(NSString *)globalId error:(PELMDaoErrorBlk)errorBlk {
  __block PELMUser *user = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    user = [PELMUtils entityFromQuery:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = ?", TBL_MASTER_USER, COL_GLOBAL_ID]
                          entityTable:TBL_MASTER_USER
                        localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMasterIdentifier]; }
                            argsArray:@[globalId]
                          rsConverter:^(FMResultSet *rs) { return [self masterUserFromResultSet:rs]; }
                                   db:db
                                error:errorBlk];
  }];
  return user;
}

- (PELMUser *)mainUserWithError:(PELMDaoErrorBlk)errorBlk {
  __block PELMUser *user = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    user = [self mainUserWithDatabase:db error:errorBlk];
  }];
  return user;
}

- (PELMUser *)mainUserWithDatabase:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk {
  NSString *userTable = TBL_MAIN_USER;
  return [PELMUtils entityFromQuery:[NSString stringWithFormat:@"SELECT * FROM %@", userTable]
                        entityTable:userTable
                      localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMainIdentifier]; }
                          argsArray:@[]
                        rsConverter:^(FMResultSet *rs){return [self mainUserFromResultSet:rs];}
                                 db:db
                              error:errorBlk];
}

- (PELMUser *)masterUserWithError:(PELMDaoErrorBlk)errorBlk {
  __block PELMUser *user = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    user = [self masterUserWithDatabase:db error:errorBlk];
  }];
  return user;
}

- (PELMUser *)masterUserWithDatabase:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk {
  NSString *userTable = TBL_MASTER_USER;
  return [PELMUtils entityFromQuery:[NSString stringWithFormat:@"SELECT * FROM %@", userTable]
                        entityTable:userTable
                      localIdGetter:^NSNumber *(PELMModelSupport *entity) { return [entity localMasterIdentifier]; }
                          argsArray:@[]
                        rsConverter:^(FMResultSet *rs){return [self masterUserFromResultSet:rs];}
                                 db:db
                              error:errorBlk];
}

- (void)saveNewLocalUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [self saveNewLocalUser:user db:db error:errorBlk];
  }];
}

- (void)saveNewLocalUser:(PELMUser *)user
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk {
  [self insertIntoMainUser:user db:db error:errorBlk];
}

- (PELMUser *)userWithError:(PELMDaoErrorBlk)errorBlk {
    // we always go to main store first...(the end-user might be in the process
  // of editing their user entity, and therefore, the "latest" version of the
  // user entity will be residing in the main store).
  __block PELMUser *user = nil;
  [_databaseQueue inDatabase:^(FMDatabase *db) {
    user = [self mainUserWithDatabase:db error:errorBlk];
    if (!user) {
      user = [self masterUserWithDatabase:db error:errorBlk];
      if (user) {
        if ([user deletedAt]) {
          user = nil;
        }
      }
    }
  }];
  return user;
}

- (BOOL)prepareUserForEdit:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  __block BOOL returnVal;
  [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    returnVal = [self prepareUserForEdit:user db:db error:errorBlk];
  }];
  return returnVal;
}

- (BOOL)prepareUserForEdit:(PELMUser *)user db:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils prepareEntityForEdit:user
                                      db:db
                               mainTable:TBL_MAIN_USER
                     entityFromResultSet:^(FMResultSet *rs){return [self mainUserFromResultSet:rs];}
                      mainEntityInserter:^(PELMMainSupport *entity, FMDatabase *db, PELMDaoErrorBlk errorBlk) {
                        [self insertIntoMainUser:(PELMUser *)entity db:db error:errorBlk];
                      }
                       mainEntityUpdater:^(PELMMainSupport *entity, FMDatabase *db, PELMDaoErrorBlk errorBlk) {
                         [PELMUtils doUpdate:[self updateStmtForMainUser]
                                   argsArray:[self updateArgsForMainUser:user]
                                          db:db
                                       error:errorBlk];
                         [PELMUtils deleteRelationsFromEntityTable:TBL_MAIN_USER
                                                   localIdentifier:[entity localMainIdentifier]
                                                                db:db
                                                             error:errorBlk];
                         [PELMUtils insertRelations:[user relations]
                                          forEntity:user
                                        entityTable:TBL_MAIN_USER
                                    localIdentifier:[user localMainIdentifier]
                                                 db:db
                                              error:errorBlk];
                       }
                                   error:errorBlk];
}

- (void)saveUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils saveEntity:user
                     mainTable:TBL_MAIN_USER
                mainUpdateStmt:[self updateStmtForMainUser]
             mainUpdateArgsBlk:^NSArray *(PELMMainSupport *entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                         error:errorBlk];
}

- (void)markAsDoneEditingImmediateSyncUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils markAsDoneEditingImmediateSyncEntity:user
                                               mainTable:TBL_MAIN_USER
                                          mainUpdateStmt:[self updateStmtForMainUser]
                                       mainUpdateArgsBlk:^NSArray *(PELMMainSupport *entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                                                   error:errorBlk];
}

- (void)markAsDoneEditingUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils markAsDoneEditingEntity:user
                                  mainTable:TBL_MAIN_USER
                             mainUpdateStmt:[self updateStmtForMainUser]
                          mainUpdateArgsBlk:^NSArray *(PELMMainSupport *entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                                      error:errorBlk];
}

- (void)reloadUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils reloadEntity:user
                   fromMainTable:TBL_MAIN_USER
                     rsConverter:^(FMResultSet *rs){return [self mainUserFromResultSet:rs];}
                           error:errorBlk];
}

- (void)cancelEditOfUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils cancelEditOfEntity:user
                             mainTable:TBL_MAIN_USER
                        mainUpdateStmt:[self updateStmtForMainUser]
                     mainUpdateArgsBlk:^NSArray *(PELMMainSupport *entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                           masterTable:TBL_MASTER_USER
                           rsConverter:^(FMResultSet *rs){return [self masterUserFromResultSet:rs];}
                                 error:errorBlk];
}

- (PELMUser *)markUserAsSyncInProgressWithError:(PELMDaoErrorBlk)errorBlk {
  NSArray *userEntities = [_localModelUtils markEntitiesAsSyncInProgressInMainTable:TBL_MAIN_USER
                                                                entityFromResultSet:^(FMResultSet *rs){return [self mainUserFromResultSet:rs];}
                                                                         updateStmt:[self updateStmtForMainUser]
                                                                      updateArgsBlk:^NSArray *(PELMMainSupport *entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                                                                              error:errorBlk];
  if ([userEntities count] > 1) {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"There cannot be more than 1 user entity"
                                 userInfo:nil];
  } else if ([userEntities count] == 0) {
    return nil;
  } else {
    return [userEntities objectAtIndex:0];
  }
}

- (void)cancelSyncForUser:(PELMUser *)user
             httpRespCode:(NSNumber *)httpRespCode
                errorMask:(NSNumber *)errorMask
                  retryAt:(NSDate *)retryAt
                    error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils cancelSyncForEntity:user
                           httpRespCode:httpRespCode
                              errorMask:errorMask
                                retryAt:retryAt
                         mainUpdateStmt:[self updateStmtForMainUser]
                      mainUpdateArgsBlk:^NSArray *(PELMMainSupport *entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                                  error:errorBlk];
}

- (BOOL)saveMasterUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  return [_localModelUtils saveMasterEntity:user
                                masterTable:TBL_MASTER_USER
                           masterUpdateStmt:[self updateStmtForMasterUser]
                        masterUpdateArgsBlk:^NSArray * (PELMUser *theUser) { return [self updateArgsForMasterUser:theUser]; }
                                  mainTable:TBL_MAIN_USER
                    mainEntityFromResultSet:^PELMUser * (FMResultSet *rs) { return [self mainUserFromResultSet:rs]; }
                             mainUpdateStmt:[self updateStmtForMainUser]
                          mainUpdateArgsBlk:^NSArray * (PELMUser *theUser) { return [self updateArgsForMainUser:theUser]; }
                                      error:errorBlk];
}

- (BOOL)saveMasterUser:(PELMUser *)user db:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk {
  return [PELMUtils saveMasterEntity:user
                         masterTable:TBL_MASTER_USER
                    masterUpdateStmt:[self updateStmtForMasterUser]
                 masterUpdateArgsBlk:^NSArray * (PELMUser *theUser) { return [self updateArgsForMasterUser:theUser]; }
                           mainTable:TBL_MAIN_USER
             mainEntityFromResultSet:^ PELMUser * (FMResultSet *rs) { return [self mainUserFromResultSet:rs]; }
                      mainUpdateStmt:[self updateStmtForMainUser]
                   mainUpdateArgsBlk:^NSArray * (PELMUser *theUser) { return [self updateArgsForMainUser:theUser]; }
                                  db:db
                               error:errorBlk];
}

- (void)markAsSyncCompleteForUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk {
  [_localModelUtils markAsSyncCompleteForUpdatedEntityInTxn:user
                                                  mainTable:TBL_MAIN_USER
                                                masterTable:TBL_MASTER_USER
                                             mainUpdateStmt:[self updateStmtForMainUser]
                                          mainUpdateArgsBlk:^(id entity){return [self updateArgsForMainUser:(PELMUser *)entity];}
                                           masterUpdateStmt:[self updateStmtForMasterUser]
                                        masterUpdateArgsBlk:^(id entity){return [self updateArgsForMasterUser:(PELMUser *)entity];}
                                                      error:errorBlk];
}

- (NSInteger)numUnsyncedEntitiesForUser:(PELMUser *)user mainEntityTable:(NSString *)entityTable {
  __block NSInteger numEntities = 0;
  if ([user localMainIdentifier]) {
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
      NSString *qry = [NSString stringWithFormat:@"select count(*) from %@ where \
                       %@ = ? and \
                       %@ = 0", entityTable,
                       COL_MAIN_USER_ID,
                       COL_MAN_SYNCED];
      FMResultSet *rs = [db executeQuery:qry
                    withArgumentsInArray:@[[user localMainIdentifier]]];
      [rs next];
      numEntities = [rs intForColumnIndex:0];
      [rs next]; // to not have 'open result set' warning
      [rs close];
    }];
  }
  return numEntities;
}

- (NSInteger)numSyncNeededEntitiesForUser:(PELMUser *)user mainEntityTable:(NSString *)entityTable {
  __block NSInteger numEntities = 0;
  if ([user localMainIdentifier]) {
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
      NSString *qry = [NSString stringWithFormat:@"select count(*) from %@ where \
                       %@ = ? and \
                       %@ = 0 and \
                       %@ = 0 and \
                       %@ = 0 and \
                       (%@ is null or %@ <= 0)",
                       entityTable,
                       COL_MAIN_USER_ID,
                       COL_MAN_SYNCED,
                       COL_MAN_EDIT_IN_PROGRESS,
                       COL_MAN_SYNC_IN_PROGRESS,
                       COL_MAN_SYNC_ERR_MASK,
                       COL_MAN_SYNC_ERR_MASK];
      FMResultSet *rs = [db executeQuery:qry
                    withArgumentsInArray:@[[user localMainIdentifier]]];
      [rs next];
      numEntities = [rs intForColumnIndex:0];
      [rs next]; // to not have 'open result set' warning
      [rs close];
    }];
  }
  return numEntities;
}

- (void)linkMainUser:(PELMUser *)mainUser
        toMasterUser:(PELMUser *)masterUser
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk {
  [mainUser overwrite:masterUser];
  [mainUser setLocalMasterIdentifier:[masterUser localMasterIdentifier]];
  [mainUser setSynced:YES];
  [PELMUtils doUpdate:[NSString stringWithFormat:@"update %@ set \
%@ = ?, \
%@ = 1, \
%@ = ?, \
%@ = ?, \
%@ = ?, \
%@ = ?, \
%@ = ? \
where %@ = ?", TBL_MAIN_USER,
                       COL_MASTER_USER_ID,
                       COL_MAN_SYNCED,
                       COL_GLOBAL_ID,
                       COL_MAN_MASTER_UPDATED_AT,
                       COL_USR_NAME,
                       COL_USR_EMAIL,
                       COL_USR_VERIFIED_AT,
                       COL_LOCAL_ID]
            argsArray:@[[masterUser localMasterIdentifier],
                        [masterUser globalIdentifier],
                        [PEUtils millisecondsFromDate:[masterUser updatedAt]],
                        orNil([masterUser name]),
                        orNil([masterUser email]),
                        orNil([PEUtils millisecondsFromDate:[masterUser verifiedAt]]),
                        [mainUser localMainIdentifier]]
                   db:db
                error:errorBlk];
  [PELMUtils deleteRelationsFromEntityTable:TBL_MAIN_USER
                            localIdentifier:[mainUser localMainIdentifier]
                                         db:db
                                      error:errorBlk];
  [PELMUtils insertRelations:[masterUser relations]
                   forEntity:mainUser
                 entityTable:TBL_MAIN_USER
             localIdentifier:[mainUser localMainIdentifier]
                          db:db
                       error:errorBlk];
}

#pragma mark - Persistence Helpers

- (NSString *)updateStmtForMasterUser {
  return [NSString stringWithFormat:@"UPDATE %@ SET \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ? \
          WHERE %@ = ?",
          TBL_MASTER_USER,        // table
          COL_GLOBAL_ID,          // col1
          COL_MEDIA_TYPE,         // col2
          COL_MST_CREATED_AT,
          COL_MST_UPDATED_AT, // col4
          COL_MST_DELETED_DT,     // col5
          COL_USR_NAME,           // col6
          COL_USR_EMAIL,          // col7
          COL_USR_PASSWORD_HASH,  // col8
          COL_USR_VERIFIED_AT,    // col 9
          COL_LOCAL_ID];          // where, col1
}

- (NSArray *)updateArgsForMasterUser:(PELMUser *)user {
  return @[orNil([user globalIdentifier]),
           orNil([[user mediaType] description]),
           orNil([PEUtils millisecondsFromDate:[user createdAt]]),
           orNil([PEUtils millisecondsFromDate:[user updatedAt]]),
           orNil([PEUtils millisecondsFromDate:[user deletedAt]]),
           orNil([user name]),
           orNil([user email]),
           orNil([user password]),
           orNil([PEUtils millisecondsFromDate:[user verifiedAt]]),
           [user localMasterIdentifier]];
}

- (NSString *)updateStmtForMainUser {
  return [NSString stringWithFormat:@"UPDATE %@ SET \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ?, \
          %@ = ? \
          WHERE %@ = ?",
          TBL_MAIN_USER,                      // table
          COL_GLOBAL_ID,                      // col1
          COL_MEDIA_TYPE,                     // col2
          COL_MAN_MASTER_UPDATED_AT,      // col3
          COL_MAN_DT_COPIED_DOWN_FROM_MASTER, // col4
          COL_USR_NAME,                       // col5
          COL_USR_EMAIL,                      // col6
          COL_USR_PASSWORD_HASH,              // col8
          COL_USR_VERIFIED_AT,
          COL_MAN_EDIT_IN_PROGRESS,           // col10
          COL_MAN_SYNC_IN_PROGRESS,           // col11
          COL_MAN_SYNCED,                     // col12
          COL_MAN_EDIT_COUNT,                 // col15
          COL_MAN_SYNC_HTTP_RESP_CODE,
          COL_MAN_SYNC_ERR_MASK,
          COL_MAN_SYNC_RETRY_AT,
          COL_MASTER_USER_ID];                // where, col1
}

- (NSArray *)updateArgsForMainUser:(PELMUser *)user {
  return @[orNil([user globalIdentifier]),
           orNil([[user mediaType] description]),
           orNil([PEUtils millisecondsFromDate:[user updatedAt]]),
           orNil([PEUtils millisecondsFromDate:[user dateCopiedFromMaster]]),
           orNil([user name]),
           orNil([user email]),
           orNil([user password]),
           orNil([PEUtils millisecondsFromDate:[user verifiedAt]]),
           [NSNumber numberWithBool:[user editInProgress]],
           [NSNumber numberWithBool:[user syncInProgress]],
           [NSNumber numberWithBool:[user synced]],
           [NSNumber numberWithInteger:[user editCount]],
           orNil([user syncHttpRespCode]),
           orNil([user syncErrMask]),
           orNil([PEUtils millisecondsFromDate:[user syncRetryAt]]),
           [user localMainIdentifier]];
}

- (void)insertIntoMainUser:(PELMUser *)user
                        db:(FMDatabase *)db
                     error:(PELMDaoErrorBlk)errorBlk {
  NSString *stmt = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, %@, %@, %@, %@, \
%@, %@, %@, %@, %@, %@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, \
?, ?, ?, ?, ?, ?, ?, ?)",
                    TBL_MAIN_USER,
                    COL_LOCAL_ID,
                    COL_MASTER_USER_ID,
                    COL_GLOBAL_ID,
                    COL_MEDIA_TYPE,
                    COL_MAN_MASTER_UPDATED_AT,
                    COL_MAN_DT_COPIED_DOWN_FROM_MASTER,
                    COL_USR_NAME,
                    COL_USR_EMAIL,
                    COL_USR_PASSWORD_HASH,
                    COL_USR_VERIFIED_AT,
                    COL_MAN_EDIT_IN_PROGRESS,
                    COL_MAN_SYNC_IN_PROGRESS,
                    COL_MAN_SYNCED,
                    COL_MAN_EDIT_COUNT,
                    COL_MAN_SYNC_HTTP_RESP_CODE,
                    COL_MAN_SYNC_ERR_MASK,
                    COL_MAN_SYNC_RETRY_AT];
  [PELMUtils doMainInsert:stmt
                argsArray:@[orNil([user localMasterIdentifier]),
                            orNil([user localMasterIdentifier]),
                            orNil([user globalIdentifier]),
                            orNil([[user mediaType] description]),
                            orNil([PEUtils millisecondsFromDate:[user updatedAt]]),
                            orNil([PEUtils millisecondsFromDate:[user dateCopiedFromMaster]]),
                            orNil([user name]),
                            orNil([user email]),
                            orNil([user password]),
                            orNil([PEUtils millisecondsFromDate:[user verifiedAt]]),
                            [NSNumber numberWithBool:[user editInProgress]],
                            [NSNumber numberWithBool:[user syncInProgress]],
                            [NSNumber numberWithBool:[user synced]],
                            [NSNumber numberWithInteger:[user editCount]],
                            orNil([user syncHttpRespCode]),
                            orNil([user syncErrMask]),
                            orNil([PEUtils millisecondsFromDate:[user syncRetryAt]])]
                   entity:user
                       db:db
                    error:errorBlk];
}

- (void)insertIntoMasterUser:(PELMUser *)user
                          db:(FMDatabase *)db
                       error:(PELMDaoErrorBlk)errorBlk {
  NSString *stmt = [NSString stringWithFormat:@"INSERT INTO %@ (%@, %@, \
%@, %@, %@, %@, %@, %@, %@) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    TBL_MASTER_USER,
                    COL_GLOBAL_ID,
                    COL_MEDIA_TYPE,
                    COL_MST_CREATED_AT,
                    COL_MST_UPDATED_AT,
                    COL_MST_DELETED_DT,
                    COL_USR_NAME,
                    COL_USR_EMAIL,
                    COL_USR_PASSWORD_HASH,
                    COL_USR_VERIFIED_AT];
  [PELMUtils doMasterInsert:stmt
                  argsArray:@[orNil([user globalIdentifier]),
                              orNil([[user mediaType] description]),
                              orNil([PEUtils millisecondsFromDate:[user createdAt]]),
                              orNil([PEUtils millisecondsFromDate:[user updatedAt]]),
                              orNil([PEUtils millisecondsFromDate:[user deletedAt]]),
                              orNil([user name]),
                              orNil([user email]),
                              orNil([user password]),
                              orNil([PEUtils millisecondsFromDate:[user verifiedAt]])]
                     entity:user
                         db:db
                      error:errorBlk];
}

#pragma mark - Result Set -> User Helpers

- (PELMUser *)mainUserFromResultSet:(FMResultSet *)rs {
  return [[_concreteUserClass alloc] initWithLocalMainIdentifier:[rs objectForColumnName:COL_LOCAL_ID]
                                           localMasterIdentifier:[rs objectForColumnName:COL_LOCAL_ID]
                                                globalIdentifier:[rs stringForColumn:COL_GLOBAL_ID]
                                                       mediaType:[HCMediaType MediaTypeFromString:[rs stringForColumn:COL_MEDIA_TYPE]]
                                                       relations:nil
                                                       createdAt:nil // NA (this is a master store-only column)
                                                       deletedAt:nil // NA (this is a master store-only column)
                                                       updatedAt:[PELMUtils dateFromResultSet:rs columnName:COL_MAN_MASTER_UPDATED_AT]
                                            dateCopiedFromMaster:[PELMUtils dateFromResultSet:rs columnName:COL_MAN_DT_COPIED_DOWN_FROM_MASTER]
                                                  editInProgress:[rs boolForColumn:COL_MAN_EDIT_IN_PROGRESS]
                                                  syncInProgress:[rs boolForColumn:COL_MAN_SYNC_IN_PROGRESS]
                                                          synced:[rs boolForColumn:COL_MAN_SYNCED]
                                                       editCount:[rs intForColumn:COL_MAN_EDIT_COUNT]
                                                syncHttpRespCode:[PELMUtils numberFromResultSet:rs columnName:COL_MAN_SYNC_HTTP_RESP_CODE]
                                                     syncErrMask:[PELMUtils numberFromResultSet:rs columnName:COL_MAN_SYNC_ERR_MASK]
                                                     syncRetryAt:[PELMUtils dateFromResultSet:rs columnName:COL_MAN_SYNC_RETRY_AT]
                                                            name:[rs stringForColumn:COL_USR_NAME]
                                                           email:[rs stringForColumn:COL_USR_EMAIL]
                                                        password:[rs stringForColumn:COL_USR_PASSWORD_HASH]
                                                      verifiedAt:[PELMUtils dateFromResultSet:rs columnName:COL_USR_VERIFIED_AT]];
}

- (PELMUser *)masterUserFromResultSet:(FMResultSet *)rs {
  return [[_concreteUserClass alloc] initWithLocalMainIdentifier:[rs objectForColumnName:COL_LOCAL_ID]
                                           localMasterIdentifier:[rs objectForColumnName:COL_LOCAL_ID]
                                                globalIdentifier:[rs stringForColumn:COL_GLOBAL_ID]
                                                       mediaType:[HCMediaType MediaTypeFromString:[rs stringForColumn:COL_MEDIA_TYPE]]
                                                       relations:nil
                                                       createdAt:[PELMUtils dateFromResultSet:rs columnName:COL_MST_CREATED_AT]
                                                       deletedAt:[PELMUtils dateFromResultSet:rs columnName:COL_MST_DELETED_DT]
                                                       updatedAt:[PELMUtils dateFromResultSet:rs columnName:COL_MST_UPDATED_AT]
                                            dateCopiedFromMaster:nil // NA (this is a main store-only column)
                                                  editInProgress:NO  // NA (this is a main store-only column)
                                                  syncInProgress:NO  // NA (this is a main store-only column)
                                                          synced:NO  // NA (this is a main store-only column)
                                                       editCount:0   // NA (this is a main store-only column)
                                                syncHttpRespCode:nil // NA (this is a main store-only column)
                                                     syncErrMask:nil // NA (this is a main store-only column)
                                                     syncRetryAt:nil // NA (this is a main store-only column)
                                                            name:[rs stringForColumn:COL_USR_NAME]
                                                           email:[rs stringForColumn:COL_USR_EMAIL]
                                                        password:[rs stringForColumn:COL_USR_PASSWORD_HASH]
                                                      verifiedAt:[PELMUtils dateFromResultSet:rs columnName:COL_USR_VERIFIED_AT]];
}

@end
