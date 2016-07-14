//
//  PEUserCoordinatorDao.m
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

#import "PEUserCoordinatorDaoImpl.h"
#import "PEUtils.h" // from PEObjc-Commons
#import <PEHateoas-Client/HCRelation.h>
#import <PEHateoas-Client/HCResource.h>
#import "PELMUser.h"
#import "PELocalDao.h"
#import "PERemoteMasterDao.h"
#import "PEAuthTokenDelegate.h"

@implementation PEUserCoordinatorDaoImpl {
  NSInteger _timeout;
  NSString *_authToken;
  id<PELocalDao> _localDao;
  id<PERemoteMasterDao> _remoteMasterDao;
  PEUserMaker _userMaker;
  id<PEAuthTokenDelegate> _authTokenDelegate;
  NSString *_userFaultedErrorDomain;
  NSString *_systemFaultedErrorDomain;
  NSString *_connFaultedErrorDomain;
  NSInteger _signInAnyIssuesBit;
  NSInteger _signInInvalidEmailBit;
  NSInteger _signInEmailNotProvidedBit;
  NSInteger _signInPwdNotProvidedBit;
  NSInteger _signInInvalidCredentialsBit;
  NSInteger _sendPwdResetAnyIssuesBit;
  NSInteger _sendPwdResetUnknownEmailBit;
  NSInteger _saveUsrAnyIssuesBit;
  NSInteger _saveUsrInvalidEmailBit;
  NSInteger _saveUsrEmailNotProvidedBit;
  NSInteger _saveUsrPwdNotProvidedBit;
  NSInteger _saveUsrEmailAlreadyRegisteredBit;
  NSInteger _saveUsrConfirmPwdOnlyProvidedBit;
  NSInteger _saveUsrConfirmPwdNotProvidedBit;
  NSInteger _saveUsrPwdConfirmPwdDontMatchBit;
  NSString *_changeLogRelation;
}

#pragma mark - Initializers

- (id)initWithRemoteMasterDao:(id<PERemoteMasterDao>)remoteMasterDao
                     localDao:(id<PELocalDao>)localDao
                    userMaker:(PEUserMaker)userMaker
      timeoutForMainThreadOps:(NSInteger)timeout
            authTokenDelegate:(id<PEAuthTokenDelegate>)authTokenDelegate
       userFaultedErrorDomain:(NSString *)userFaultedErrorDomain
     systemFaultedErrorDomain:(NSString *)systemFaultedErrorDomain
       connFaultedErrorDomain:(NSString *)connFaultedErrorDomain
           signInAnyIssuesBit:(NSInteger)signInAnyIssuesBit
        signInInvalidEmailBit:(NSInteger)signInInvalidEmailBit
    signInEmailNotProvidedBit:(NSInteger)signInEmailNotProvidedBit
      signInPwdNotProvidedBit:(NSInteger)signInPwdNotProvidedBit
  signInInvalidCredentialsBit:(NSInteger)signInInvalidCredentialsBit
     sendPwdResetAnyIssuesBit:(NSInteger)sendPwdResetAnyIssuesBit
  sendPwdResetUnknownEmailBit:(NSInteger)sendPwdResetUnknownEmailBit
          saveUsrAnyIssuesBit:(NSInteger)saveUsrAnyIssuesBit
       saveUsrInvalidEmailBit:(NSInteger)saveUsrInvalidEmailBit
   saveUsrEmailNotProvidedBit:(NSInteger)saveUsrEmailNotProvidedBit
     saveUsrPwdNotProvidedBit:(NSInteger)saveUsrPwdNotProvidedBit
saveUsrEmailAlreadyRegisteredBit:(NSInteger)saveUsrEmailAlreadyRegisteredBit
saveUsrConfirmPwdOnlyProvidedBit:(NSInteger)saveUsrConfirmPwdOnlyProvidedBit
saveUsrConfirmPwdNotProvidedBit:(NSInteger)saveUsrConfirmPwdNotProvidedBit
saveUsrPwdConfirmPwdDontMatchBit:(NSInteger)saveUsrPwdConfirmPwdDontMatchBit
            changeLogRelation:(NSString *)changeLogRelation {
  self = [super init];
  if (self) {
    _localDao = localDao;
    _remoteMasterDao = remoteMasterDao;
    _userMaker = userMaker;
    _timeout = timeout;
    _authTokenDelegate = authTokenDelegate;
    
    _userFaultedErrorDomain = userFaultedErrorDomain;
    _systemFaultedErrorDomain = systemFaultedErrorDomain;
    _connFaultedErrorDomain = connFaultedErrorDomain;
    
    _signInAnyIssuesBit = signInAnyIssuesBit;
    _signInInvalidEmailBit = signInInvalidEmailBit;
    _signInEmailNotProvidedBit = signInEmailNotProvidedBit;
    _signInPwdNotProvidedBit = signInPwdNotProvidedBit;
    _signInInvalidCredentialsBit = signInInvalidCredentialsBit;
    
    _sendPwdResetAnyIssuesBit = sendPwdResetAnyIssuesBit;
    _sendPwdResetUnknownEmailBit = sendPwdResetUnknownEmailBit;
    
    _saveUsrAnyIssuesBit = saveUsrAnyIssuesBit;
    _saveUsrInvalidEmailBit = saveUsrInvalidEmailBit;
    _saveUsrEmailNotProvidedBit = saveUsrEmailNotProvidedBit;
    _saveUsrPwdNotProvidedBit = saveUsrPwdNotProvidedBit;
    _saveUsrEmailAlreadyRegisteredBit = saveUsrEmailAlreadyRegisteredBit;
    _saveUsrConfirmPwdOnlyProvidedBit = saveUsrConfirmPwdOnlyProvidedBit;
    _saveUsrConfirmPwdNotProvidedBit = saveUsrConfirmPwdNotProvidedBit;
    _saveUsrPwdConfirmPwdDontMatchBit = saveUsrPwdConfirmPwdDontMatchBit;
    _changeLogRelation = changeLogRelation;
  }
  return self;
}

#pragma mark - Getters / Setters

- (NSString *)authToken {
  return _authToken;
}

- (void)setAuthToken:(NSString *)authToken {
  _authToken = authToken;
  [_remoteMasterDao setAuthToken:authToken];
}

#pragma mark - User Operations

- (void)resetAsLocalUser:(PELMUser *)user error:(PELMDaoErrorBlk)error {
  [_localDao deleteUser:user error:error];
  PELMUser *newLocalUser = [self newLocalUserWithError:error];
  [user overwrite:newLocalUser];
  [user setLocalMainIdentifier:[newLocalUser localMainIdentifier]];
  [user setLocalMasterIdentifier:nil];
}

- (PELMUser *)newLocalUserWithError:(PELMDaoErrorBlk)errorBlk {
  PELMUser *user = _userMaker(nil, nil, nil);
  [_localDao saveNewLocalUser:user error:errorBlk];
  return user;
}

- (void)establishRemoteAccountForLocalUser:(PELMUser *)localUser
             preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                           remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                         completionHandler:(PESavedNewEntityCompletionHandler)complHandler
                     localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler {
  PELMRemoteMasterCompletionHandler remoteMasterComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    PELMUser *remoteUser = nil;
    if (globalId) { // success!
      remoteUser = resourceModel;
      [_localDao saveNewRemoteUser:remoteUser
           andLinkToLocalUser:localUser
preserveExistingLocalEntities:preserveExistingLocalEntities
                        error:localSaveErrorHandler];
      [self processNewAuthToken:newAuthTkn forUser:remoteUser];
    };
    complHandler(remoteUser, err);
  };
  [_remoteMasterDao establishAccountForUser:localUser
                                    timeout:_timeout
                            remoteStoreBusy:busyHandler
                               authRequired:[self authReqdBlk]
                          completionHandler:remoteMasterComplHandler];
}

- (void)loginWithEmail:(NSString *)email
              password:(NSString *)password
andLinkRemoteUserToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
       remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
     completionHandler:(PEFetchedEntityCompletionHandler)complHandler
 localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler {
  PELMRemoteMasterCompletionHandler masterStoreComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    PELMUser *remoteUser = resourceModel;
    if (remoteUser) {
      [_localDao deepSaveNewRemoteUser:remoteUser
                    andLinkToLocalUser:localUser
         preserveExistingLocalEntities:preserveExistingLocalEntities
                                 error:localSaveErrorHandler];
      [self processNewAuthToken:newAuthTkn forUser:remoteUser];
    }
    complHandler(remoteUser, err);
  };
  PELMRemoteMasterAuthReqdBlk authReqdBlk = ^(HCAuthentication *authReqd) {
    NSError *error = [NSError errorWithDomain:_userFaultedErrorDomain
                                         code:(_signInAnyIssuesBit | _signInInvalidCredentialsBit)
                                     userInfo:nil];
    complHandler(nil, error);
  };
  [_remoteMasterDao loginWithEmail:email
                          password:password
                           timeout:_timeout
                   remoteStoreBusy:busyHandler
                      authRequired:authReqdBlk
                 completionHandler:masterStoreComplHandler];
}

- (void)lightLoginForUser:(PELMUser *)user
                 password:(NSString *)password
          remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
        completionHandler:(void(^)(NSError *))complHandler
    localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler {
  PELMRemoteMasterCompletionHandler masterStoreComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    if (newAuthTkn) {
      [self processNewAuthToken:newAuthTkn forUser:user];
    }
    complHandler(err);
  };
  PELMRemoteMasterAuthReqdBlk authReqdBlk = ^(HCAuthentication *authReqd) {
    NSError *error = [NSError errorWithDomain:_userFaultedErrorDomain
                                         code:(_signInAnyIssuesBit | _signInInvalidCredentialsBit)
                                     userInfo:nil];
    complHandler(error);
  };
  [_remoteMasterDao lightLoginForUser:user
                             password:password
                              timeout:_timeout
                      remoteStoreBusy:busyHandler
                         authRequired:authReqdBlk
                    completionHandler:masterStoreComplHandler];
}

- (void)logoutUser:(PELMUser *)user
remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
 addlCompletionBlk:(void(^)(void))addlCompletionBlk
localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler {
  PELMRemoteMasterCompletionHandler masterStoreComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    // whether error or success, we're going to call the additional completion
    // block and delete the local user
    if (addlCompletionBlk) { addlCompletionBlk(); }
    [_localDao deleteUser:user error:localSaveErrorHandler];
    _authToken = nil;
  };
  [_remoteMasterDao logoutUser:user
                       timeout:_timeout
               remoteStoreBusy:remoteStoreBusyBlk
             completionHandler:masterStoreComplHandler];
}

- (void)resendVerificationEmailForUser:(PELMUser *)user
                    remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
                            successBlk:(void(^)(void))successBlk
                              errorBlk:(void(^)(void))errorBlk {
  PELMRemoteMasterCompletionHandler masterStoreComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    if (isConflict ||
        gone ||
        notFound ||
        movedPermanently ||
        ![PEUtils isNil:err]) {
      errorBlk();
    } else {
      successBlk();
    }
  };
  [_remoteMasterDao resendVerificationEmailForUser:user
                                           timeout:_timeout
                                   remoteStoreBusy:remoteStoreBusyBlk
                                 completionHandler:masterStoreComplHandler];
}

- (void)sendPasswordResetEmailToEmail:(NSString *)email
                   remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
                           successBlk:(void(^)(void))successBlk
                      unknownEmailBlk:(void(^)(void))unknownEmailBlk
                             errorBlk:(void(^)(void))errorBlk {
  PELMRemoteMasterCompletionHandler masterStoreComplHandler =
  ^(NSString *newAuthTkn, NSString *globalId, id resourceModel, NSDictionary *rels,
    NSDate *lastModified, BOOL isConflict, BOOL gone, BOOL notFound, BOOL movedPermanently,
    BOOL notModified, NSError *err, NSHTTPURLResponse *httpResp) {
    if (isConflict ||
        gone ||
        notFound ||
        movedPermanently) {
      errorBlk();
    } else if (![PEUtils isNil:err]) {
      if ([err code] & _sendPwdResetUnknownEmailBit) {
        unknownEmailBlk();
      } else {
        errorBlk();
      }
    } else {
      successBlk();
    }
  };
  [_remoteMasterDao sendPasswordResetEmailToEmail:email
                                          timeout:_timeout
                                  remoteStoreBusy:remoteStoreBusyBlk
                                completionHandler:masterStoreComplHandler];
}

- (void)flushUnsyncedChangesToUser:(PELMUser *)user
               notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
                    addlSuccessBlk:(void(^)(void))addlSuccessBlk
            addlRemoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)addlRemoteStoreBusyBlk
            addlTempRemoteErrorBlk:(void(^)(void))addlTempRemoteErrorBlk
                addlRemoteErrorBlk:(void(^)(NSInteger))addlRemoteErrorBlk
                   addlConflictBlk:(void(^)(PELMUser *))addlConflictBlk
               addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk
                             error:(PELMDaoErrorBlk)errorBlk {
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler =
  [PELMUtils complHandlerToFlushUnsyncedChangesToEntity:user
                                    remoteStoreErrorBlk:^(NSError *err, NSNumber *httpStatusCode) {
                                      [_localDao cancelSyncForUser:user httpRespCode:httpStatusCode errorMask:@([err code]) retryAt:nil error:errorBlk];
                                      [self invokeErrorBlocksForHttpStatusCode:httpStatusCode
                                                                         error:err
                                                            tempRemoteErrorBlk:addlTempRemoteErrorBlk
                                                                remoteErrorBlk:addlRemoteErrorBlk];
                                    }
                                      entityNotFoundBlk:^{ if (notFoundOnServerBlk) { notFoundOnServerBlk(); } }
                                      markAsConflictBlk:^(PELMUser *serverUser) {
                                        [_localDao cancelSyncForUser:user httpRespCode:@(409) errorMask:nil retryAt:nil error:errorBlk];
                                        if (addlConflictBlk) { addlConflictBlk(serverUser); }
                                      }
                      markAsSyncCompleteForNewEntityBlk:nil // because new users are always immediately synced upon creation
                 markAsSyncCompleteForExistingEntityBlk:^{
                   [_localDao markAsSyncCompleteForUser:user error:errorBlk];
                   if (addlSuccessBlk) { addlSuccessBlk(); }
                 }
                                        newAuthTokenBlk:^(NSString *newAuthTkn){[self processNewAuthToken:newAuthTkn forUser:user];}];
  [_remoteMasterDao saveExistingUser:user
                             timeout:_timeout
                     remoteStoreBusy:^(NSDate *retryAt) {
                       [_localDao cancelSyncForUser:user httpRespCode:@(503) errorMask:nil retryAt:retryAt error:errorBlk];
                       if (addlRemoteStoreBusyBlk) { addlRemoteStoreBusyBlk(retryAt); }
                     }
                        authRequired:^(HCAuthentication *auth) {
                          [self authReqdBlk](auth);
                          [_localDao cancelSyncForUser:(PELMUser *)user httpRespCode:@(401) errorMask:nil retryAt:nil error:errorBlk];
                          if (addlAuthRequiredBlk) { addlAuthRequiredBlk(); }
                        }
                   completionHandler:remoteStoreComplHandler];
}

- (void)markAsDoneEditingAndSyncUserImmediate:(PELMUser *)user
                          notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
                               addlSuccessBlk:(void(^)(void))addlSuccessBlk
                       addlRemoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)addlRemoteStoreBusyBlk
                       addlTempRemoteErrorBlk:(void(^)(void))addlTempRemoteErrorBlk
                           addlRemoteErrorBlk:(void(^)(NSInteger))addlRemoteErrorBlk
                              addlConflictBlk:(void(^)(PELMUser *))addlConflictBlk
                          addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk
                                        error:(PELMDaoErrorBlk)errorBlk {
  [_localDao markAsDoneEditingImmediateSyncUser:user error:errorBlk];
  [self flushUnsyncedChangesToUser:user
               notFoundOnServerBlk:notFoundOnServerBlk
                    addlSuccessBlk:addlSuccessBlk
            addlRemoteStoreBusyBlk:addlRemoteStoreBusyBlk
            addlTempRemoteErrorBlk:addlTempRemoteErrorBlk
                addlRemoteErrorBlk:addlRemoteErrorBlk
                   addlConflictBlk:addlConflictBlk
               addlAuthRequiredBlk:addlAuthRequiredBlk
                             error:errorBlk];
}

- (void)deleteUser:(PELMUser *)user
notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
    addlSuccessBlk:(void(^)(void))addlSuccessBlk
remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)addlRemoteStoreBusyBlk
tempRemoteErrorBlk:(void(^)(void))tempRemoteErrorBlk
    remoteErrorBlk:(void(^)(NSInteger))remoteErrorBlk
       conflictBlk:(void(^)(PELMUser *))conflictBlk
addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk
             error:(PELMDaoErrorBlk)errorBlk {
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler =
  [PELMUtils complHandlerToDeleteEntity:user
                    remoteStoreErrorBlk:^(NSError *err, NSNumber *httpStatusCode) {
                      [self invokeErrorBlocksForHttpStatusCode:httpStatusCode
                                                                         error:err
                                                            tempRemoteErrorBlk:tempRemoteErrorBlk
                                                                remoteErrorBlk:remoteErrorBlk];
                    }
                      entityNotFoundBlk:^{ if (notFoundOnServerBlk) { notFoundOnServerBlk(); } }
                      markAsConflictBlk:^(PELMUser *serverUser) { if (conflictBlk) { conflictBlk(serverUser); } }
                       deleteSuccessBlk:^{
                         [_localDao deleteUser:user error:errorBlk];
                         if (addlSuccessBlk) { addlSuccessBlk(); }
                       }
                        newAuthTokenBlk:^(NSString *newAuthTkn){[self processNewAuthToken:newAuthTkn forUser:user];}];
  [_remoteMasterDao deleteUser:user
                       timeout:_timeout
               remoteStoreBusy:^(NSDate *retryAfter) { if (addlRemoteStoreBusyBlk) { addlRemoteStoreBusyBlk(retryAfter); } }
                  authRequired:^(HCAuthentication *auth) {
                    [self authReqdBlk](auth);
                    if (addlAuthRequiredBlk) { addlAuthRequiredBlk(); }
                  }
             completionHandler:remoteStoreComplHandler];
}

- (void)fetchUser:(PELMUser *)user
  ifModifiedSince:(NSDate *)ifModifiedSince
notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
       successBlk:(void(^)(PELMUser *))successBlk
remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
tempRemoteErrorBlk:(void(^)(void))tempRemoteErrorBlk
addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk {
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler =
  [PELMUtils complHandlerToFetchEntityWithGlobalId:user.globalIdentifier
                               remoteStoreErrorBlk:^(NSError *err, NSNumber *httpStatusCode) { if (tempRemoteErrorBlk) { tempRemoteErrorBlk(); } }
                                 entityNotFoundBlk:^{ if (notFoundOnServerBlk) { notFoundOnServerBlk(); } }
                                  fetchCompleteBlk:^(PELMUser *fetchedUser) {
                                    if (successBlk) { successBlk(fetchedUser); }
                                  }
                                   newAuthTokenBlk:^(NSString *newAuthTkn){[self processNewAuthToken:newAuthTkn forUser:user];}];
  [_remoteMasterDao fetchUserWithGlobalId:user.globalIdentifier
                          ifModifiedSince:ifModifiedSince
                                  timeout:_timeout
                          remoteStoreBusy:^(NSDate *retryAfter) { if (remoteStoreBusyBlk) { remoteStoreBusyBlk(retryAfter); } }
                             authRequired:^(HCAuthentication *auth) {
                               [self authReqdBlk](auth);
                               if (addlAuthRequiredBlk) { addlAuthRequiredBlk(); }
                             }
                        completionHandler:remoteStoreComplHandler];
}

- (void)fetchChangelogForUser:(PELMUser *)user
              ifModifiedSince:(NSDate *)ifModifiedSince
          notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
                   successBlk:(void(^)(PEChangelog *))successBlk
           remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
           tempRemoteErrorBlk:(void(^)(void))tempRemoteErrorBlk
          addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk {
  HCRelation *changelogRelation = [[user relations] objectForKey:_changeLogRelation];
  PELMRemoteMasterCompletionHandler remoteStoreComplHandler =
  [PELMUtils complHandlerToFetchEntityWithGlobalId:changelogRelation.target.uri.absoluteString
                               remoteStoreErrorBlk:^(NSError *err, NSNumber *httpStatusCode) { if (tempRemoteErrorBlk) { tempRemoteErrorBlk(); } }
                                 entityNotFoundBlk:^{ if (notFoundOnServerBlk) { notFoundOnServerBlk(); } }
                                  fetchCompleteBlk:^(PEChangelog *fetchedChangelog) {
                                    if (successBlk) { successBlk(fetchedChangelog); }
                                  }
                                   newAuthTokenBlk:^(NSString *newAuthTkn){[self processNewAuthToken:newAuthTkn forUser:user];}];
  [_remoteMasterDao fetchChangelogWithGlobalId:changelogRelation.target.uri.absoluteString
                               ifModifiedSince:ifModifiedSince
                                       timeout:_timeout
                               remoteStoreBusy:^(NSDate *retryAfter) { if (remoteStoreBusyBlk) { remoteStoreBusyBlk(retryAfter); } }
                                  authRequired:^(HCAuthentication *auth) {
                                    [self authReqdBlk](auth);
                                    if (addlAuthRequiredBlk) { addlAuthRequiredBlk(); }
                                  }
                             completionHandler:remoteStoreComplHandler];
}

#pragma mark - Process Authentication Token

- (void)processNewAuthToken:(NSString *)newAuthToken forUser:(PELMUser *)user {
  if (newAuthToken) {
    [self setAuthToken:newAuthToken];
    dispatch_async(dispatch_get_main_queue(), ^{
      [_authTokenDelegate didReceiveNewAuthToken:newAuthToken
                         forUserGlobalIdentifier:[user globalIdentifier]];
    });
  }
}

#pragma mark - Authentication Required Block

- (PELMRemoteMasterAuthReqdBlk)authReqdBlk {
  return ^(HCAuthentication *auth) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_authTokenDelegate authRequired:auth];
    });
  };
}

#pragma mark - Helpers

- (void)invokeErrorBlocksForHttpStatusCode:(NSNumber *)httpStatusCode
                                     error:(NSError *)err
                        tempRemoteErrorBlk:(void(^)(void))tempRemoteErrorBlk
                            remoteErrorBlk:(void(^)(NSInteger))remoteErrorBlk {
  if (httpStatusCode) {
    if ([[err domain] isEqualToString:_userFaultedErrorDomain]) {
      if ([err code] > 0) {
        if (remoteErrorBlk) remoteErrorBlk([err code]);
      } else {
        if (tempRemoteErrorBlk) tempRemoteErrorBlk();
      }
    } else {
      if (tempRemoteErrorBlk) tempRemoteErrorBlk();
    }
  } else {
    // if no http status code, then it was a connection failure, and that by nature is temporary
    if (tempRemoteErrorBlk) tempRemoteErrorBlk();
  }
}

@end
