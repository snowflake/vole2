//
//  AppController.h
//  Vienna
//
//  Created by Steve on Sat Jan 24 2004.
//  Copyright (c) 2004 Steve Palmer. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import "Vole.h"
#import "Growl/GrowlApplicationBridge.h"


#import "Database.h"
#import "Connect.h"
#import "ConnectProtocol.h"
#import "MessageListView.h"
#import "BacktrackArray.h"
#import "ActivityViewer.h"
#import "TasksWindow.h"
#import "ExtDateFormatter.h"
#import "Join.h"
#import "Credentials.h"
#import "Profile.h"
#import "VoleBuildInfoController.h"

@class PreferenceController;
@class AuthenticationController;
@class ImportController;
@class ExportController;
@class MissingMessagesController;
@class FoldersTree;
@class MessageInfoBar;
@class FolderHeaderBar;
@class MessageWindow;
@class PersonManager;
@class CheckForUpdates;
@class DownloadUpdate;
@class SearchFolder;
@class RSSFeed;
@class MessageView;
@class Browser;
@class VoleBuildInfoController;

@interface AppController : NSObject <ConnectProtocol,GrowlApplicationBridgeDelegate> {
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSView * searchView;
	IBOutlet NSProgressIndicator * spinner;
	IBOutlet NSTextField * infoString;
	IBOutlet FoldersTree * foldersTree;
	IBOutlet MessageListView * messageList;
	IBOutlet MessageView * textView;
	IBOutlet MessageInfoBar * infoBarView;
	IBOutlet FolderHeaderBar * headerBarView;
	IBOutlet NSWindow * gotoWindow;
	IBOutlet NSWindow * renameWindow;
	IBOutlet NSWindow * compactDatabaseWindow;
	IBOutlet NSTextField * gotoNumber;
	IBOutlet NSTextField * renameField;
	IBOutlet NSImageView * mugshotView;
	IBOutlet NSSplitView * splitView1;
	IBOutlet NSSplitView * splitView2;
	IBOutlet NSSplitView * splitView3; // mugshot splitter
	IBOutlet NSWindow * modUsernameWindow;
	IBOutlet NSWindow * modAddTopicWindow;
	IBOutlet NSWindow * modAddConferenceWindow;
	IBOutlet NSTextField * modUsernameTitle;
	IBOutlet NSTextField * modUsernameText;
	IBOutlet NSTextField * modAddtopicConfname;
	IBOutlet NSTextField * modAddtopicTopicname;
	IBOutlet NSTextField * modAddtopicDescription;
	IBOutlet NSButton * modAddtopicSeedMessage;
	IBOutlet NSButton * modAddtopicHasFiles;
	IBOutlet NSWindow * downloadWindow;
	IBOutlet NSTextField * downloadConference;
	IBOutlet NSTextField * downloadFilename;

	ActivityViewer * activityViewer;
	PreferenceController * preferenceController;
	AuthenticationController * authenticationController;
	ImportController * importController;
	ExportController * exportController;
	CheckForUpdates * checkUpdates;
	DownloadUpdate * downloadUpdate;
	MissingMessagesController * missingMessagesController;
	TasksWindow * tasksWindow;
	Join * joinWindow;
	SearchFolder * searchFolder;
	Browser * browserController;
	Profile * profileWindow;
	RSSFeed * rssFeed;
	VoleBuildInfoController * voleBuildInfoController;

	Database * db;
	BOOL sortedFlag;
	NSInteger currentFolderId;
	NSInteger currentSelectedRow;
	BOOL showThreading;
	BOOL reinstateThreading;
	BOOL showPlainText;
	BOOL showWindowsCP;
	BOOL showMugshots;
	BOOL hideIgnoredMessages;
	NSColor * quoteColour;
	NSColor * priorityColour;
	NSColor * ignoredColour;
	NSArray * currentArrayOfMessages;
	BackTrackArray * backtrackArray;
	BOOL isBacktracking;
	BOOL selectAtEndOfReload;
	NSFont * messageListFont;
	NSFont * boldMessageListFont;
	NSImage * originalIcon;
	NSString * sortColumnIdentifier;
	NSInteger sortDirection;
	NSInteger sortColumnTag;
	NSArray * allColumns;
	ExtDateFormatter * extDateFormatter;
	Connect * connect;
	NSTimer * checkTimer;
	NSInteger lastCountOfPriorityUnread;
	NSInteger progressCount;
	NSString * statusText;
	Credentials * cixCredentials;
	PersonManager * personManager;
	NSMutableDictionary * htmlDict;
	BOOL isOnlineMode;
	BOOL batchConnect;
	BOOL growlAvailable;
	NSInteger requestedMessage;
	NSString * appName;
	NSMutableDictionary *acronymDictionary;
}

// Menu action items
-(IBAction)showVoleBuild:(id)sender;   // Show the VoleBuildInfo window
-(IBAction)showPreferencePanel:(id)sender;
// #warning 64BIT DJE deleted next line - multiple getMessages found
-(IBAction)getMessages:(id)sender;

-(IBAction)getRSSMessages:(id)sender;
-(IBAction)getCixMessages:(id)sender;
-(IBAction)newMessage:(id)sender;
-(IBAction)deleteMessage:(id)sender;
-(IBAction)replyToMessage:(id)sender;
-(IBAction)replyByMail:(id)sender;
-(IBAction)joinConference:(id)sender;
-(IBAction)deleteFolder:(id)sender;
-(IBAction)resignFolder:(id)sender;
-(IBAction)searchUsingToolbarTextField:(id)sender;
-(IBAction)gotoMessage:(id)sender;
-(IBAction)originalMessage:(id)sender;
-(IBAction)originalThread:(id)sender;
-(IBAction)markAllRead:(id)sender;
-(IBAction)markRead:(id)sender;
-(IBAction)markFlagged:(id)sender;
-(IBAction)markThreadFromRootFlagged:(id)sender;
-(IBAction)markThreadFromRootRead:(id)sender;
-(IBAction)markThreadFromRootIgnored:(id)sender;
-(IBAction)markThreadFromRootPriority:(id)sender;
-(IBAction)markPriority:(id)sender;
-(IBAction)markIgnored:(id)sender;
-(IBAction)markThreadRead:(id)sender;
-(IBAction)viewProfile:(id)sender;
-(IBAction)viewNextUnread:(id)sender;
-(IBAction)viewNextPriorityUnread:(id)sender;
-(IBAction)printDocument:(id)sender;
-(IBAction)toggleThreading:(id)sender;
-(IBAction)togglePlainText:(id)sender;
-(IBAction)toggleHideIgnoredMessages:(id)sender;
-(IBAction)toggleActivityViewer:(id)sender;
-(IBAction)toggleWindowsCP:(id)sender;
-(IBAction)showTasksWindow:(id)sender;
-(IBAction)viewOutbox:(id)sender;
-(IBAction)viewDrafts:(id)sender;
-(IBAction)backTrackMessage:(id)sender;
-(IBAction)forwardTrackMessage:(id)sender;
-(IBAction)newSearchFolder:(id)sender;
-(IBAction)newRSSSubscription:(id)sender;
-(IBAction)editRSSSubscription:(id)sender;
-(IBAction)compactDatabase:(id)sender;
-(IBAction)fillMessageGaps:(id)sender;
-(IBAction)toggleOnline:(id)sender;
-(IBAction)goOnline:(id)sender;
-(IBAction)goOffline:(id)sender;
-(IBAction)showBrowser:(id)sender;
-(IBAction)editSearchFolder:(id)sender;
-(IBAction)showAcknowledgements:(id)sender;
-(IBAction)uploadFile:(id)sender;
-(IBAction)downloadFile:(id)sender;
-(IBAction)cancelDownload:(id)sender;
-(IBAction)okDownload:(id)sender;
-(IBAction)copyUrl:(id)sender;
-(IBAction)setCIXBack:(id)sender;

// Moderator menu options
-(IBAction)modAddParticipant:(id)sender;
-(IBAction)modRemParticipant:(id)sender;
-(IBAction)modComod:(id)sender;
-(IBAction)modExmod:(id)sender;
-(IBAction)modReadonly:(id)sender;
-(IBAction)modAddTopic:(id)sender;
-(IBAction)modNewConference:(id)sender;
-(IBAction)cancelModUsername:(id)sender;
-(IBAction)okModUsername:(id)sender;
-(IBAction)cancelModAddtopic:(id)sender;
-(IBAction)okModAddtopic:(id)sender;


// Mugshot updated
-(IBAction)mugshotUpdated:(id)sender;

// Infobar functions
-(void)activityString:(NSString *)string;
-(void)startConnect:(id)sender;
-(void)endConnect:(NSNumber *)resultCode;
-(void)setStatusMessage:(NSString *)statusText;
-(void)updateStatusMessage;
-(void)startProgressIndicator;
-(void)stopProgressIndicator;
-(void)showPriorityUnreadCountOnApplicationIcon;

// Notification response functions
-(void)handleFolderSelection:(NSNotification *)note;
-(void)handleQuoteColourChange:(NSNotification *)note;
-(void)handlePriorityColourChange:(NSNotification *)note;
-(void)handleIgnoredColourChange:(NSNotification *)note;
-(void)handleCheckFrequencyChange:(NSNotification *)note;
-(void)handleFolderUpdate:(NSNotification *)nc;
-(void)handleCIXLink:(NSString *)folderPath messageNumber:(NSInteger)messageNumber;
-(void)handleCIXFileLink:(NSString *)folderPath file:(NSString *)filename;
-(void)handleRSSLink:(NSString *)linkPath;
-(void)handlePersonUpdate:(NSNotification *)note;

// Message selection functions
-(BOOL)scrollToMessage:(NSInteger)number;
-(void)selectFirstUnreadInFolder;
-(void)selectFirstUnreadPriorityInFolder;
-(void)makeRowSelectedAndVisible:(NSInteger)rowIndex;
-(BOOL)viewNextUnreadInCurrentFolder:(NSInteger)currentRow isPriority:(BOOL)priorityFlag;
-(void)selectNextRootMessage;
-(void)selectPreviousRootMessage;
-(void)offerToRetrieveMessage:(NSInteger)messageId fromFolderId:(NSInteger)folderId;
-(void)offerToRetrieveMessage:(NSInteger)messageId fromFolderPath:(NSString *)folderPath;
-(void)retrieveMessage:(NSInteger)messageId fromFolder:(NSString *)folderPath;
-(IBAction)refreshCurrentMessage:(id)sender;


// General functions
-(void)initSortMenu;
-(void)initColumnsMenu;
-(void)updateHTMLDict;
-(NSAttributedString *)formatMessage:(NSString *)messageText usePlainText:(BOOL)usePlainText;
-(void)threadMessages;
-(void)setMainWindowTitle:(NSInteger)folderId;
-(void)refreshFolder:(BOOL)reloadData;
-(BOOL)selectFolderAndMessage:(NSInteger)folderId messageNumber:(NSInteger)messageNumber;
-(void)selectFolderWithFilter:(NSInteger)newFolderId searchFilter:(NSString *)searchFilter;
-(void)updateMessageText;
-(NSArray *)markedMessageRange:(NSUInteger)flags;
-(void)markFlaggedByArray:(NSArray *)messageArray flagged:(BOOL)flagged;
-(void)markIgnoredByArray:(NSArray *)messageArray ignoreFlag:(BOOL)ignoreFlag;
-(void)markPriorityByArray:(NSArray *)messageArray priorityFlag:(BOOL)priorityFlag;
-(void)getMessagesOnTimer:(NSTimer *)aTimer;
-(void)doConfirmedDelete:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
-(void)markCurrentRead;
-(BOOL)validateCommonToolbarAndMenuItems:(SEL)theAction validateFlag:(BOOL *)validateFlag;
-(BOOL)canPostMessage:(NSInteger)folderId messageNumber:(NSInteger)messageNumber;
-(MessageWindow *)messageWindowWithAttributes:(NSInteger)folderId messageNumber:(NSInteger)messageNumber;
-(BOOL)closeAllMessageWindows;
-(void)centerSelectedRow;
-(void)refreshMessageAtRow:(NSInteger)theRow;
-(BOOL)beginConnect:(NSInteger)connectMode;
-(Database *)database;
-(PersonManager *)personManager;
-(NSInteger)currentFolderId;
-(NSArray *)folders;
-(NSString *)appName;
-(BOOL)isConnecting;
-(BOOL)onlineMode;
-(void)readAcronyms;

// Goto sheet functions
-(IBAction)endGotoMessage:(id)sender;
-(IBAction)cancelGotoMessage:(id)sender;

// Rename sheet functions
-(IBAction)endRenameFolder:(id)sender;
-(IBAction)cancelRenameFolder:(id)sender;

// Message list helper functions
-(void)initTableView;
-(void)showColumnsForFolder:(NSInteger)folderId;
-(void)setTableViewFont;
-(void)sortByIdentifier:(NSString *)columnName;
-(void)showSortDirection;
-(void)setSortColumnIdentifier:(NSString *)str;
-(void)doubleClickRow:(id)sender;
-(void)runOKAlertSheet:(NSString *)titleString text:(NSString *)bodyText, ...;
-(void)updateVisibleColumns;
-(void)saveTableSettings;
-(NSInteger)tagFromIdentifier:(NSString *)identifier;
-(void)selectMessageAfterReload;
-(void)markReadByArray:(NSArray *)messageArray readFlag:(BOOL)readFlag;
-(void)displayMugshot:(VMessage *)theRecord;
-(void)resizeMugshotView:(NSInteger)height;

//Required NSToolbar delegate methods
-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;    
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;

// Acronyms
+(NSString *)getAcronymsVersion;
@end
