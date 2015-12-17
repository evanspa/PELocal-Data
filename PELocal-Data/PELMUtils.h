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

@class FMDatabase;
@class FMDatabaseQueue;
@class FMResultSet;
@class HCAuthentication;

@class PELMModelSupport;
@class PELMMainSupport;
@class PELMMasterSupport;

/**
 Param 1 (NSString *): New authentication token.
 Param 2 (NSString *): The global identifier of the newly created resource, in
 the event the request was a POST to create a resource.  If the request was not
 a POST to create a resource, this parameter may be nil.
 Param 3 (id): Resource returned in the response (in the case of a GET or a
 PUT).  This parameter may be nil.
 Param 4 (NSDictionary *): The relations associated with the subject-resource
 Param 5 (NSDate *): The last-modified date of the subject-resource of the HTTP request (this response-header should be present on ALL 2XX responses)
 Param 6 (BOOL): Whether or not the subject-resource is gone (existed at one point, but has since been deleted).
 Param 7 (BOOL): Whether or not the subject-resource is not-found (i.e., never exists).
 Param 8 (BOOL): Whether or not the subject-resource has permanently moved
 Param 9 (BOOL): Whether or not the subject-resource has not been modified based on conditional-fetch criteria
 Param 10 (NSError *): Encapsulates error information in the event of an error.
 Param 11 (NSHTTPURLResponse *): The raw HTTP response.
 */
typedef void (^PELMRemoteMasterCompletionHandler)(NSString *, // auth token
                                                  NSString *, // global URI (location) (in case of moved-permenantly, will be new location of resource)
                                                  id,         // resource returned in response (in case of 409, will be master's copy of subject-resource)
                                                  NSDictionary *, // resource relations
                                                  NSDate *,   // last modified date
                                                  BOOL,       // is conflict (if YES, then id param will be latest version of result)
                                                  BOOL,       // gone
                                                  BOOL,       // not found
                                                  BOOL,       // moved permanently
                                                  BOOL,       // not modified
                                                  NSError *,  // error
                                                  NSHTTPURLResponse *); // raw HTTP response

typedef void (^PELMRemoteMasterBusyBlk)(NSDate *);

typedef void (^PELMRemoteMasterAuthReqdBlk)(HCAuthentication *);

typedef void (^PELMDaoErrorBlk)(NSError *, int, NSString *);

typedef NSDictionary * (^relationsFromResultSetBlk)(FMResultSet *);

typedef id (^entityFromResultSetBlk)(FMResultSet *);

typedef void (^editPrepInvariantChecksBlk)(PELMMainSupport *, PELMMainSupport *);

typedef void (^mainEntityInserterBlk)(PELMMainSupport *, FMDatabase *, PELMDaoErrorBlk);

typedef void (^mainEntityUpdaterBlk)(PELMMainSupport *, FMDatabase *, PELMDaoErrorBlk);

void (^cannotBe)(BOOL, NSString *);

id (^orNil)(id);

void (^LogSyncRemoteMaster)(NSString *, NSInteger);

void (^LogSystemPrune)(NSString *, NSInteger);

void (^LogSyncLocal)(NSString *, NSInteger);

typedef NS_ENUM(NSInteger, PELMSaveNewOrExistingCode) {
  PELMSaveNewOrExistingCodeDidNothing,
  PELMSaveNewOrExistingCodeDidUpdate,
  PELMSaveNewOrExistingCodeDidInsert
};

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
               rsConverter:(entityFromResultSetBlk)rsConverter
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
                                   mainEntityFromResultSet:(entityFromResultSetBlk)mainEntityFromResultSet
                                            mainUpdateStmt:(NSString *)mainUpdateStmt
                                         mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                                                     error:(PELMDaoErrorBlk)errorBlk;

+ (PELMSaveNewOrExistingCode)saveNewOrExistingMasterEntity:(PELMMainSupport *)masterEntity
                                               masterTable:(NSString *)masterTable
                                           masterInsertBlk:(void (^)(id, FMDatabase *))masterInsertBlk
                                          masterUpdateStmt:(NSString *)masterUpdateStmt
                                       masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
                                                 mainTable:(NSString *)mainTable
                                   mainEntityFromResultSet:(entityFromResultSetBlk)mainEntityFromResultSet
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
 mainEntityFromResultSet:(entityFromResultSetBlk)mainEntityFromResultSet
          mainUpdateStmt:(NSString *)mainUpdateStmt
       mainUpdateArgsBlk:(NSArray *(^)(id))mainUpdateArgsBlk
                   error:(PELMDaoErrorBlk)errorBlk;

+ (BOOL)saveMasterEntity:(PELMMainSupport *)masterEntity
             masterTable:(NSString *)masterTable
        masterUpdateStmt:(NSString *)masterUpdateStmt
     masterUpdateArgsBlk:(NSArray *(^)(id))masterUpdateArgsBlk
               mainTable:(NSString *)mainTable
 mainEntityFromResultSet:(entityFromResultSetBlk)mainEntityFromResultSet
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

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
         parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                   pageBoundaryWhere:(NSString *)pageBoundaryWhere
                     pageBoundaryArg:(id)pageBoundaryArg
                   entityMasterTable:(NSString *)entityMasterTable
      masterEntityResultSetConverter:(entityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
        mainEntityResultSetConverter:(entityFromResultSetBlk)mainEntityResultSetConverter
                   comparatorForSort:(NSComparisonResult(^)(id, id))comparatorForSort
                 orderByDomainColumn:(NSString *)orderByDomainColumn
        orderByDomainColumnDirection:(NSString *)orderByDomainColumnDirection
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)unsyncedEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                       parentEntityMainTable:(NSString *)parentEntityMainTable
                 parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
                  parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
                    parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                                    pageSize:(NSNumber *)pageSize
                           entityMasterTable:(NSString *)entityMasterTable
              masterEntityResultSetConverter:(entityFromResultSetBlk)masterEntityResultSetConverter
                             entityMainTable:(NSString *)entityMainTable
                mainEntityResultSetConverter:(entityFromResultSetBlk)mainEntityResultSetConverter
                           comparatorForSort:(NSComparisonResult(^)(id, id))comparatorForSort
                         orderByDomainColumn:(NSString *)orderByDomainColumn
                orderByDomainColumnDirection:(NSString *)orderByDomainColumnDirection
                                          db:(FMDatabase *)db
                                       error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
         parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                            whereBlk:(NSString *(^)(NSString *))whereBlk
                           whereArgs:(NSArray *)whereArgs
                   entityMasterTable:(NSString *)entityMasterTable
      masterEntityResultSetConverter:(entityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
        mainEntityResultSetConverter:(entityFromResultSetBlk)mainEntityResultSetConverter
                   comparatorForSort:(NSComparisonResult(^)(id, id))comparatorForSort
                 orderByDomainColumn:(NSString *)orderByDomainColumn
        orderByDomainColumnDirection:(NSString *)orderByDomainColumnDirection
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)entitiesForParentEntity:(PELMModelSupport *)parentEntity
               parentEntityMainTable:(NSString *)parentEntityMainTable
         parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
          parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
            parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                            pageSize:(NSNumber *)pageSize
                            whereBlk:(NSString *(^)(NSString *))whereBlk
                           whereArgs:(NSArray *)whereArgs
                   entityMasterTable:(NSString *)entityMasterTable
      masterEntityResultSetConverter:(entityFromResultSetBlk)masterEntityResultSetConverter
                     entityMainTable:(NSString *)entityMainTable
        mainEntityResultSetConverter:(entityFromResultSetBlk)mainEntityResultSetConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSInteger)numEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                  parentEntityMainTable:(NSString *)parentEntityMainTable
            parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
             parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
               parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                      entityMasterTable:(NSString *)entityMasterTable
                        entityMainTable:(NSString *)entityMainTable
                                     db:(FMDatabase *)db
                                  error:(PELMDaoErrorBlk)errorBlk;

+ (NSInteger)numEntitiesForParentEntity:(PELMModelSupport *)parentEntity
                  parentEntityMainTable:(NSString *)parentEntityMainTable
            parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
             parentEntityMasterIdColumn:(NSString *)parentEntityMasterIdColumn
               parentEntityMainIdColumn:(NSString *)parentEntityMainIdColumn
                      entityMasterTable:(NSString *)entityMasterTable
                        entityMainTable:(NSString *)entityMainTable
                                  where:(NSString *)where
                               whereArg:(id)whereArg
                                     db:(FMDatabase *)db
                                  error:(PELMDaoErrorBlk)errorBlk;

+ (PELMMainSupport *)parentForChildEntity:(PELMMainSupport *)childEntity
                    parentEntityMainTable:(NSString *)parentEntityMainTable
                  parentEntityMasterTable:(NSString *)parentEntityMasterTable
                 parentEntityMainFkColumn:(NSString *)parentEntityMainFkColumn
               parentEntityMasterFkColumn:(NSString *)parentEntityMasterFkColumn
              parentEntityMainRsConverter:(entityFromResultSetBlk)parentEntityMainRsConverter
            parentEntityMasterRsConverter:(entityFromResultSetBlk)parentEntityMasterRsConverter
                     childEntityMainTable:(NSString *)childEntityMainTable
               childEntityMainRsConverter:(entityFromResultSetBlk)childEntityMainRsConverter
                   childEntityMasterTable:(NSString *)childEntityMasterTable
                                       db:(FMDatabase *)db
                                    error:(PELMDaoErrorBlk)errorBlk;

+ (PELMMainSupport *)masterParentForMasterChildEntity:(PELMMainSupport *)childEntity
                              parentEntityMasterTable:(NSString *)parentEntityMasterTable
                           parentEntityMasterFkColumn:(NSString *)parentEntityMasterFkColumn
                        parentEntityMasterRsConverter:(entityFromResultSetBlk)parentEntityMasterRsConverter
                               childEntityMasterTable:(NSString *)childEntityMasterTable
                                                   db:(FMDatabase *)db
                                                error:(PELMDaoErrorBlk)errorBlk;

+ (NSNumber *)localMainIdentifierForEntity:(PELMModelSupport *)entity
                                 mainTable:(NSString *)mainTable
                                        db:(FMDatabase *)db
                                     error:(PELMDaoErrorBlk)errorBlk;

- (void)reloadEntity:(PELMModelSupport *)entity
       fromMainTable:(NSString *)mainTable
         rsConverter:(entityFromResultSetBlk)rsConverter
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
                                 entityFromResultSet:(entityFromResultSetBlk)entityFromResultSet
                                          updateStmt:(NSString *)updateStmt
                                       updateArgsBlk:(NSArray *(^)(PELMMainSupport *))updateArgsBlk
                                           filterBlk:(BOOL(^)(PELMMainSupport *))filterBlk
                                               error:(PELMDaoErrorBlk)errorBlk;

- (NSArray *)markEntitiesAsSyncInProgressInMainTable:(NSString *)mainTable
                                 entityFromResultSet:(entityFromResultSetBlk)entityFromResultSet
                                          updateStmt:(NSString *)updateStmt
                                       updateArgsBlk:(NSArray *(^)(PELMMainSupport *))updateArgsBlk
                                               error:(PELMDaoErrorBlk)errorBlk;

+ (BOOL)prepareEntityForEdit:(PELMMainSupport *)entity
                          db:(FMDatabase *)db
                   mainTable:(NSString *)mainTable
         entityFromResultSet:(entityFromResultSetBlk)entityFromResultSet
          mainEntityInserter:(mainEntityInserterBlk)mainEntityInserter
           mainEntityUpdater:(mainEntityUpdaterBlk)mainEntityUpdater
                       error:(PELMDaoErrorBlk)errorBlk;

- (BOOL)prepareEntityForEditInTxn:(PELMMainSupport *)entity
                        mainTable:(NSString *)mainTable
              entityFromResultSet:(entityFromResultSetBlk)entityFromResultSet
               mainEntityInserter:(mainEntityInserterBlk)mainEntityInserter
                mainEntityUpdater:(mainEntityUpdaterBlk)mainEntityUpdater
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
          rsConverter:(entityFromResultSetBlk)rsConverter
                   db:(FMDatabase *)db
                error:(PELMDaoErrorBlk)errorBlk;

+ (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
            argsArray:(NSArray *)argsArray
          rsConverter:(entityFromResultSetBlk)rsConverter
                   db:(FMDatabase *)db
                error:(PELMDaoErrorBlk)errorBlk;

- (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
          rsConverter:(entityFromResultSetBlk)rsConverter
                error:(PELMDaoErrorBlk)errorBlk;

- (id)entityFromQuery:(NSString *)query
          entityTable:(NSString *)entityTable
        localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
            argsArray:(NSArray *)argsArray
          rsConverter:(entityFromResultSetBlk)rsConverter
                error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)mainEntitiesFromQuery:(NSString *)query
                       entityTable:(NSString *)entityTable
                         argsArray:(NSArray *)argsArray
                       rsConverter:(entityFromResultSetBlk)rsConverter
                                db:(FMDatabase *)db
                             error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)masterEntitiesFromQuery:(NSString *)query
                         entityTable:(NSString *)entityTable
                           argsArray:(NSArray *)argsArray
                         rsConverter:(entityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)mainEntitiesFromQuery:(NSString *)query
                        numAllowed:(NSNumber *)numAllowed
                       entityTable:(NSString *)entityTable
                         argsArray:(NSArray *)argsArray
                       rsConverter:(entityFromResultSetBlk)rsConverter
                                db:(FMDatabase *)db
                             error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)masterEntitiesFromQuery:(NSString *)query
                          numAllowed:(NSNumber *)numAllowed
                         entityTable:(NSString *)entityTable
                           argsArray:(NSArray *)argsArray
                         rsConverter:(entityFromResultSetBlk)rsConverter
                                  db:(FMDatabase *)db
                               error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)entitiesFromQuery:(NSString *)query
                    numAllowed:(NSNumber *)numAllowed
                   entityTable:(NSString *)entityTable
                 localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
                     argsArray:(NSArray *)argsArray
                   rsConverter:(entityFromResultSetBlk)rsConverter
                            db:(FMDatabase *)db
                         error:(PELMDaoErrorBlk)errorBlk;

+ (NSArray *)entitiesFromEntityTable:(NSString *)entityTable
                         whereClause:(NSString *)whereClause
                       localIdGetter:(NSNumber *(^)(PELMModelSupport *))localIdGetter
                           argsArray:(NSArray *)argsArray
                         rsConverter:(entityFromResultSetBlk)rsConverter
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
