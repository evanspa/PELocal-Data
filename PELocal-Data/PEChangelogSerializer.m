//
//  FPChangelogSerializer.m
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

#import "PEChangelogSerializer.h"
#import <PEHateoas-Client/HCUtils.h>
#import <PEObjc-Commons/NSDictionary+PEAdditions.h>
#import "PEChangelog.h"

NSString * const PEChangelogUpdatedAtKey = @"changelog/updated-at";

@implementation PEChangelogSerializer {
  Class _changelogClass;
}

#pragma mark - Initializers

- (id)initWithMediaType:(HCMediaType *)mediaType
                charset:(HCCharset *)charset
serializersForEmbeddedResources:(NSDictionary *)embeddedSerializers
actionsForEmbeddedResources:(NSDictionary *)actions
         changelogClass:(Class)changelogClass {
  self = [super initWithMediaType:mediaType
                          charset:charset
  serializersForEmbeddedResources:embeddedSerializers
      actionsForEmbeddedResources:actions];
  if (self) {
    _changelogClass = changelogClass;
  }
  return self;
}

#pragma mark - Serialization (Resource Model -> JSON Dictionary)

- (NSDictionary *)dictionaryWithResourceModel:(id)resourceModel {
  return nil;
}

#pragma mark - Deserialization (JSON Dictionary -> Resource Model)

- (id)resourceModelWithDictionary:(NSDictionary *)resDict
                        relations:(NSDictionary *)relations
                        mediaType:(HCMediaType *)mediaType
                         location:(NSString *)location
                     lastModified:(NSDate *)lastModified {
  return [PEChangelog changelogOfClass:_changelogClass
                         withUpdatedAt:[resDict dateSince1970ForKey:PEChangelogUpdatedAtKey]];
}

@end
