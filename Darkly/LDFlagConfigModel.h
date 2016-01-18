//
//  LDFlagConfigModel.h
//  Darkly
//
//  Created by Jeffrey Byrnes on 1/18/16.
//  Copyright © 2016 Darkly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LDFlagConfigModel : NSObject

@property (nullable, nonatomic, strong) NSDictionary *featuresJsonDictionary;

-(BOOL) isFlagOn: ( NSString * __nonnull )keyName;
-(BOOL) doesFlagExist: ( NSString * __nonnull )keyName;

@end