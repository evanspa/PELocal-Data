//
//  PERestRemoteMasterDao.m
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

#import "PERestRemoteMasterDao.h"
#import "PELMLoginUser.h"
#import <PEHateoas-Client/HCResource.h>
#import <PEHateoas-Client/HCAuthorization.h>
#import <PEHateoas-Client/HCRelationExecutor.h>
#import <PEHateoas-Client/HCRelation.h>
#import "PELMUser.h"
#import "PELoginSerializer.h"
#import "PEChangelogSerializer.h"
#import "PELogoutSerializer.h"
#import "PEResendVerificationEmailSerializer.h"
#import "PEPasswordResetSerializer.h"
#import "PEUserSerializer.h"

NSString * const LAST_MODIFIED_HEADER = @"last-modified";

@implementation PERestRemoteMasterDao

#pragma mark - Initializers

- (id)initWithAcceptCharset:(HCCharset *)acceptCharset
             acceptLanguage:(NSString *)acceptLanguage
         contentTypeCharset:(HCCharset *)contentTypeCharset
                 authScheme:(NSString *)authScheme
         authTokenParamName:(NSString *)authTokenParamName
                  authToken:(NSString *)authToken
        errorMaskHeaderName:(NSString *)errorMaskHeaderName
 establishSessionHeaderName:(NSString *)establishHeaderSessionName
        authTokenHeaderName:(NSString *)authTokenHeaderName
  ifModifiedSinceHeaderName:(NSString *)ifModifiedSinceHeaderName
ifUnmodifiedSinceHeaderName:(NSString *)ifUnmodifiedSinceHeaderName
loginFailedReasonHeaderName:(NSString *)loginFailedReasonHeaderName
accountClosedReasonHeaderName:(NSString *)accountClosedReasonHeaderName
bundleHoldingApiJsonResource:(NSBundle *)bundle
  nameOfApiJsonResourceFile:(NSString *)apiResourceFileName
            apiResMtVersion:(NSString *)apiResMtVersion
             userSerializer:(PEUserSerializer *)userSerializer
        changelogSerializer:(PEChangelogSerializer *)changelogSerializer
            loginSerializer:(PELoginSerializer *)loginSerializer
           logoutSerializer:(PELogoutSerializer *)logoutSerializer
resendVerificationEmailSerializer:(PEResendVerificationEmailSerializer *)resendVerificationEmailSerializer
    passwordResetSerializer:(PEPasswordResetSerializer *)passwordResetSerializer
   allowInvalidCertificates:(BOOL)allowInvalidCertificates
   clientFaultedErrorDomain:(NSString *)clientFaultedErrorDomain
     userFaultedErrorDomain:(NSString *)userFaultedErrorDomain
   systemFaultedErrorDomain:(NSString *)systemFaultedErrorDomain
     connFaultedErrorDomain:(NSString *)connFaultedErrorDomain
           restApiRelations:(NSDictionary *)restApiRelations {
  self = [super init];
  if (self) {
    _relationExecutor = [[HCRelationExecutor alloc] initWithDefaultAcceptCharset:acceptCharset
                                                           defaultAcceptLanguage:acceptLanguage
                                                       defaultContentTypeCharset:contentTypeCharset
                                                        allowInvalidCertificates:allowInvalidCertificates];
    _authScheme = authScheme;
    _authTokenParamName = authTokenParamName;
    _authToken = authToken;
    _errorMaskHeaderName = errorMaskHeaderName;
    _establishSessionHeaderName = establishHeaderSessionName;
    _authTokenHeaderName = authTokenHeaderName;
    _ifModifiedSinceHeaderName = ifModifiedSinceHeaderName;
    _ifUnmodifiedSinceHeaderName = ifUnmodifiedSinceHeaderName;
    _loginFailedReasonHeaderName = loginFailedReasonHeaderName;
    _accountClosedReasonHeaderName = accountClosedReasonHeaderName;
    _userSerializer = userSerializer;
    _changelogSerializer = changelogSerializer;
    _loginSerializer = loginSerializer;
    _logoutSerializer = logoutSerializer;
    _resendVerificationEmailSerializer = resendVerificationEmailSerializer;
    _passwordResetSerializer = passwordResetSerializer;
    _serialQueue = dispatch_queue_create("pe.local.model.serialqueue", DISPATCH_QUEUE_SERIAL);
    _clientFaultedErrorDomain = clientFaultedErrorDomain;
    _userFaultedErrorDomain = userFaultedErrorDomain;
    _systemFaultedErrorDomain = systemFaultedErrorDomain;
    _connFaultedErrorDomain = connFaultedErrorDomain;
    _restApiRelations = restApiRelations;
  }
  return self;
}

#pragma mark - PERemoteMasterDao Protocol

- (void)logoutUser:(PELMUser *)user
           timeout:(NSInteger)timeout
   remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
 completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [self doPostToRelation:[[user relations] objectForKey:PELMLogoutRelation]
      resourceModelParam:user
              serializer:_logoutSerializer
                 timeout:timeout
         remoteStoreBusy:busyHandler
            authRequired:nil
       completionHandler:complHandler
            otherHeaders:@{}];
}

- (void)resendVerificationEmailForUser:(PELMUser *)user
                               timeout:(NSInteger)timeout
                       remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                     completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [self doPostToRelation:[[user relations] objectForKey:PELMSendVerificationEmailRelation]
      resourceModelParam:user
              serializer:_resendVerificationEmailSerializer
                 timeout:timeout
         remoteStoreBusy:busyHandler
            authRequired:nil
       completionHandler:complHandler
            otherHeaders:@{}];
}

- (void)sendPasswordResetEmailToEmail:(NSString *)email
                              timeout:(NSInteger)timeout
                      remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                    completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  PELMLoginUser *unknownUser = [[PELMLoginUser alloc] init];
  [unknownUser setEmail:email];
  [self doPostToRelation:[_restApiRelations objectForKey:PELMSendPasswordResetEmailRelation]
      resourceModelParam:unknownUser
              serializer:_passwordResetSerializer
                 timeout:timeout
         remoteStoreBusy:busyHandler
            authRequired:nil
       completionHandler:complHandler
            otherHeaders:@{}];
}

- (void)establishAccountForUser:(PELMUser *)user
                        timeout:(NSInteger)timeout
                remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                   authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
              completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [self doPostToRelation:[_restApiRelations objectForKey:PELMUsersRelation]
      resourceModelParam:user
              serializer:_userSerializer
                 timeout:timeout
         remoteStoreBusy:busyHandler
            authRequired:authRequired
       completionHandler:complHandler
            otherHeaders:@{_establishSessionHeaderName : @"true"}];
}

- (void)saveExistingUser:(PELMUser *)user
                 timeout:(NSInteger)timeout
         remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
            authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
       completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [_relationExecutor
   doPutForTargetResource:[PERestRemoteMasterDao resourceFromModel:user]
   targetSerializer:_userSerializer
   asynchronous:YES
   completionQueue:_serialQueue
   authorization:[self authorization]
   success:[self newPutSuccessBlk:complHandler]
   redirection:[self newRedirectionBlk:complHandler]
   clientError:[self newClientErrBlk:complHandler]
   authenticationRequired:[PERestRemoteMasterDao toHCAuthReqdBlk:authRequired]
   serverError:[self newServerErrBlk:complHandler]
   unavailableError:[PERestRemoteMasterDao serverUnavailableBlk:busyHandler]
   conflict:[self newConflictBlk:complHandler]
   connectionFailure:[self newConnFailureBlk:complHandler]
   timeout:timeout
   otherHeaders:[self addFpIfUnmodifiedSinceHeaderToHeader:@{} entity:user]];
}

- (void)loginWithEmail:(NSString *)email
              password:(NSString *)password
         loginRelation:(NSString *)loginRelation
               timeout:(NSInteger)timeout
       remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
          authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
     completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  NSMutableDictionary *headers = [NSMutableDictionary new];
  [headers setObject:@"true" forKey:_establishSessionHeaderName];
  PELMLoginUser *loginUser = [[PELMLoginUser alloc] init];
  [loginUser setEmail:email];
  [loginUser setPassword:password];
  [self doPostToRelation:[_restApiRelations objectForKey:loginRelation]
      resourceModelParam:loginUser
              serializer:_loginSerializer
                 timeout:timeout
         remoteStoreBusy:busyHandler
            authRequired:authRequired
       completionHandler:complHandler
            otherHeaders:headers];
}

- (void)loginWithEmail:(NSString *)email
              password:(NSString *)password
               timeout:(NSInteger)timeout
       remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
          authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
     completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [self loginWithEmail:email
              password:password
         loginRelation:PELMLoginRelation
               timeout:timeout
       remoteStoreBusy:busyHandler
          authRequired:authRequired
     completionHandler:complHandler];
}

- (void)lightLoginForUser:(PELMUser *)user
                 password:(NSString *)password
                  timeout:(NSInteger)timeout
          remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
             authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
        completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [self loginWithEmail:[user email]
              password:password
         loginRelation:PELMLightLoginRelation
               timeout:timeout
       remoteStoreBusy:busyHandler
          authRequired:authRequired
     completionHandler:complHandler];
}

- (void)sendConfirmationEmailForUser:(PELMUser *)user
                             timeout:(NSInteger)timeout
                     remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                        authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
                   completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [self doPostToRelation:[[user relations] objectForKey:PELMSendEmailConfirmationRelation]
      resourceModelParam:user
              serializer:nil
                 timeout:timeout
         remoteStoreBusy:busyHandler
            authRequired:authRequired
       completionHandler:complHandler
            otherHeaders:@{}];
}

- (void)deleteUser:(PELMUser *)user
           timeout:(NSInteger)timeout
   remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
      authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
 completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [_relationExecutor
   doDeleteOfTargetResource:[PERestRemoteMasterDao resourceFromModel:user]
   wouldBeTargetSerializer:_userSerializer
   asynchronous:YES
   completionQueue:_serialQueue
   authorization:[self authorization]
   success:[self newDeleteSuccessBlk:complHandler]
   redirection:[self newRedirectionBlk:complHandler]
   clientError:[self newClientErrBlk:complHandler]
   authenticationRequired:[PERestRemoteMasterDao toHCAuthReqdBlk:authRequired]
   serverError:[self newServerErrBlk:complHandler]
   unavailableError:[PERestRemoteMasterDao serverUnavailableBlk:busyHandler]
   conflict:[self newConflictBlk:complHandler]
   connectionFailure:[self newConnFailureBlk:complHandler]
   timeout:timeout
   otherHeaders:[self addFpIfUnmodifiedSinceHeaderToHeader:@{} entity:user]];
}

- (void)fetchUserWithGlobalId:(NSString *)globalId
              ifModifiedSince:(NSDate *)ifModifiedSince
                      timeout:(NSInteger)timeout
              remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                 authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
            completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [_relationExecutor doGetForURLString:globalId
                       ifModifiedSince:nil
                      targetSerializer:_userSerializer
                          asynchronous:YES
                       completionQueue:_serialQueue
                         authorization:[self authorization]
                               success:[self newGetSuccessBlk:complHandler]
                           redirection:[self newRedirectionBlk:complHandler]
                           clientError:[self newClientErrBlk:complHandler]
                authenticationRequired:[PERestRemoteMasterDao toHCAuthReqdBlk:authRequired]
                           serverError:[self newServerErrBlk:complHandler]
                      unavailableError:[PERestRemoteMasterDao serverUnavailableBlk:busyHandler]
                     connectionFailure:[self newConnFailureBlk:complHandler]
                               timeout:timeout
                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                          otherHeaders:[self addDateHeaderToHeaders:@{} headerName:_ifModifiedSinceHeaderName value:ifModifiedSince]];
}

#pragma mark - Helpers

- (NSDictionary *)addDateHeaderToHeaders:(NSDictionary *)headers
                              headerName:(NSString *)headerName
                                   value:(NSDate *)value {
  if (value) {
    NSMutableDictionary *newHeaders = [headers mutableCopy];
    [newHeaders setObject:[[NSNumber numberWithDouble:([value timeIntervalSince1970] * 1000)] description]
                   forKey:headerName];
    return newHeaders;
  } else {
    return headers;
  }
}

- (NSDictionary *)addFpIfUnmodifiedSinceHeaderToHeader:(NSDictionary *)headers
                                                entity:(PELMMasterSupport *)entity {
  return [self addDateHeaderToHeaders:headers
                           headerName:_ifUnmodifiedSinceHeaderName
                                value:[entity updatedAt]];
}

+ (HCServerUnavailableBlk)serverUnavailableBlk:(PELMRemoteMasterBusyBlk)busyHandler {
  return ^(NSDate *retryAfter, NSHTTPURLResponse *resp) {
    if (busyHandler) { busyHandler(retryAfter); }
  };
}

+ (HCResource *)resourceFromModel:(PELMModelSupport *)model {
  return [[HCResource alloc]
          initWithMediaType:[model mediaType]
          uri:[NSURL URLWithString:[model globalIdentifier]]
          model:model];
}

+ (HCAuthReqdErrorBlk)toHCAuthReqdBlk:(PELMRemoteMasterAuthReqdBlk)authReqdBlk {
  return ^(HCAuthentication *auth, NSHTTPURLResponse *resp) {
    if (authReqdBlk) { authReqdBlk(auth); }
  };
}

- (HCClientErrorBlk)newClientErrBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSHTTPURLResponse *httpResp) {
    NSString *fpErrMaskStr = [[httpResp allHeaderFields] objectForKey:_errorMaskHeaderName];
    NSError *error =
    [NSError errorWithDomain:_userFaultedErrorDomain code:[fpErrMaskStr intValue] userInfo:nil];
    BOOL gone = [httpResp statusCode] == 410;
    BOOL notFound = [httpResp statusCode] == 404;
    // now, the reason why "NO" is harded into the 'inConflict' block parameter
    // is because we have a specific block type (HCConflictBlk) to handle the
    // special case of the "409" client error type
    complHandler(nil, nil, nil, nil, nil, NO, gone, notFound, NO, NO, error, httpResp);
  };
}

- (HCRedirectionBlk)newRedirectionBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSURL *location, BOOL movedPermanently, BOOL notModified, NSHTTPURLResponse *resp) {
    NSString *authToken = [[resp allHeaderFields] objectForKey:_authTokenHeaderName];
    complHandler(authToken, [location absoluteString], nil, nil, nil, NO, NO, NO, movedPermanently, notModified, nil, resp);
  };
}

- (HCServerErrorBlk)newServerErrBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSHTTPURLResponse *resp) {
    NSString *fpErrMaskStr = [[resp allHeaderFields] objectForKey:_errorMaskHeaderName];
    NSInteger codeForError = 0;
    if (fpErrMaskStr) {
      codeForError = [fpErrMaskStr integerValue];
    }
    NSError *error = [NSError errorWithDomain:_systemFaultedErrorDomain code:codeForError userInfo:nil];
    complHandler(nil, nil, nil, nil, nil, NO, NO, NO, NO, NO, error, resp);
  };
}

- (HCConnFailureBlk)newConnFailureBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSInteger nsurlErr) {
    NSError *error = [NSError errorWithDomain:_connFaultedErrorDomain code:nsurlErr userInfo:nil];
    complHandler(nil, nil, nil, nil, nil, NO, NO, NO, NO, NO, error, nil);
  };
}

- (HCGETSuccessBlk)newGetSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSURL *location, id resModel, NSDate *lastModified, NSDictionary *rels, NSHTTPURLResponse *resp) {
    NSString *authToken = [[resp allHeaderFields] objectForKey:_authTokenHeaderName];
    complHandler(authToken, [location absoluteString], resModel, rels, lastModified, NO, NO, NO, NO, NO, nil, resp);
  };
}

- (HCPOSTSuccessBlk)newPostSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSURL *location, id resModel, NSDate *lastModified, NSDictionary *rels, NSHTTPURLResponse *resp) {
    NSString *authToken = [[resp allHeaderFields] objectForKey:_authTokenHeaderName];
    complHandler(authToken, [location absoluteString], resModel, rels, lastModified, NO, NO, NO, NO, NO, nil, resp);
  };
}

- (HCDELETESuccessBlk)newDeleteSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSHTTPURLResponse *resp) {
    NSString *authToken = [[resp allHeaderFields] objectForKey:_authTokenHeaderName];
    complHandler(authToken, nil, nil, nil, nil, NO, NO, NO, NO, NO, nil, resp);
  };
}

- (HCPUTSuccessBlk)newPutSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSURL *location, id resModel, NSDate *lastModified, NSDictionary *rels, NSHTTPURLResponse *resp) {
    NSString *authToken = [[resp allHeaderFields] objectForKey:_authTokenHeaderName];
    complHandler(authToken, [location absoluteString], resModel, rels, lastModified, NO, NO, NO, NO, NO, nil, resp);
  };
}

- (HCConflictBlk)newConflictBlk:(PELMRemoteMasterCompletionHandler)complHandler {
  return ^(NSURL *location, id resModel, NSDate *lastModified, NSDictionary *rels, NSHTTPURLResponse *resp) {
    NSString *authToken = [[resp allHeaderFields] objectForKey:_authTokenHeaderName];
    NSError *error = [NSError errorWithDomain:_clientFaultedErrorDomain code:[resp statusCode] userInfo:nil];
    complHandler(authToken, [location absoluteString], resModel, rels, lastModified, YES, NO, NO, NO, NO, error, resp);
  };
}

- (HCAuthorization *)authorization {
  HCAuthorization *authorization = nil;
  if (_authToken) {
    authorization = [HCAuthorization authWithScheme:_authScheme
                                singleAuthParamName:_authTokenParamName
                                     authParamValue:_authToken];
  }
  return authorization;
}

- (void)doPostToRelation:(HCRelation *)relation
      resourceModelParam:(id)resourceModelParam
              serializer:(id<HCResourceSerializer>)serializer
                 timeout:(NSInteger)timeout
         remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
            authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
       completionHandler:(PELMRemoteMasterCompletionHandler)complHandler
            otherHeaders:(NSDictionary *)otherHeaders {
  [_relationExecutor doPostForTargetResource:[relation target]
                          resourceModelParam:resourceModelParam
                             paramSerializer:serializer
                    responseEntitySerializer:serializer
                                asynchronous:YES
                             completionQueue:_serialQueue
                               authorization:[self authorization]
                                     success:[self newPostSuccessBlk:complHandler]
                                 redirection:[self newRedirectionBlk:complHandler]
                                 clientError:[self newClientErrBlk:complHandler]
                      authenticationRequired:[PERestRemoteMasterDao toHCAuthReqdBlk:authRequired]
                                 serverError:[self newServerErrBlk:complHandler]
                            unavailableError:[PERestRemoteMasterDao serverUnavailableBlk:busyHandler]
                           connectionFailure:[self newConnFailureBlk:complHandler]
                                     timeout:timeout
                                otherHeaders:otherHeaders];
}

#pragma mark - Changelog Operations

- (void)fetchChangelogWithGlobalId:(NSString *)globalId
                   ifModifiedSince:(NSDate *)ifModifiedSince
                           timeout:(NSInteger)timeout
                   remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
                      authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
                 completionHandler:(PELMRemoteMasterCompletionHandler)complHandler {
  [_relationExecutor doGetForURLString:globalId
                       ifModifiedSince:nil
                      targetSerializer:_changelogSerializer
                          asynchronous:YES
                       completionQueue:self.serialQueue
                         authorization:[self authorization]
                               success:[self newGetSuccessBlk:complHandler]
                           redirection:[self newRedirectionBlk:complHandler]
                           clientError:[self newClientErrBlk:complHandler]
                authenticationRequired:[PERestRemoteMasterDao toHCAuthReqdBlk:authRequired]
                           serverError:[self newServerErrBlk:complHandler]
                      unavailableError:[PERestRemoteMasterDao serverUnavailableBlk:busyHandler]
                     connectionFailure:[self newConnFailureBlk:complHandler]
                               timeout:timeout
                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                          otherHeaders:[self addDateHeaderToHeaders:@{} headerName:self.ifModifiedSinceHeaderName value:ifModifiedSince]];
}

#pragma mark - General Operations

- (void)setAuthToken:(NSString *)authToken {
  _authToken = authToken;
}

@end
