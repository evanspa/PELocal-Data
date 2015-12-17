//
//  FPLoginSerializer.m
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

#import "PELoginSerializer.h"
#import "PELMLoginUser.h"
#import <PEObjc-Commons/NSMutableDictionary+PEAdditions.h>
#import "PEUserSerializer.h"

NSString * const PELoginUserEmailKey    = @"user/username-or-email";
NSString * const PELoginUserPasswordKey = @"user/password";

@implementation PELoginSerializer {
  PEUserSerializer *_userSerializer;
}

- (id)initWithMediaType:(HCMediaType *)mediaType
                charset:(HCCharset *)charset
         userSerializer:(PEUserSerializer *)userSerializer {
  self = [super initWithMediaType:mediaType
                          charset:charset
  serializersForEmbeddedResources:[userSerializer embeddedSerializers]
      actionsForEmbeddedResources:[userSerializer embeddedResourceActions]];
  if (self) {
    _userSerializer = userSerializer;
  }
  return self;
}

#pragma mark - Serialization (Resource Model -> JSON Dictionary)

- (NSDictionary *)dictionaryWithResourceModel:(id)resourceModel {
  PELMLoginUser *loginUser = (PELMLoginUser *)resourceModel;
  NSMutableDictionary *userDict = [NSMutableDictionary dictionary];
  [userDict setObjectIfNotNull:[loginUser email] forKey:PELoginUserEmailKey];
  [userDict setObjectIfNotNull:[loginUser password] forKey:PELoginUserPasswordKey];
  return userDict;
}

#pragma mark - Deserialization (JSON Dictionary -> Resource Model)

- (id)resourceModelWithDictionary:(NSDictionary *)resDict
                        relations:(NSDictionary *)relations
                        mediaType:(HCMediaType *)mediaType
                         location:(NSString *)location
                     lastModified:(NSDate *)lastModified {
  return [_userSerializer resourceModelWithDictionary:resDict
                                            relations:relations
                                            mediaType:mediaType
                                             location:location
                                         lastModified:lastModified];
}

@end
