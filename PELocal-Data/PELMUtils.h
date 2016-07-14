//
//  PELMUtils.h
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

@import Foundation;
#import "PELMDefs.h"

@class FMDatabase;
@class FMDatabaseQueue;
@class FMResultSet;
@class HCAuthentication;

@class PELMModelSupport;
@class PELMMainSupport;
@class PELMMasterSupport;

@interface PELMUtils : NSObject

#pragma mark - Initializers

- (id)initWithDatabaseQueue:(FMDatabaseQueue *)databaseQueue;

#pragma mark - Completion Handler Makers

+ (PELMRemoteMasterCompletionHandler)complHandlerToFlushUnsyncedChangesToEntity:(PELMMainSupport *)entity
                                                            remoteStoreErrorBlk:(void(^)(NSError *, NSNumber *))remoteStoreErrorBlk
                                                              entityNotFoundBlk:(void(^)(void))entityNotFoundBlk
                                                              markAsConflictBlk:(void(^)(id))markAsConflictBlk
                                              markAsSyncCompleteForNewEntityBlk:(void(^)(void))markAsSyncCompleteForNewEntityBlk
                                         markAsSyncCompleteForExistingEntityBlk:(void(^)(void))markAsSyncCompleteForExistingEntityBlk
                                                                newAuthTokenBlk:(void(^)(NSString *))newAuthTokenBlk;

+ (PELMRemoteMasterCompletionHandler)complHandlerToDeleteEntity:(PELMMainSupport *)entity
                                            remoteStoreErrorBlk:(void(^)(NSError *, NSNumber *))remoteStoreErrorBlk
                                              entityNotFoundBlk:(void(^)(void))entityNotFoundBlk
                                              markAsConflictBlk:(void(^)(id))markAsConflictBlk
                                               deleteSuccessBlk:(void(^)(void))deleteSuccessBlk
                                                newAuthTokenBlk:(void(^)(NSString *))newAuthTokenBlk;

+ (PELMRemoteMasterCompletionHandler)complHandlerToFetchEntityWithGlobalId:(NSString *)globalId
                                                       remoteStoreErrorBlk:(void(^)(NSError *, NSNumber *))remoteStoreErrorBlk
                                                         entityNotFoundBlk:(void(^)(void))entityNotFoundBlk
                                                          fetchCompleteBlk:(void(^)(id))fetchCompleteBlk
                                                           newAuthTokenBlk:(void(^)(NSString *))newAuthTokenBlk;

+ (void)cancelSyncInProgressForEntityTable:(NSString *)mainEntityTable
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)error;

#pragma mark - Result Set Helpers

+ (NSNumber *)numberFromResultSet:(FMResultSet *)rs columnName:(NSString *)columnName;

+ (NSDecimalNumber *)decimalNumberFromResultSet:(FMResultSet *)rs columnName:(NSString *)columnName;

+ (NSDate *)dateFromResultSet:(FMResultSet *)rs columnName:(NSString *)columnName;

+ (BOOL)boolFromResultSet:(FMResultSet *)rs columnName:(NSString *)columnName boolIfNull:(BOOL)boolIfNull;

#pragma mark - Properties

@property (nonatomic, readonly) FMDatabaseQueue *databaseQueue;

#pragma mark - Utils

+ (PELMCannotBe)makeCannotBe;

+ (PELMOrNil)makeOrNil;

- (void)cancelSyncForEntity:(PELMMainSupport *)entity
               httpRespCode:(NSNumber *)httpRespCode
                  errorMask:(NSNumber *)errorMask
                    retryAt:(NSDate *)retryAt
             mainUpdateStmt:(NSString *)mainUpdateStmt
          mainUpdateArgsBlk:(NSArray *(^)(PELMMainSupport *))mainUpdateArgsBlk
                      error:(PELMDaoErrorBlk)errorBlk;

- (void)cancelEditOfEntity:(PELMMainSupport *)entity
                 mainTable:(NSString *)mainTable
            mainUpdateStmt:(NSString *)mainUpdateStmt
         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
               masterTable:(NSString *)masterTable
               rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                     error:(PELMDaoErrorBlk)errorBlk;

- (void)saveEntity:(PELMMainSupport *)entity
         mainTable:(NSString *)mainTable
    mainUpdateStmt:(NSString *)mainUpdateStmt
 mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
             error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsDoneEditingEntity:(PELMMainSupport *)entity
                      mainTable:(NSString *)mainTable
                 mainUpdateStmt:(NSString *)mainUpdateStmt
              mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                          error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsDoneEditingImmediateSyncEntity:(PELMMainSupport *)entity
                                   mainTable:(NSString *)mainTable
                              mainUpdateStmt:(NSString *)mainUpdateStmt
                           mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                                       error:(PELMDaoErrorBlk)errorBlk;

- (PELMSaveNewOrExistingCode)saveNewOrExistingMasterEntity:(PELMMainSupport *)masterEntity
                                               masterTable:(NSString *)masterTable
                                           masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                                          masterUpdateStmt:(NSString *)masterUpdateStmt
                                       masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                                 mainTable:(NSString *)mainTable
                                   mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
                                            mainUpdateStmt:(NSString *)mainUpdateStmt
                                         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                                                     error:(PELMDaoErrorBlk)errorBlk;

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
                                                     error:(PELMDaoErrorBlk)errorBlk;

- (void)saveNewMasterEntity:(PELMMainSupport *)entity
                masterTable:(NSString *)masterTable
            masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                      error:(PELMDaoErrorBlk)errorBlk;

+ (void)saveNewMasterEntity:(PELMMainSupport *)entity
                masterTable:(NSString *)masterTable
            masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                         db:(FMDatabase *)db
                      error:(PELMDaoErrorBlk)errorBlk;

- (BOOL)saveMasterEntity:(PELMMainSupport *)entity
             masterTable:(NSString *)masterTable
        masterUpdateStmt:(NSString *)masterUpdateStmt
     masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
               mainTable:(NSString *)mainTable
 mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
          mainUpdateStmt:(NSString *)mainUpdateStmt
       mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                   error:(PELMDaoErrorBlk)errorBlk;

+ (BOOL)saveMasterEntity:(PELMMainSupport *)masterEntity
             masterTable:(NSString *)masterTable
        masterUpdateStmt:(NSString *)masterUpdateStmt
     masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
               mainTable:(NSString *)mainTable
 mainEntityFromResultSet:(PELMEntityFromResultSetBlk)mainEntityFromResultSet
          mainUpdateStmt:(NSString *)mainUpdateStmt
       mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsSyncCompleteForNewEntity:(PELMMainSupport *)entity
                             mainTable:(NSString *)mainTable
                           masterTable:(NSString *)masterTable
                        mainUpdateStmt:(NSString *)mainUpdateStmt
                     mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                       masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                                 error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsSyncCompleteForUpdatedEntityInTxn:(PELMMainSupport *)entity
                                      mainTable:(NSString *)mainTable
                                    masterTable:(NSString *)masterTable
                                 mainUpdateStmt:(NSString *)mainUpdateStmt
                              mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                               masterUpdateStmt:(NSString *)masterUpdateStmt
                            masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                          error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsSyncCompleteForUpdatedEntity:(PELMMainSupport *)entity
                                 mainTable:(NSString *)mainTable
                               masterTable:(NSString *)masterTable
                            mainUpdateStmt:(NSString *)mainUpdateStmt
                         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                          masterUpdateStmt:(NSString *)masterUpdateStmt
                       masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk;

+ (void)incorporateJoinTables:(NSArray *)joinTables
             intoSelectClause:(NSMutableString *)selectClause
                   fromClause:(NSMutableString *)fromClause
                  whereClause:(NSMutableString *)whereClause
            entityTablePrefix:(NSString *)entityTablePrefix;

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
                               error:(PELMDaoErrorBlk)errorBlk;

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
                                       error:(PELMDaoErrorBlk)errorBlk;

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
                               error:(PELMDaoErrorBlk)errorBlk;

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
                               error:(PELMDaoErrorBlk)errorBlk;

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
                                  error:(PELMDaoErrorBlk)errorBlk;

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
                                  error:(PELMDaoErrorBlk)errorBlk;

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
                                    error:(PELMDaoErrorBlk)errorBlk;

+ (PELMMainSupport *)masterParentForMasterChildEntity:(PELMMainSupport *)childEntity
                              parentEntityMasterTable:(NSString *)parentEntityMasterTable
                     addlJoinParentEntityMasterTables:(NSArray *)addlJoinParentEntityMasterTables
                           parentEntityMasterFkColumn:(NSString *)parentEntityMasterFkColumn
                        parentEntityMasterRsConverter:(PELMEntityFromResultSetBlk)parentEntityMasterRsConverter
                               childEntityMasterTable:(NSString *)childEntityMasterTable
                                                   db:(FMDatabase *)db
                                                error:(PELMDaoErrorBlk)errorBlk;

+ (NSNumber *)localMainIdentifierForEntity:(PELMModelSupport *)entity
                                 mainTable:(NSString *)mainTable
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk;

- (void)reloadEntity:(PELMModelSupport *)entity
       fromMainTable:(NSString *)mainTable
      addlJoinTables:(NSArray *)addlJoinTables
         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
               error:(PELMDaoErrorBlk)errorBlk;

+ (void)copyMasterEntity:(PELMMainSupport *)entity
             toMainTable:(NSString *)mainTable
    mainTableInserterBlk:(void(^)(PELMMasterSupport *))mainTableInserter
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk;

+ (NSNumber *)masterLocalIdFromEntityTable:(NSString *)masterEntityTable
                          globalIdentifier:(NSString *)globalIdentifier
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk;

+ (NSDictionary *)relationsForEntity:(PELMModelSupport *)entity
                         entityTable:(NSString *)entityTable
                     localIdentifier:(NSNumber *)localIdentifier
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (void)setRelationsForEntity:(PELMModelSupport *)entity
                  entityTable:(NSString *)entityTable
              localIdentifier:(NSNumber *)localIdentifier
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk;

+ (void)updateRelationsForEntity:(PELMModelSupport *)entity
                     entityTable:(NSString *)entityTable
                 localIdentifier:(NSNumber *)localIdentifier
                              db:(FMDatabase *)db
                           error:(PELMDaoErrorBlk)errorBlk;

+ (void)insertRelations:(NSDictionary *)relations
              forEntity:(PELMModelSupport *)entity
            entityTable:(NSString *)entityTable
        localIdentifier:(NSNumber *)localIdentifier
                     db:(FMDatabase *)db
                  error:(PELMDaoErrorBlk)errorBlk;

- (NSArray *)markEntitiesAsSyncInProgressInMainTable:(NSString *)mainTable
                                          usingQuery:(NSString *)query
                                 entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
                                          updateStmt:(NSString *)updateStmt
                                       updateArgsBlk:(NSArray *(^)(PELMMainSupport *))updateArgsBlk
                                           filterBlk:(BOOL(^)(PELMMainSupport *))filterBlk
                                               error:(PELMDaoErrorBlk)errorBlk;

- (NSArray *)markEntitiesAsSyncInProgressInMainTable:(NSString *)mainTable
                            addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
                                 entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
                                          updateStmt:(NSString *)updateStmt
                                       updateArgsBlk:(NSArray *(^)(PELMMainSupport *))updateArgsBlk
                                               error:(PELMDaoErrorBlk)errorBlk;

+ (BOOL)prepareEntityForEdit:(PELMMainSupport *)entity
                          db:(FMDatabase *)db
                   mainTable:(NSString *)mainTable
    addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
         entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
          mainEntityInserter:(PELMMainEntityInserterBlk)mainEntityInserter
           mainEntityUpdater:(PELMMainEntityUpdaterBlk)mainEntityUpdater
                       error:(PELMDaoErrorBlk)errorBlk;

- (BOOL)prepareEntityForEditInTxn:(PELMMainSupport *)entity
                        mainTable:(NSString *)mainTable
         addlJoinEntityMainTables:(NSArray *)addlJoinEntityMainTables
              entityFromResultSet:(PELMEntityFromResultSetBlk)entityFromResultSet
               mainEntityInserter:(PELMMainEntityInserterBlk)mainEntityInserter
                mainEntityUpdater:(PELMMainEntityUpdaterBlk)mainEntityUpdater
                            error:(PELMDaoErrorBlk)errorBlk;

+ (void)invokeError:(PELMDaoErrorBlk)errorBlk db:(FMDatabase *)db;

+ (void)deleteEntity:(PELMModelSupport *)entity
     entityMainTable:(NSString *)entityMainTable
   entityMasterTable:(NSString *)entityMasterTable
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk;

+ (void)deleteRelationsFromEntityTable:(NSString *)entityTable
                       localIdentifier:(NSNumber *)localIdentifier
                                    db:(FMDatabase *)db
                                 error:(PELMDaoErrorBlk)errorBlk;

- (void)pruneAllSyncedFromMainTables:(NSArray *)tableNames
                               error:(PELMDaoErrorBlk)errorBlk;

+ (void)doMainInsert:(NSString *)stmt
           argsArray:(NSArray *)argsArray
              entity:(PELMMainSupport *)entity
                  db:(FMDatabase *)db
               error:(PELMDaoErrorBlk)errorBlk;

+ (void)doMasterInsert:(NSString *)stmt
             argsArray:(NSArray *)argsArray
                entity:(PELMModelSupport *)entity
                    db:(FMDatabase *)db
                 error:(PELMDaoErrorBlk)errorBlk;

+ (void)doUpdate:(NSString *)stmt
              db:(FMDatabase *)db
           error:(PELMDaoErrorBlk)errorBlk;

+ (void)doUpdate:(NSString *)stmt
       argsArray:(NSArray *)argsArray
              db:(FMDatabase *)db
           error:(PELMDaoErrorBlk)errorBlk;

- (void)doUpdateInTxn:(NSString *)stmt
            argsArray:(NSArray *)argsArray
                error:(PELMDaoErrorBlk)errorBlk;

+ (FMResultSet *)doQuery:(NSString *)query
               argsArray:(NSArray *)argsArray
                      db:(FMDatabase *)db
                   error:(PELMDaoErrorBlk)errorBlk;

+ (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                   db:(FMDatabase *)db
                error:(PELMDaoErrorBlk)errorBlk;

+ (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
            argsArray:(NSArray *)argsArray
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                   db:(FMDatabase *)db
                error:(PELMDaoErrorBlk)errorBlk;

- (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                error:(PELMDaoErrorBlk)errorBlk;

- (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
            argsArray:(NSArray *)argsArray
          rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)mainEntitiesFromQuery:(NSString *)query
                       entityTable:(NSString *)entityTable
                         argsArray:(NSArray *)argsArray
                       rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                db:(FMDatabase *)db
                             error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)masterEntitiesFromQuery:(NSString *)query
                         entityTable:(NSString *)entityTable
                           argsArray:(NSArray *)argsArray
                         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)mainEntitiesFromQuery:(NSString *)query
                        numAllowed:(NSNumber *)numAllowed
                       entityTable:(NSString *)entityTable
                         argsArray:(NSArray *)argsArray
                       rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                db:(FMDatabase *)db
                             error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)masterEntitiesFromQuery:(NSString *)query
                          numAllowed:(NSNumber *)numAllowed
                         entityTable:(NSString *)entityTable
                           argsArray:(NSArray *)argsArray
                         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)entitiesFromQuery:(NSString *)query
                    numAllowed:(NSNumber *)numAllowed
                   entityTable:(NSString *)entityTable
                 localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
                     argsArray:(NSArray *)argsArray
                   rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                            db:(FMDatabase *)db
                         error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)entitiesFromEntityTable:(NSString *)entityTable
                      addlJoinTables:(NSArray *)addlJoinTables
                         whereClause:(NSString *)whereClause
                       localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
                           argsArray:(NSArray *)argsArray
                         rsConverter:(PELMEntityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

#pragma mark - Helpers

+ (NSDate *)maxDateFromTable:(NSString *)table
                  dateColumn:(NSString *)dateColumn
                 whereColumn:(NSString *)whereColumn
                  whereValue:(id)whereValue
                          db:(FMDatabase *)db
                       error:(PELMDaoErrorBlk)errorBlk;

+ (NSDate *)dateFromTable:(NSString *)table
               dateColumn:(NSString *)dateColumn
              whereColumn:(NSString *)whereColumn
               whereValue:(id)whereValue
                       db:(FMDatabase *)db
                    error:(PELMDaoErrorBlk)errorBlk;

- (NSInteger)numEntitiesFromTable:(NSString *)table
                            error:(PELMDaoErrorBlk)errorBlk;

+ (NSInteger)numEntitiesFromTable:(NSString *)table
                               db:(FMDatabase *)db
                            error:(PELMDaoErrorBlk)errorBlk;

- (NSNumber *)numberFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                        error:(PELMDaoErrorBlk)errorBlk;

+ (NSNumber *)numberFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk;

- (NSString *)stringFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                        error:(PELMDaoErrorBlk)errorBlk;

+ (NSString *)stringFromTable:(NSString *)table
                 selectColumn:(NSString *)selectColumn
                  whereColumn:(NSString *)whereColumn
                   whereValue:(id)whereValue
                           db:(FMDatabase *)db
                        error:(PELMDaoErrorBlk)errorBlk;

@end
