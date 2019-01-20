//
//  RSSFolderUpdateData.h
//  Vole_xc5
//
//  Created by David Evans on 20/01/2019.
//
//

#import <Foundation/Foundation.h>

@interface RSSFolderUpdateData : NSObject

@property (atomic) NSInteger folderId;
@property (atomic) NSString * folderPath;
@property (atomic) NSDate * lastUpdate;
@property (atomic) NSString * title;
@property (atomic) NSString * description;
@property (atomic) NSString * link;


@end
