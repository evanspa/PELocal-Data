//
//  PELMUser.h
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
#import "PELMMainSupport.h"

FOUNDATION_EXPORT NSString * const PELMUsersRelation;
FOUNDATION_EXPORT NSString * const PELMLoginRelation;
FOUNDATION_EXPORT NSString * const PELMLightLoginRelation;
FOUNDATION_EXPORT NSString * const PELMLogoutRelation;
FOUNDATION_EXPORT NSString * const PELMSendVerificationEmailRelation;
FOUNDATION_EXPORT NSString * const PELMSendPasswordResetEmailRelation;
FOUNDATION_EXPORT NSString * const PELMSendEmailConfirmationRelation;

@interface PELMUser : PELMMainSupport <NSCopying>

#pragma mark - Initializers

- (id)initWithLocalMainIdentifier:(NSNumber *)localMainIdentifier
            localMasterIdentifier:(NSNumber *)localMasterIdentifier
                 globalIdentifier:(NSString *)globalIdentifier
                        mediaType:(HCMediaType *)mediaType
                        relations:(NSDictionary *)relations
                        createdAt:(NSDate *)createdAt
                        deletedAt:(NSDate *)deletedAt
                        updatedAt:(NSDate *)updatedAt
             dateCopiedFromMaster:(NSDate *)dateCopiedFromMaster
                   editInProgress:(BOOL)editInProgress
                   syncInProgress:(BOOL)syncInProgress
                           synced:(BOOL)synced
                        editCount:(NSUInteger)editCount
                 syncHttpRespCode:(NSNumber *)syncHttpRespCode
                      syncErrMask:(NSNumber *)syncErrMask
                      syncRetryAt:(NSDate *)syncRetryAt
                             name:(NSString *)name
                            email:(NSString *)email
                         password:(NSString *)password
                       verifiedAt:(NSDate *)verifiedAt;

#pragma mark - Creation Functions

+ (PELMUser *)userOfClass:(Class)clazz
                 withName:(NSString *)name
                    email:(NSString *)email
                 password:(NSString *)password
                mediaType:(HCMediaType *)mediaType;

+ (PELMUser *)userOfClass:(Class)clazz
                 withName:(NSString *)name
                    email:(NSString *)email
                 password:(NSString *)password
               verifiedAt:(NSDate *)verifiedAt
         globalIdentifier:(NSString *)globalIdentifier
                mediaType:(HCMediaType *)mediaType
                relations:(NSDictionary *)relations
                createdAt:(NSDate *)createdAt
                deletedAt:(NSDate *)deletedAt
                updatedAt:(NSDate *)updatedAt;

#pragma mark - Methods

- (void)overwrite:(PELMUser *)user;

#pragma mark - Properties

@property (nonatomic) NSString *name;

@property (nonatomic) NSString *email;

@property (nonatomic) NSString *password;

@property (nonatomic) NSString *confirmPassword;

@property (nonatomic) NSDate *verifiedAt;

#pragma mark - Equality

- (BOOL)isEqualToUser:(PELMUser *)user;

@end
