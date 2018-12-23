//
//  MessageWindow.m
//  Vienna
//
//  Created by Steve on Sun Mar 14 2004.
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

#import "MessageWindow.h"
#import "PreferenceNames.h"
#import "StringExtensions.h"
#import "AppController.h"
#import "Signatures.h"
#import "logit.h"
// Private interfaces
@interface MessageWindow (Private)
	-(void)handleMessageFontChange:(NSNotification *)note;
	-(void)handleSignaturesChange:(NSNotification *)note;
	-(void)setMessageFont;
	-(void)updateTitle;
	-(NSString *)textRestyledForPosting;
	-(void)saveToFolder:(NSInteger)folderId;
	-(void)removeFromFolder:(NSInteger)folderId;
	-(void)insertSignature:(NSString *)signatureTitle;
	-(void)reloadSignaturesList;
@end

@implementation MessageWindow

/* initNewMessage
 * Create a new message window.
 */
-(id)initNewMessage:(Database *)theDb recipient:(NSString *)recipient commentNumber:(NSInteger)commentNumber initialText:(NSString *)initialText
{
    // DJE rearanged to assign self first 30/8/2014
    LOGLINE
    self=[super initWithWindowNibName:@"Comment"];
    if(self){
        db = theDb;
        message = [[VMessage alloc] initWithInfo:MA_MsgID_New];
        [message setFolderId:-1];
        [message setComment:commentNumber];
        [message setSender:recipient];
        if (initialText)
            [message setText: initialText];
    }
    LOGLINE
    return self;
}

/* initMessageFromMessage
 * Creates a message window set up to display the contents of the specified message.
 */
-(id)initMessageFromMessage:(Database *)theDb message:(VMessage *)newMessage
{
    LOGLINE
	db = theDb;
	message = newMessage;
    LOGLINE
	return [super initWithWindowNibName:@"Comment"];
}

/* windowDidLoad
 */
-(void)windowDidLoad
{
    LOGLINE
	// Create the toolbar.
    NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier:@"MA_ReplyToolbar"];

    // Set the appropriate toolbar options. We are the delegate, customization is allowed,
	// changes made by the user are automatically saved and we start in icon+text mode.
    LOGLINE
    [toolbar setDelegate:(id)self];
    LOGLINE
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES]; 
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    LOGLINE
    [messageWindow setToolbar:toolbar];
	[messageWindow setDelegate:(id)self];
    LOGLINE
	// Set the current message text
	NSInteger messageNumber = [message messageId];
	NSInteger folderId = [message folderId];
	if (messageNumber != MA_MsgID_New)
	{
		NSString * messageText = [db messageText:folderId messageId:messageNumber];
		[subjectLine setStringValue:[messageText firstLine]];
		if ([message comment] == 0)
			messageText = [messageText secondAndSubsequentLines];
		[textView setString:messageText];
	}
    LOGLINE
	// Disable subject line if this is a comment
	if ([message comment])
	{
		[subjectLine setEnabled:NO];
		[messageWindow setInitialFirstResponder:textView];
		
//#warning 64BIT: Check formatting arguments
		NSString * commentSubject = [NSString stringWithFormat:@"Comment to message %ld",(long) [message comment]];
		[subjectLine setStringValue:commentSubject];
		if ([message text])
			[textView setString: [message text]];
	}
    LOGLINE
	// Set the recipient line
	[postToLine setStringValue:[message sender]];
	[postToLine setEnabled:NO];
	
	// Set the message font
	[self setMessageFont];

	// Make sure we're notified if the message font changes
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleMessageFontChange:) name:@"MA_Notify_MessageFontChange" object:nil];
    LOGLINE
	// Also wants to be notified if the list of signatures changes
	[nc addObserver:self selector:@selector(handleSignaturesChange:) name:@"MA_Notify_SignaturesChange" object:nil];

	// Init the list of signatures
	currentSignature = nil;
	[self reloadSignaturesList];
    LOGLINE
	// If the text is empty, insert the default signature.
	NSString * defaultSignature = [[NSUserDefaults standardUserDefaults] valueForKey:MAPref_DefaultSignature];
	if (![defaultSignature isEqualToString:@"None"] && messageNumber == MA_MsgID_New)
	{
		// Select default signature for this folder(conference)
		AppController * app = (AppController *)[NSApp delegate];
		Folder * f = [db folderFromID: [app currentFolderId]];
		f = [db folderFromID: [f parentId]];
		NSString * folderName = [f name];

		NSString * signature = defaultSignature;
		if ([[Signatures defaultSignatures] signatureForTitle:folderName] != nil)
			signature = folderName;

		[signaturesList selectItemWithTitle:signature];
		[self insertSignature:signature];
	}
    LOGLINE
	// Set the window title
	[self updateTitle];
    NSLog(@"%@", self);
    NSLog(@"MessageWindow delegate %@",[toolbar delegate]);
    LOGLINE
    CALLSTACK
    // Add this to the window collection to ensure that a reference is
    // maintained.
    [[WindowCollection defaultCollection] add:self];
}

/* handleMessageFontChange
 * Called when the user changes the message or plain text font and/or size in the Preferences
 */
-(void)handleMessageFontChange:(NSNotification *)note
{
    (void)note;
	[self setMessageFont];
}

/* handleSignaturesChange
 * Called when a signature is modified, added or removed from the global signature list.
 * This is a cue for us to refresh the signatures drop-down list.
 */
-(void)handleSignaturesChange:(NSNotification *)note
{
    (void)note;
	[self reloadSignaturesList];
}

/* reloadSignaturesList
 * Refresh the signatures drop down list.
 */
-(void)reloadSignaturesList
{
	NSArray * arrayOfSignatures = [[Signatures defaultSignatures] signatureTitles];
	NSUInteger index;
	
	[signaturesList removeAllItems];
	[signaturesList addItemWithTitle:@"None"];
	for (index = 0; index < [arrayOfSignatures count]; ++index)
		[signaturesList addItemWithTitle:[arrayOfSignatures objectAtIndex:index]];
}

/* signatureSelected
 */
-(IBAction)signatureSelected:(id)sender
{
	[self insertSignature:[sender titleOfSelectedItem]];
}

/* insertSignature
 * This is the routine that actually inserts a signature into the text.
 */
-(void)insertSignature:(NSString *)signatureTitle
{
	NSMutableString * msgText = [NSMutableString stringWithString:[textView string]];
	NSRange textRange = NSMakeRange(0, [msgText length]);
	NSRange selRange = [textView selectedRange];
	NSString * newSignature = @"";
	BOOL doAppend = YES;

	if (![signatureTitle isEqualToString:@"None"])
	{
		newSignature = [NSString stringWithFormat:@"\n\n%@", [[Signatures defaultSignatures] signatureForTitle:signatureTitle]];
	}

	if (currentSignature != nil)
	{
		NSRange range = [msgText rangeOfString:currentSignature options:NSLiteralSearch range:textRange];
		if (range.location != NSNotFound)
		{
			[msgText replaceCharactersInRange:range withString:newSignature];
			[textView setString:msgText];
			doAppend = NO;
		}
	}
	if (doAppend)
	{
		NSAttributedString * attrText = [[NSAttributedString alloc] initWithString:newSignature attributes:[textView typingAttributes]];
		[[textView textStorage] insertAttributedString:attrText atIndex:[msgText length]];
	}

	currentSignature = newSignature;
	
	[textView setSelectedRange:selRange];
}

/* setMessageFont
 */
-(void)setMessageFont
{
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:MAPref_PlainTextFont];
	NSFont * messageFont = [NSUnarchiver unarchiveObjectWithData:fontData];
	[textView setFont:messageFont];
	// static analyser complains
	//[messageFont release];
}

/* message
 * Return a pointer to our message item.
 */
-(VMessage *)message
{
	return message;
}

/* windowShouldClose
 * Since we established ourselves as the delegate for the window, we will
 * get the notifications when the window closes.
 */
-(BOOL)windowShouldClose:(NSNotification *)notification
{
    (void)notification;
    LOGLINE
	[[self window] orderFront:self];
	if ([messageWindow isDocumentEdited])
	{
		NSInteger returnCode;

		returnCode = NSRunAlertPanel(NSLocalizedString(@"Message not saved", nil),
									 NSLocalizedString(@"Message not saved text", nil),
									 NSLocalizedString(@"Save", nil),
									 NSLocalizedString(@"Cancel", nil),
									 NSLocalizedString(@"Don't Save", nil));
		if (returnCode == NSAlertDefaultReturn)
		{
			[self saveAsDraft:self];
			[messageWindow setDocumentEdited:NO];
		}
		else if (returnCode == NSAlertOtherReturn)
			[messageWindow setDocumentEdited:NO];
	}
	if (![messageWindow isDocumentEdited])
	{
//		[self autorelease];
        LOGLINE
		return YES;
	}
    LOGLINE
	return NO;
}

/* When the window is about to close, remove ourselves from the
 * collection.
 */
-(void)windowWillClose:(NSNotification *)notification
{
    [[WindowCollection defaultCollection] remove:self];
}


/* sendMessage
 * Save the message to the Out Basket then close the window
 */
-(void)sendMessage:(id)sender
{
    (void)sender;
    LOGLINE
	[self removeFromFolder:MA_Draft_NodeID];
    LOGLINE
	[self saveToFolder:MA_Outbox_NodeID];
	[messageWindow performClose:self];
    // Warning - cannot refer to LOGLINE here as performClose will release the object
    // we are supposedly referring to.
}

/* saveAsDraft
 * Save the message to the Draft folder but do not
 * close the window afterwards.
 */
-(void)saveAsDraft:(id)sender
{
    (void)sender;
	[self removeFromFolder:MA_Outbox_NodeID];
	[self saveToFolder:MA_Draft_NodeID];
	[messageWindow setDocumentEdited:NO];
}

#define SINGLE_OPEN_QUOTE	8216
#define SINGLE_CLOSE_QUOTE	8217
#define DOUBLE_OPEN_QUOTE	8220
#define DOUBLE_CLOSE_QUOTE	8221

/* textRestyledForPosting
 * Get the text from the control and convert smart quote characters into their 7-bit ASCII
 * equivalents.
 */
-(NSString *)textRestyledForPosting
{
    LOGLINE
	NSMutableString * msgText = [NSMutableString stringWithString:[textView string]];
	[msgText replaceString:[NSString stringWithFormat:@"%C", (unichar)SINGLE_OPEN_QUOTE] withString:@"'"];
	[msgText replaceString:[NSString stringWithFormat:@"%C", (unichar)SINGLE_CLOSE_QUOTE] withString:@"'"];
	[msgText replaceString:[NSString stringWithFormat:@"%C", (unichar)DOUBLE_OPEN_QUOTE] withString:@"\""];
	[msgText replaceString:[NSString stringWithFormat:@"%C", (unichar)DOUBLE_CLOSE_QUOTE] withString:@"\""];
    LOGLINE
	return msgText;
}

/* saveToFolder
 * Saves the current message to the specified folder
 */
-(void)saveToFolder:(NSInteger)folderId
{
	NSInteger messageNumber;
    LOGLINE
	// Set the text into the message
	if ([message comment] == 0)
		[message setText:[NSString stringWithFormat:@"%@\n%@", [subjectLine stringValue], [self textRestyledForPosting]]];
	else
		[message setText:[self textRestyledForPosting]];
    LOGLINE
	// We need to know the message number so removing it later
	// actually works.
	[message markRead:YES];
	[message setFolderId:folderId];
	messageNumber = [db addMessage:folderId message:message wasNew:nil];
	if (messageNumber != MA_MsgID_New)
		[message setNumber:messageNumber];
    LOGLINE
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithLong:(long)folderId]];

	[messageWindow setDocumentEdited:NO];
}

/* removeFromFolder
 * Removes the current message from the specified folder.
 */
-(void)removeFromFolder:(NSInteger)folderId
{
    LOGLINE
	if ([message folderId] == folderId)
	{
		[db deleteMessage:folderId messageNumber:[message messageId]];
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc postNotificationName:@"MA_Notify_FoldersUpdated" object:[NSNumber numberWithLong:(long)folderId]];
		[message setNumber:MA_MsgID_New];
	}
}

/* textDidChange
 * Called when the user makes any modifications to the text
 */
-(void)textDidChange:(NSNotification *)notification
{
    (void)notification;
	[messageWindow setDocumentEdited:YES];
}

/* controlTextDidChange
 * Called when the user makes any modifications to the text
 */
-(void)controlTextDidChange:(NSNotification *)notification
{
    (void)notification;
	[messageWindow setDocumentEdited:YES];
	[self updateTitle];
}

/* printDocument
 * Print the current message in the message window.
 */
-(IBAction)printDocument:(id)sender
{
    (void)sender;
	NSPrintInfo * printInfo = [NSPrintInfo sharedPrintInfo];
	NSPrintOperation * printOp;
	
	printOp = [NSPrintOperation printOperationWithView:textView printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperation];
}

/* updateTitle
 * Update the window title from the subject field
 */
-(void)updateTitle
{
	NSString * title = [subjectLine stringValue];
	
	if ([title isEqualToString:@""])
		title = NSLocalizedString(@"(No subject)", nil);
	[messageWindow setTitle:title];
}

/* validateToolbarItem
 * Check [theItem identifier] and return YES if the item is enabled, NO otherwise.
 */
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    (void)toolbarItem;
	return YES;
}

/* itemForItemIdentifier
 * This method is required of NSToolbar delegates.  It takes an identifier, and returns the matching NSToolbarItem.
 * It also takes a parameter telling whether this toolbar item is going into an actual toolbar, or whether it's
 * going to be displayed in a customization palette.
 */
-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    LOGLINE
    (void)toolbar; (void)flag;
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
	if ([itemIdentifier isEqualToString:@"SendMessage"])
	{
        [item setLabel:NSLocalizedString(@"Send", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"send.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(sendMessage:)];
	}
	else if ([itemIdentifier isEqualToString:@"SaveAsDraft"])
	{
        [item setLabel:NSLocalizedString(@"Save As Draft", nil)];
        [item setPaletteLabel:[item label]];
        [item setImage:[NSImage imageNamed:@"saveAsDraft.tiff"]];
        [item setTarget:self];
        [item setAction:@selector(saveAsDraft:)];
	}
    LOGLINE
	return item;
}

/* toolbarDefaultItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for the default
 * set of toolbar items.  It can also be called by the customization palette to display the default toolbar.
 */
-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
    (void)toolbar;
    LOGLINE
    return [NSArray arrayWithObjects:@"SendMessage",
									 NSToolbarPrintItemIdentifier,
									 @"SaveAsDraft",
									 nil];
}

/* toolbarAllowedItemIdentifiers
 * This method is required of NSToolbar delegates.  It returns an array holding identifiers for all allowed
 * toolbar items in this toolbar.  Any not listed here will not be available in the customization palette.
 */
-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    (void)toolbar;
    LOGLINE
      return [NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
									 NSToolbarSpaceItemIdentifier,
									 NSToolbarFlexibleSpaceItemIdentifier,
									 NSToolbarPrintItemIdentifier,
									 @"SendMessage",
									 @"SaveAsDraft",
									 nil];
}

/* dealloc
 * Clean up and release resources.
 */
@end
