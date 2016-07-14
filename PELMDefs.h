//
//  PELMDefs.h
//  PELocal-Data
//
//  Created by Paul Evans on 12/18/15.
//  Copyright © 2015 Paul Evans. All rights reserved.
//

@class HCAuthentication;
@class FMResultSet;
@class FMDatabase;
@class PELMMainSupport;

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

typedef NSDictionary * (^PELMRelationsFromResultSetBlk)(FMResultSet *);

typedef id (^PELMEntityFromResultSetBlk)(FMResultSet *);

typedef void (^PELMEditPrepInvariantChecksBlk)(PELMMainSupport *, PELMMainSupport *);

typedef void (^PELMMainEntityInserterBlk)(PELMMainSupport *, FMDatabase *, PELMDaoErrorBlk);

typedef void (^PELMMainEntityUpdaterBlk)(PELMMainSupport *, FMDatabase *, PELMDaoErrorBlk);

typedef void (^PELMCannotBe)(BOOL, NSString *);

typedef id (^PELMOrNil)(id);

typedef void (^PELMLogSyncRemoteMaster)(NSString *, NSInteger);

typedef void (^PELMLogSystemPrune)(NSString *, NSInteger);

typedef void (^PELMLogSyncLocal)(NSString *, NSInteger);

typedef NS_ENUM(NSInteger, PELMSaveNewOrExistingCode) {
  PELMSaveNewOrExistingCodeDidNothing,
  PELMSaveNewOrExistingCodeDidUpdate,
  PELMSaveNewOrExistingCodeDidInsert
};
