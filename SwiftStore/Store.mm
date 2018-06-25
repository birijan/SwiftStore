//
//  OLDB.m
//  LevelDBTest
//
//  Created by Hemanta Sapkota on 1/05/2015.
//  Copyright (c) 2015 Hemanta Sapkota. All rights reserved.
//

#import "Store.h"

#include <iostream>
#include <sstream>
#include <string>

#import <leveldb/db.h>
#import <leveldb/write_batch.h>

using namespace std;

@implementation Store {
  leveldb::DB *db;
}

- (instancetype) initWithDBName:(NSString *) dbName {
  self = [super init];
  if (self) {
    [self createDB:dbName];
  }
  return self;
}

-(void)createDB:(NSString *) dbName {
    NSLog(@"MyDBName %@", dbName);
  leveldb::Options options;
  options.create_if_missing = true;
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  
  /* Lock Folder */
  NSError *error = nil;
  NSString *dbPath = [paths[0] stringByAppendingPathComponent:dbName];
    NSLog(@"Path:: %@", dbPath);

  /* Create lock file. For some reason, leveldb cannot create the LOCK directory. So we make it. */
  NSString *lockFolderPath = [dbPath stringByAppendingPathComponent:@"LOCK"];
  
  NSFileManager *mgr = [NSFileManager defaultManager];
  if (![mgr fileExistsAtPath:lockFolderPath]) {
    NSURL *url = [NSURL fileURLWithPath:dbPath];
    [mgr createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (error != nil) {
        NSLog(@"%@", error);
        return;
    }
  }
  /* End lock folder */
  
  leveldb::Status status = leveldb::DB::Open(options, [dbPath UTF8String], &self->db);
  if (false == status.ok()) {
      NSLog(@"ERROR: Unable to open/create database.");
      std::cout << status.ToString();
  } else {
      NSLog(@"INFO: Database setup.");
  }
}

-(NSArray *)findKeys:(NSString *)key {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    
    leveldb::Slice slice = leveldb::Slice(key.UTF8String);

    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (it->Seek(slice); it->Valid() && it->key().starts_with(slice); it->Next()) {
        
//        NSString *value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding: NSUTF32StringEncoding];
        
//        NSError *jsonError;
        NSString *value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding:NSUTF8StringEncoding];
//        NSData *objectData = [value dataUsingEncoding:[NSString defaultCStringEncoding]];
        
//        NSArray *strings = [NSJSONSerialization JSONObjectWithData:objectData options:kNilOptions error:NULL];
        
//        const char* elems = it->value().data();
//
//        NSMutableString *result = [NSMutableString string];
//        for (int i = 0; i < [objectData length]; i++)
//        {
//            [result appendFormat:@"%02hhx", (unsigned char)elems[i]];
//        }
//
        
        
//        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
//                                                             options:NSJSONReadingMutableContainers
//                                                               error:&jsonError];
//        NSString *key = [[NSString alloc] initWithCString:it->key().ToString().c_str() encoding: NSUTF8StringEncoding];
//        NSArray *result = [self getBytes: key];
        
//        NSString *value = @(it->value().ToString().c_str());
        [array addObject:value];
    }
    delete it;
    
    return array;
}

-(NSArray *)findMatchingKeys:(NSString *)key {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    
    leveldb::Slice slice = leveldb::Slice(key.UTF8String);
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (it->Seek(slice); it->Valid() && it->key().starts_with(slice); it->Next()) {
        NSString *value = [[NSString alloc] initWithCString:it->key().ToString().c_str() encoding:NSUTF8StringEncoding];
        [array addObject:value];
    }
    delete it;
    
    return array;
}

-(NSArray *)getBytes:(NSString *)key {

    std::string data;
    leveldb::Slice slice = leveldb::Slice(key.UTF8String);
    leveldb::Status status = db->Get(leveldb::ReadOptions(), slice, &data);

    if (status.ok()) {
        int size = data.size();

        char* elems = const_cast<char*>(data.data());
        NSMutableArray *array = [[NSMutableArray alloc] init];

//        jbyteArray array = env->NewByteArray(size * sizeof(jbyte));
        [array addObject: @(elems)];
//        env->SetByteArrayRegion(array, 0, size, reinterpret_cast<jbyte*>(elems));
//        LOGI("Successfully reading a byte array");
        return array;

    } else {
        std::string err("Failed to get a byte array: " + status.ToString());
//        throwException(env, err.c_str());
        return NULL;
    }
}


-(NSDictionary *)findKeysWithIndex:(NSString *)key {
    leveldb::ReadOptions readOptions;
    leveldb::Iterator *it = db->NewIterator(readOptions);
    
    leveldb::Slice slice = leveldb::Slice(key.UTF8String);
    
    NSMutableDictionary *array = [[NSMutableDictionary alloc] init];
    
    for (it->Seek(slice); it->Valid() && it->key().starts_with(slice); it->Next()) {
        NSString *value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding: NSUTF8StringEncoding];
        NSString *key = [[NSString alloc] initWithCString:it->key().ToString().c_str() encoding: NSUTF8StringEncoding];
        [array setObject:value forKey: key];
    }
    delete it;
    return array;
}

-(NSArray *)iterate:(NSString *)key {
  leveldb::ReadOptions readOptions;
  leveldb::Iterator *it = db->NewIterator(readOptions);
  
  leveldb::Slice slice = leveldb::Slice(key.UTF8String);
  
  std::string endKey = key.UTF8String;
  endKey.append("0xFF");
  
  NSMutableArray *array = [[NSMutableArray alloc] init];
  
  for (it->Seek(slice); it->Valid() && it->key().ToString() < endKey; it->Next()) {
    NSString *value = [[NSString alloc] initWithCString:it->value().ToString().c_str() encoding:[NSString defaultCStringEncoding]];
    [array addObject:value];
  }
  delete it;
  
  return array;
}

-(bool)deleteBatch:(NSArray*)keys {
  leveldb::WriteBatch batch;
  
  for (int i=0; i <[keys count]; i++) {
    NSString *key = [keys objectAtIndex:i];
    leveldb::Slice slice = leveldb::Slice(key.UTF8String);
    batch.Delete(slice);
  }
  
  leveldb::Status s = self->db->Write(leveldb::WriteOptions(), &batch);
  return s.ok();
}

-(NSString *)get:(NSString *)key {
  ostringstream keyStream;
  keyStream << key.UTF8String;
  
  leveldb::ReadOptions readOptions;
  string value;
  leveldb::Status s = self->db->Get(readOptions, keyStream.str(), &value);
  
  NSString *nsstr = [[NSString alloc] initWithUTF8String:value.c_str()];
  
  return [nsstr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

-(bool)put:(NSString *)key value:(NSString *)value {
  ostringstream keyStream;
  keyStream << key.UTF8String;
  
  ostringstream valueStream;
  valueStream << value.UTF8String;

  leveldb::WriteOptions writeOptions;
  leveldb::Status s = self->db->Put(writeOptions, keyStream.str(), valueStream.str());
  
  return s.ok();
}

-(bool)delete:(NSString *)key {
  ostringstream keySream;
  keySream << key.UTF8String;
  
  leveldb::WriteOptions writeOptions;
  leveldb::Status s = self->db->Delete(writeOptions, keySream.str());
  
  return s.ok();
}

-(void)close {
  delete self->db;
}

@end
