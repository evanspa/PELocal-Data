//
//  PELocalModelDDL.h
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

//##############################################################################
// Shared columns
//##############################################################################
// ----Columns common to both main and master entities--------------------------
FOUNDATION_EXPORT NSString * const COL_LOCAL_ID;
FOUNDATION_EXPORT NSString * const COL_MAIN_USER_ID;
FOUNDATION_EXPORT NSString * const COL_MASTER_USER_ID;
FOUNDATION_EXPORT NSString * const COL_GLOBAL_ID;
FOUNDATION_EXPORT NSString * const COL_MEDIA_TYPE;
FOUNDATION_EXPORT NSString * const COL_REL_NAME;
FOUNDATION_EXPORT NSString * const COL_REL_URI;
FOUNDATION_EXPORT NSString * const COL_REL_MEDIA_TYPE;
// ----Common master columns----------------------------------------------------
FOUNDATION_EXPORT NSString * const COL_MST_CREATED_AT;
FOUNDATION_EXPORT NSString * const COL_MST_UPDATED_AT;
FOUNDATION_EXPORT NSString * const COL_MST_DELETED_DT;
// ----Common main columns------------------------------------------------------
FOUNDATION_EXPORT NSString * const COL_MAN_MASTER_UPDATED_AT;
FOUNDATION_EXPORT NSString * const COL_MAN_DT_COPIED_DOWN_FROM_MASTER;
FOUNDATION_EXPORT NSString * const COL_MAN_EDIT_IN_PROGRESS;
FOUNDATION_EXPORT NSString * const COL_MAN_SYNC_IN_PROGRESS;
FOUNDATION_EXPORT NSString * const COL_MAN_SYNCED;
FOUNDATION_EXPORT NSString * const COL_MAN_EDIT_COUNT;
FOUNDATION_EXPORT NSString * const COL_MAN_SYNC_HTTP_RESP_CODE;
FOUNDATION_EXPORT NSString * const COL_MAN_SYNC_ERR_MASK;
FOUNDATION_EXPORT NSString * const COL_MAN_SYNC_RETRY_AT;
// ----Common table names-------------------------------------------------------
FOUNDATION_EXPORT NSString * const TBLSUFFIX_RELATION_ENTITY;

//##############################################################################
// User Entity (main and master)
//##############################################################################
// ----Table names--------------------------------------------------------------
FOUNDATION_EXPORT NSString * const TBL_MASTER_USER;
FOUNDATION_EXPORT NSString * const TBL_MAIN_USER;
// ----Columns------------------------------------------------------------------
FOUNDATION_EXPORT NSString * const COL_USR_NAME;
FOUNDATION_EXPORT NSString * const COL_USR_EMAIL;
FOUNDATION_EXPORT NSString * const COL_USR_PASSWORD_HASH;
FOUNDATION_EXPORT NSString * const COL_USR_VERIFIED_AT;

@interface PELMDDL : NSObject

+ (NSString *)indexDDLForEntity:(NSString *)entity
                         unique:(BOOL)unique
                         column:(NSString *)column
                      indexName:(NSString *)indexName;

+ (NSString *)indexDDLForEntity:(NSString *)entity
                         unique:(BOOL)unique
                        columns:(NSArray *)columns
                      indexName:(NSString *)indexName;

+ (NSString *)relTableForEntityTable:(NSString *)entityTable;

+ (NSString *)relFkColumnForEntityTable:(NSString *)entityTable
                         entityPkColumn:(NSString *)entityPkColumn;

+ (NSString *)relDDLForEntityTable:(NSString *)entityTable
                    entityPkColumn:(NSString *)entityPkColumn;

+ (NSString *)relDDLForEntityTable:(NSString *)entityTable;

@end
