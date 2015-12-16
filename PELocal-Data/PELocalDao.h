//
// PELocalDao.h
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

#import <FMDB/FMDatabase.h>
#import <FMDB/FMDatabaseQueue.h>
#import "PELMUser.h"
#import "PELMUtils.h"
#import "PEChangelog.h"

typedef void (^PELMProcessChangelogEntitiesBlk)(NSArray *,
                                                NSString *,
                                                NSString *,
                                                void(^)(id),
                                                PELMSaveNewOrExistingCode(^)(id));

@protocol PELocalDao <NSObject>

#pragma mark - Initializers

- (id)initWithSqliteDataFilePath:(NSString *)sqliteDataFilePath
               concreteUserClass:(Class)concreteUserClass;

- (id)initWithDatabaseQueue:(FMDatabaseQueue *)databaseQueue
          concreteUserClass:(Class)concreteUserClass;

#pragma mark - Getters

- (PELMUtils *)localModelUtils;

- (FMDatabaseQueue *)databaseQueue;

#pragma mark - System Functions

- (void)pruneAllSyncedEntitiesWithError:(PELMDaoErrorBlk)errorBlk;

- (void)globalCancelSyncInProgressWithError:(PELMDaoErrorBlk)error;

#pragma mark - Change Log Operations

- (NSArray *)saveChangelog:(PEChangelog *)changelog forUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

#pragma mark - User Operations

- (void)saveNewRemoteUser:(PELMUser *)remoteUser
       andLinkToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                    error:(PELMDaoErrorBlk)errorBlk;

- (void)saveNewRemoteUser:(PELMUser *)newRemoteUser
       andLinkToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                       db:(FMDatabase *)db
                    error:(PELMDaoErrorBlk)errorBlk;

- (void)deepSaveNewRemoteUser:(PELMUser *)remoteUser
           andLinkToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                        error:(PELMDaoErrorBlk)errorBlk;

- (NSDate *)mostRecentMasterUpdateForUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (void)deleteUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (void)deleteUser:(PELMUser *)user db:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)masterUserWithId:(NSNumber *)userId error:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)masterUserWithGlobalId:(NSString *)globalId error:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)mainUserWithError:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)mainUserWithDatabase:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)masterUserWithError:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)masterUserWithDatabase:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk;

- (void)saveNewLocalUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)userWithError:(PELMDaoErrorBlk)errorBlk;

- (BOOL)prepareUserForEdit:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (BOOL)prepareUserForEdit:(PELMUser *)user db:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk;

- (void)saveUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsDoneEditingImmediateSyncUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsDoneEditingUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (void)reloadUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (void)cancelEditOfUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (PELMUser *)markUserAsSyncInProgressWithError:(PELMDaoErrorBlk)errorBlk;

- (void)cancelSyncForUser:(PELMUser *)user
             httpRespCode:(NSNumber *)httpRespCode
                errorMask:(NSNumber *)errorMask
                  retryAt:(NSDate *)retryAt
                    error:(PELMDaoErrorBlk)errorBlk;

- (BOOL)saveMasterUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (BOOL)saveMasterUser:(PELMUser *)user db:(FMDatabase *)db error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsSyncCompleteForUser:(PELMUser *)user error:(PELMDaoErrorBlk)errorBlk;

- (NSInteger)numUnsyncedEntitiesForUser:(PELMUser *)user mainEntityTable:(NSString *)entityTable;

- (NSInteger)numSyncNeededEntitiesForUser:(PELMUser *)user mainEntityTable:(NSString *)entityTable;

- (void)linkMainUser:(PELMUser *)mainUser
        toMasterUser:(PELMUser *)masterUser
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk;

#pragma mark - Persistence Helpers

- (NSString *)updateStmtForMasterUser;

- (NSArray *)updateArgsForMasterUser:(PELMUser *)user;

- (NSString *)updateStmtForMainUser;

- (NSArray *)updateArgsForMainUser:(PELMUser *)user;

- (void)insertIntoMainUser:(PELMUser *)user
                        db:(FMDatabase *)db
                     error:(PELMDaoErrorBlk)errorBlk;

- (void)insertIntoMasterUser:(PELMUser *)user
                          db:(FMDatabase *)db
                       error:(PELMDaoErrorBlk)errorBlk;

#pragma mark - Result Set -> User Helpers

- (PELMUser *)mainUserFromResultSet:(FMResultSet *)rs;

- (PELMUser *)masterUserFromResultSet:(FMResultSet *)rs;

@end
