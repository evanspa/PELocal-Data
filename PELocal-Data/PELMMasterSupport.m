//
//  PELMMasterSupport.m
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

#import "PELMMasterSupport.h"
#import "PEUtils.h" // from PEObjc-Commons

@implementation PELMMasterSupport

#pragma mark - Initializers

- (id)initWithLocalMainIdentifier:(NSNumber *)localMainIdentifier
            localMasterIdentifier:(NSNumber *)localMasterIdentifier
                 globalIdentifier:(NSString *)globalIdentifier
                  mainEntityTable:(NSString *)mainEntityTable
                masterEntityTable:(NSString *)masterEntityTable
                        mediaType:(HCMediaType *)mediaType
                        relations:(NSDictionary *)relations
                        createdAt:(NSDate *)createdAt
                        deletedAt:(NSDate *)deletedAt
                        updatedAt:(NSDate *)updatedAt {
  self = [super initWithLocalMainIdentifier:localMainIdentifier
                      localMasterIdentifier:localMasterIdentifier
                           globalIdentifier:globalIdentifier
                            mainEntityTable:mainEntityTable
                          masterEntityTable:masterEntityTable
                                  mediaType:mediaType
                                  relations:relations];
  if (self) {
    _createdAt = createdAt;
    _deletedAt = deletedAt;
    _updatedAt = updatedAt;
  }
  return self;
}

#pragma mark - Methods

- (void)overwrite:(PELMMasterSupport *)entity {
  [super overwrite:entity];
  [self setCreatedAt:[entity createdAt]];
  [self setUpdatedAt:[entity updatedAt]];
  [self setDeletedAt:[entity deletedAt]];
}

#pragma mark - Equality

- (BOOL)isEqualToMasterSupport:(PELMMasterSupport *)masterSupport {
  if (!masterSupport) { return NO; }
  if ([super isEqualToModelSupport:masterSupport]) {
    return [PEUtils isDate:[self deletedAt] msprecisionEqualTo:[masterSupport deletedAt]] &&
      [PEUtils isDate:[self updatedAt] msprecisionEqualTo:[masterSupport updatedAt]] &&
      [PEUtils isDate:[self createdAt] msprecisionEqualTo:[masterSupport createdAt]];
  }
  return NO;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
  if (self == object) { return YES; }
  if (![object isKindOfClass:[PELMMasterSupport class]]) { return NO; }
  return [self isEqualToMasterSupport:object];
}

- (NSUInteger)hash {
  return [super hash] ^
    [[self deletedAt] hash] ^
    [[self updatedAt] hash] ^
    [[self createdAt] hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@, created-at: [{%@}, {%f}], deleted-at: [{%@}, {%f}], updated-at: [{%@}, {%f}]",
          [super description],
          _createdAt, [_createdAt timeIntervalSince1970],
          _deletedAt, [_deletedAt timeIntervalSince1970],
          _updatedAt, [_updatedAt timeIntervalSince1970]];
}

@end
