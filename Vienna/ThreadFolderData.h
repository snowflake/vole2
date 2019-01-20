//
//  ThreadFolderData.h
//  Vole_xc5
//
//  Created by David Evans on 20/01/2019.
//
//

#import <Foundation/Foundation.h>
#import "VMessage.h"
@interface ThreadFolderData : NSObject


@property (atomic) NSString * folderPath;
@property (atomic) NSUInteger permissions;
@property (atomic) NSUInteger mask;
@property (atomic) VMessage * message;
@property (atomic) NSDate * lastUpdate;

@end
