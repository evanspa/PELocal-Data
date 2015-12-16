//
//  PERestRemoteMasterDao.h
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

#import <Foundation/Foundation.h>
#import <PEHateoas-Client/HCMediaType.h>
#import <PEHateoas-Client/HCCharset.h>
#import <PEHateoas-Client/HCRelationExecutor.h>
#import <PEHateoas-Client/HCUtils.h>
#import <PEHateoas-Client/HCRelation.h>
#import "PERemoteMasterDao.h"
#import "PEUserSerializer.h"
#import "PEChangelogSerializer.h"
#import "PELoginSerializer.h"
#import "PELogoutSerializer.h"
#import "PEResendVerificationEmailSerializer.h"
#import "PEPasswordResetSerializer.h"

FOUNDATION_EXPORT NSString * const LAST_MODIFIED_HEADER;

@interface PERestRemoteMasterDao : NSObject <PERemoteMasterDao>

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
           restApiRelations:(NSDictionary *)restApiRelations;

#pragma mark - Properties

@property (nonatomic) NSString *authToken;

@property (nonatomic, readonly) NSDictionary *restApiRelations;

@property (nonatomic, readonly) HCRelationExecutor *relationExecutor;

@property (nonatomic, readonly) NSString *authScheme;

@property (nonatomic, readonly) NSString *authTokenParamName;

@property (nonatomic, readonly) NSString *errorMaskHeaderName;

@property (nonatomic, readonly) NSString *establishSessionHeaderName;

@property (nonatomic, readonly) NSString *authTokenHeaderName;

@property (nonatomic, readonly) NSString *ifModifiedSinceHeaderName;

@property (nonatomic, readonly) NSString *ifUnmodifiedSinceHeaderName;

@property (nonatomic, readonly) NSString *loginFailedReasonHeaderName;

@property (nonatomic, readonly) NSString *accountClosedReasonHeaderName;

@property (nonatomic, readonly) PEUserSerializer *userSerializer;

@property (nonatomic, readonly) PEChangelogSerializer *changelogSerializer;

@property (nonatomic, readonly) PELoginSerializer *loginSerializer;

@property (nonatomic, readonly) PELogoutSerializer *logoutSerializer;

@property (nonatomic, readonly) PEResendVerificationEmailSerializer *resendVerificationEmailSerializer;

@property (nonatomic, readonly) PEPasswordResetSerializer *passwordResetSerializer;

@property (nonatomic, readonly) dispatch_queue_t serialQueue;

@property (nonatomic, readonly) NSString *clientFaultedErrorDomain;

@property (nonatomic, readonly) NSString *userFaultedErrorDomain;

@property (nonatomic, readonly) NSString *systemFaultedErrorDomain;

@property (nonatomic, readonly) NSString *connFaultedErrorDomain;

#pragma mark - Helpers

- (NSDictionary *)addDateHeaderToHeaders:(NSDictionary *)headers
                              headerName:(NSString *)headerName
                                   value:(NSDate *)value;

- (NSDictionary *)addFpIfUnmodifiedSinceHeaderToHeader:(NSDictionary *)headers
                                                entity:(PELMMasterSupport *)entity;

+ (HCServerUnavailableBlk)serverUnavailableBlk:(PELMRemoteMasterBusyBlk)busyHandler;

+ (HCResource *)resourceFromModel:(PELMModelSupport *)model;

+ (HCAuthReqdErrorBlk)toHCAuthReqdBlk:(PELMRemoteMasterAuthReqdBlk)authReqdBlk;

- (HCClientErrorBlk)newClientErrBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCRedirectionBlk)newRedirectionBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCServerErrorBlk)newServerErrBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCConnFailureBlk)newConnFailureBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCGETSuccessBlk)newGetSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCPOSTSuccessBlk)newPostSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCDELETESuccessBlk)newDeleteSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCPUTSuccessBlk)newPutSuccessBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCConflictBlk)newConflictBlk:(PELMRemoteMasterCompletionHandler)complHandler;

- (HCAuthorization *)authorization;

- (void)doPostToRelation:(HCRelation *)relation
      resourceModelParam:(id)resourceModelParam
              serializer:(id<HCResourceSerializer>)serializer
                 timeout:(NSInteger)timeout
         remoteStoreBusy:(PELMRemoteMasterBusyBlk)busyHandler
            authRequired:(PELMRemoteMasterAuthReqdBlk)authRequired
       completionHandler:(PELMRemoteMasterCompletionHandler)complHandler
            otherHeaders:(NSDictionary *)otherHeaders;

@end
