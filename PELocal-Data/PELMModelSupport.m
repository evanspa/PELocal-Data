//
//  PELMModelSupport.m
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

#import <PEObjc-Commons/PEUtils.h>
#import <PEHateoas-Client/HCRelation.h>
#import <PEHateoas-Client/HCMediaType.h>
#import <PELMModelSupport.h>
#import "PELMUtils.h"

@implementation PELMModelSupport

#pragma mark - Initializers

- (id)initWithLocalMainIdentifier:(NSNumber *)localMainIdentifier
            localMasterIdentifier:(NSNumber *)localMasterIdentifier
                 globalIdentifier:(NSString *)globalIdentifier
                  mainEntityTable:(NSString *)mainEntityTable
                masterEntityTable:(NSString *)masterEntityTable
                        mediaType:(HCMediaType *)mediaType
                        relations:(NSDictionary *)relations {
  self = [super init];
  if (self) {
    _localMainIdentifier = localMainIdentifier;
    _localMasterIdentifier = localMasterIdentifier;
    _globalIdentifier = globalIdentifier;
    _mainEntityTable = mainEntityTable;
    _masterEntityTable = masterEntityTable;
    _mediaType = mediaType;
    _relations = relations;
  }
  return self;
}

#pragma mark - Methods

- (void)overwrite:(PELMModelSupport *)entity {
  [self setRelations:[entity relations]];
  [self setGlobalIdentifier:[entity globalIdentifier]];
  [self setMediaType:[entity mediaType]];
}

#pragma mark - PELMIdentifiable Protocol

- (BOOL)doesHaveEqualIdentifiers:(id<PELMIdentifiable>)entity {
  if (_localMainIdentifier && [entity localMainIdentifier]) {
    return ([_localMainIdentifier isEqualToNumber:[entity localMainIdentifier]]);
  } else if (_globalIdentifier && [entity globalIdentifier]) {
    return ([_globalIdentifier isEqualToString:[entity globalIdentifier]]);
  } else if (_localMasterIdentifier && [entity localMasterIdentifier]) {
    return ([_localMasterIdentifier isEqualToNumber:[entity localMasterIdentifier]]);
  }
  return NO;
}

#pragma mark - Equality

- (BOOL)isEqualToModelSupport:(PELMModelSupport *)modelSupport {
  if (!modelSupport) { return NO; }
  BOOL hasEqualGlobalIds =
    [PEUtils isString:[self globalIdentifier]
              equalTo:[modelSupport globalIdentifier]];
  BOOL hasEqualMediaTypes = [PEUtils nilSafeIs:[self mediaType] equalTo:[modelSupport mediaType]];
  return hasEqualGlobalIds && hasEqualMediaTypes;
}

#pragma mark - NSObject

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isEqual:(id)object {
  if (self == object) { return YES; }
  if (![object isKindOfClass:[PELMModelSupport class]]) { return NO; }
  return [self isEqualToModelSupport:object];
}

- (NSUInteger)hash {
  return [[self globalIdentifier] hash] ^
    [[self localMainIdentifier] hash] ^ [[self localMasterIdentifier] hash] ^
    [[self mediaType] hash];
}

- (NSString *)description {
  NSMutableString *relationsDesc = [NSMutableString stringWithString:@"relations: ["];
  __block NSUInteger numRelations = [_relations count];
  [_relations enumerateKeysAndObjectsUsingBlock:^(id key, id relation, BOOL *stop) {
    [relationsDesc appendFormat:@"%@", relation];
    if ((numRelations + 1) < numRelations) {
      [relationsDesc appendString:@", "];
    }
    numRelations++;
  }];
  [relationsDesc appendString:@"]"];
  return [NSString stringWithFormat:@"type: [%@], memory address: [%p], local main ID: [%@], \
local master ID: [%@], global ID: [%@], media type: [%@], %@",
          NSStringFromClass([self class]), self, _localMainIdentifier, _localMasterIdentifier,
          _globalIdentifier, [_mediaType description], relationsDesc];
}

@end
