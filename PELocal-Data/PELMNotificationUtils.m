//
//  PELMNotificationUtils.m
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

#import "PELMNotificationUtils.h"

NSString * const PELMNotificationEntitiesUserInfoKey = @"PELMNotificationEntitiesUserInfoKey";

@implementation PELMNotificationUtils

+ (void)postNotificationWithName:(NSString *)notificationName
                        entities:(NSArray *)entities {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter]
      postNotificationName:notificationName
                    object:nil
                  userInfo:@{PELMNotificationEntitiesUserInfoKey : entities}];
  });
}

+ (void)postNotificationWithName:(NSString *)notificationName
                          entity:(PELMMainSupport *)entity {
  NSArray *entities;
  if (entity) {
    entities = @[entity];
  } else {
    entities = @[];
  }
  [PELMNotificationUtils postNotificationWithName:notificationName
                                         entities:entities];
}

+ (void)postNotificationWithName:(NSString *)notificationName {
  [PELMNotificationUtils postNotificationWithName:notificationName
                                         entities:@[]];
}

+ (NSArray *)entitiesFromNotification:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  if (userInfo) {
    return userInfo[PELMNotificationEntitiesUserInfoKey];
  }
  return nil;
}

+ (NSNumber *)indexOfEntityRef:(PELMMainSupport *)entity
                  notification:(NSNotification *)notification {
  NSArray *entities = [PELMNotificationUtils entitiesFromNotification:notification];
  NSInteger numEntities = [entities count];
  for (NSInteger i = 0; i < numEntities; i++) {
    if ([entity doesHaveEqualIdentifiers:entities[i]]) {
      return @(i);
    }
  }
  return nil;
}

+ (PELMMainSupport *)entityAtIndex:(NSInteger)index
                      notification:(NSNotification *)notification {
  NSArray *entities = [PELMNotificationUtils entitiesFromNotification:notification];
  if (index < [entities count]) {
    return entities[index];
  }
  return nil;
}

@end