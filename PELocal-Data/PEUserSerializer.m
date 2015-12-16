//
//  PEUserSerializer.m
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

#import "PEUserSerializer.h"
#import "PELMUser.h"
#import <PEObjc-Commons/NSMutableDictionary+PEAdditions.h>
#import <PEObjc-Commons/NSDictionary+PEAdditions.h>
#import <PEHateoas-Client/HCUtils.h>

NSString * const PEUserFullnameKey     = @"user/name";
NSString * const PEUserEmailKey        = @"user/email";
NSString * const PEUserPasswordKey     = @"user/password";
NSString * const PEUserVerifiedAtKey   = @"user/verified-at";
NSString * const PEUserCreatedAtKey    = @"user/created-at";
NSString * const PEUserUpdatedAtKey    = @"user/updated-at";
NSString * const PEUserDeletedAtKey    = @"user/deleted-at";

@implementation PEUserSerializer {
  Class _userClass;
}

#pragma mark - Initializers

- (id)initWithMediaType:(HCMediaType *)mediaType
                charset:(HCCharset *)charset
serializersForEmbeddedResources:(NSDictionary *)embeddedSerializers
actionsForEmbeddedResources:(NSDictionary *)actions
              userClass:(Class)userClass {
  self = [super initWithMediaType:mediaType
                          charset:charset
  serializersForEmbeddedResources:embeddedSerializers
      actionsForEmbeddedResources:actions];
  if (self) {
    _userClass = userClass;
  }
  return self;
}

#pragma mark - Serialization (Resource Model -> JSON Dictionary)

- (NSDictionary *)dictionaryWithResourceModel:(id)resourceModel {
  PELMUser *user = (PELMUser *)resourceModel;
  NSMutableDictionary *userDict = [NSMutableDictionary dictionary];
  [userDict nullSafeSetObject:[user name] forKey:PEUserFullnameKey];
  [userDict nullSafeSetObject:[user email] forKey:PEUserEmailKey];
  [userDict setStringIfNotBlank:[user password] forKey:PEUserPasswordKey];
  return userDict;
}

#pragma mark - Deserialization (JSON Dictionary -> Resource Model)

- (id)resourceModelWithDictionary:(NSDictionary *)resDict
                        relations:(NSDictionary *)relations
                        mediaType:(HCMediaType *)mediaType
                         location:(NSString *)location
                     lastModified:(NSDate *)lastModified {
  return [PELMUser userOfClass:_userClass
                      withName:[resDict objectForKey:PEUserFullnameKey]
                         email:[resDict objectForKey:PEUserEmailKey]
                      password:[resDict objectForKey:PEUserPasswordKey]
                    verifiedAt:[resDict dateSince1970ForKey:PEUserVerifiedAtKey]
              globalIdentifier:location
                     mediaType:mediaType
                     relations:relations
                     createdAt:[resDict dateSince1970ForKey:PEUserCreatedAtKey]
                     deletedAt:[resDict dateSince1970ForKey:PEUserDeletedAtKey]
                     updatedAt:[resDict dateSince1970ForKey:PEUserUpdatedAtKey]];
}

@end
