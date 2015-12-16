//
//  PEUserCoordinatorDao.h
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

#import "PELocalDao.h"
#import "PERemoteMasterDao.h"
#import "PEAuthTokenDelegate.h"

typedef void (^PESavedNewEntityCompletionHandler)(PELMUser *, NSError *);

typedef void (^PEFetchedEntityCompletionHandler)(id, NSError *);

typedef PELMUser * (^PEUserMaker)(NSString *, NSString *, NSString *);

@protocol PEUserCoordinatorDao <NSObject>

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
            changeLogRelation:(NSString *)changeLogRelation;

#pragma mark - Getters / Setters

- (NSString *)authToken;

- (void)setAuthToken:(NSString *)authToken;

#pragma mark - User Operations

- (void)resetAsLocalUser:(PELMUser *)user error:(PELMDaoErrorBlk)error;

- (PELMUser *)newLocalUserWithError:(PELMDaoErrorBlk)errorBlk;

- (void)establishRemoteAccountForLocalUser:(PELMUser *)localUser
             preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
                           remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                         completionHandler:(PESavedNewEntityCompletionHandler)complHandler
                     localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler;

- (void)loginWithEmail:(NSString *)email
              password:(NSString *)password
andLinkRemoteUserToLocalUser:(PELMUser *)localUser
preserveExistingLocalEntities:(BOOL)preserveExistingLocalEntities
       remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
     completionHandler:(PEFetchedEntityCompletionHandler)complHandler
 localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler;

- (void)lightLoginForUser:(PELMUser *)user
                 password:(NSString *)password
          remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
        completionHandler:(void(^)(NSError *))complHandler
    localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler;

- (void)logoutUser:(PELMUser *)user
remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
 addlCompletionBlk:(void(^)(void))addlCompletionBlk
localSaveErrorHandler:(PELMDaoErrorBlk)localSaveErrorHandler;

- (void)resendVerificationEmailForUser:(PELMUser *)user
                    remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
                            successBlk:(void(^)(void))successBlk
                              errorBlk:(void(^)(void))errorBlk;

- (void)sendPasswordResetEmailToEmail:(NSString *)email
                   remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
                           successBlk:(void(^)(void))successBlk
                      unknownEmailBlk:(void(^)(void))unknownEmailBlk
                             errorBlk:(void(^)(void))errorBlk;

- (void)flushUnsyncedChangesToUser:(PELMUser *)user
               notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
                    addlSuccessBlk:(void(^)(void))addlSuccessBlk
            addlRemoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)addlRemoteStoreBusyBlk
            addlTempRemoteErrorBlk:(void(^)(void))addlTempRemoteErrorBlk
                addlRemoteErrorBlk:(void(^)(NSInteger))addlRemoteErrorBlk
                   addlConflictBlk:(void(^)(PELMUser *))addlConflictBlk
               addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk
                             error:(PELMDaoErrorBlk)errorBlk;

- (void)markAsDoneEditingAndSyncUserImmediate:(PELMUser *)user
                          notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
                               addlSuccessBlk:(void(^)(void))addlSuccessBlk
                       addlRemoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)addlRemoteStoreBusyBlk
                       addlTempRemoteErrorBlk:(void(^)(void))addlTempRemoteErrorBlk
                           addlRemoteErrorBlk:(void(^)(NSInteger))addlRemoteErrorBlk
                              addlConflictBlk:(void(^)(PELMUser *))addlConflictBlk
                          addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk
                                        error:(PELMDaoErrorBlk)errorBlk;

- (void)deleteUser:(PELMUser *)user
notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
    addlSuccessBlk:(void(^)(void))addlSuccessBlk
remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)addlRemoteStoreBusyBlk
tempRemoteErrorBlk:(void(^)(void))addlTempRemoteErrorBlk
    remoteErrorBlk:(void(^)(NSInteger))addlRemoteErrorBlk
       conflictBlk:(void(^)(PELMUser *))conflictBlk
addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk
             error:(PELMDaoErrorBlk)errorBlk;

- (void)fetchUser:(PELMUser *)user
  ifModifiedSince:(NSDate *)ifModifiedSince
notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
       successBlk:(void(^)(PELMUser *))successBlk
remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
tempRemoteErrorBlk:(void(^)(void))tempRemoteErrorBlk
addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk;

- (void)fetchChangelogForUser:(PELMUser *)user
              ifModifiedSince:(NSDate *)ifModifiedSince
          notFoundOnServerBlk:(void(^)(void))notFoundOnServerBlk
                   successBlk:(void(^)(PEChangelog *))successBlk
           remoteStoreBusyBlk:(PELMRemoteMasterBusyBlk)remoteStoreBusyBlk
           tempRemoteErrorBlk:(void(^)(void))tempRemoteErrorBlk
          addlAuthRequiredBlk:(void(^)(void))addlAuthRequiredBlk;

#pragma mark - Process Authentication Token

- (void)processNewAuthToken:(NSString *)newAuthToken forUser:(PELMUser *)user;

#pragma mark - Authentication Required Block

- (PELMRemoteMasterAuthReqdBlk)authReqdBlk;

@end
