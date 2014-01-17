//
//  PreferenceController.m
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

#import "PreferenceController.h"
#import "PreferenceNames.h"
#import "Signatures.h"
#import "ViennaApp.h"
#import "AppController.h"
#import "PersonManager.h"

/* Actual definitions of the preference tags. Keep this in
 * sync with the PreferenceNames.h file.
 */
NSString * MAPref_Username = @"Username";
NSString * MAPref_DrawerState = @"DrawerState";
NSString * MAPref_MessageListFont = @"MessageListFont";
NSString * MAPref_FolderFont = @"FolderFont";
NSString * MAPref_MessageFont = @"MessageFont";
NSString * MAPref_PlainTextFont = @"PlainTextFont";
NSString * MAPref_ShowThreading = @"ShowThreading";
NSString * MAPref_CachedFolderID = @"CachedFolderID";
NSString * MAPref_QuoteColour = @"QuoteColour";
NSString * MAPref_PriorityColour = @"PriorityColour";
NSString * MAPref_IgnoredColour = @"IgnoredColour";
NSString * MAPref_DefaultDatabase = @"DefaultDatabase";
NSString * MAPref_ShowPlainText = @"ShowPlainText";
NSString * MAPref_ShowWindowsCP = @"ShowWindowsCP";
NSString * MAPref_SortDirection = @"SortDirection";
NSString * MAPref_HideIgnoredMessages = @"HideIgnoredMessages";
NSString * MAPref_SortColumn = @"SortColumn";
NSString * MAPref_CheckFrequency = @"CheckFrequencyInSeconds";
NSString * MAPref_MessageColumns = @"MessageColumns";
NSString * MAPref_Signatures = @"Signatures";
NSString * MAPref_DefaultSignature = @"DefaultSignature";
NSString * MAPref_AutoCollapseFolders = @"AutoCollapseFolders";
NSString * MAPref_RecentOnJoin = @"RecentOnJoin";
NSString * MAPref_OnlineMode = @"OnlineModeWhenStarting";
NSString * MAPref_Recovery = @"RecoverScratchpad";
NSString * MAPref_MugshotsEnabled = @"MugshotsEnabled";
NSString * MAPref_MugshotsFolder = @"MugshotsFolder";
NSString * MAPref_MugshotsSize = @"MugshotsSize";
NSString * MAPref_ConnectionType = @"ConnectionType";
NSString * MAPref_CheckForUpdatesOnStartup = @"CheckForUpdatesOnStartup";
NSString * MAPref_SaveSpotlightMetadata = @"SaveSpotlightMetadata";
NSString * MAPref_LogVersions = @"LogVersions";
NSString * MAPref_DownloadFolder = @"DownloadFolder";
NSString * MAPref_LastUploadFolder = @"LastUploadFolder";
NSString * MAPref_DetectMugshotDownload = @"DetectMugshotDownload";
NSString * MAPref_LibraryFolder = @"LibraryFolder";


// List of available font sizes. I picked the ones that matched
// Mail but you easily could add or remove from the list as needed.
NSInteger availableFontSizes[] = { 6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48, 64 };
// #warning 64BIT: Inspect use of sizeof
// #warning 64BIT: Inspect use of sizeof
#define countOfAvailableFontSizes  (sizeof(availableFontSizes)/sizeof(availableFontSizes[0]))

// Private functions
@interface PreferenceController (Private)
	-(NSString *)stringFromPascalString:(const unsigned char *)pascalString;
	-(void)setSavedUsername:(NSString *)newUsername;
	-(void)setSavedPassword:(NSString *)newPassword;
	-(void)selectUserDefaultFont:(NSString *)preferenceName control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl;
	-(void)reloadSignatures;
	-(void)removeSignature:(NSString *)title;
	-(void)setDefaultLinksHandler:(NSString *)newHandler creatorCode:(OSType)creatorCode;
	-(void)controlTextDidEndEditing:(NSNotification *)notification;
@end

@implementation PreferenceController

/* init
 * Initialize the class
 */
-(id)initWithCredentials:(Credentials *)theCredentials
{
	credentials = theCredentials;
	internetConfigHandler = nil;
	currentPerson = nil;
	return [super initWithWindowNibName:@"Preferences"];
}

/* windowDidLoad
 * First time window load initialisation. Since preferences could potentially be
 * changed while the Preferences window is closed, initialise the controls in the
 * initializePreferences function instead.
 */
-(void)windowDidLoad
{
	[self initializePreferences];

	// Set up to be notified if preferences change outside this window
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(handleReloadPreferences:) name:@"MA_Notify_PreferencesUpdated" object:nil];

	[nc addObserver:self selector:@selector(controlTextDidEndEditing:) name:NSTextDidEndEditingNotification object:profileResume];

	// Also get notified when the signature title changes in the editor.
	[nc addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:signatureTitle];
}

/* handleReloadPreferences
 * This gets called when MA_Notify_PreferencesUpdated is broadcast. Just update the controls values.
 */
-(void)handleReloadPreferences:(NSNotification *)nc
{
	[self initializePreferences];
}

/* stringFromPascalString
 * Given a pointer to a Pascal string where the format is a 1-byte length followed by
 * the actual characters, this function returns an NSString representing that string.
 */
-(NSString *)stringFromPascalString:(const unsigned char *)pascalString
{
	NSInteger pStringLength = (NSInteger)(unsigned char)*(pascalString);
	// deprecated API was here DJE
//	return [NSString stringWithCString:(char *)pascalString + 1 length:pStringLength];
	// replcement here
	return [[[NSString alloc]initWithBytes:(char *)pascalString + 1 
									length:pStringLength
								  encoding:NSWindowsCP1252StringEncoding]
			autorelease];

}

/* initializePreferences
 * Set the preference settings from the user defaults.
 */
-(void)initializePreferences
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// Set the account information
	[self setSavedUsername:[credentials username]];
	[self setSavedPassword:[credentials password]];
	[username setStringValue:savedUsername];
	[password setStringValue:savedPassword];

	// Set the recent on join count
	// #warning 64BIT dje integerValue -> intValue
	[recentCount setIntValue:[defaults integerForKey:MAPref_RecentOnJoin]];
	
	// Set the quote colour info
	[quoteColour setColor:[NSApp quoteColour]];

	// Set the priority colour info
	[priorityColour setColor:[NSApp priorityColour]];

	// Set the ignored colour info
	[ignoredColour setColor:[NSApp ignoredColour]];
	
	// Populate the drop downs with the font names and sizes
	[self selectUserDefaultFont:MAPref_MessageFont control:messageFont sizeControl:messageFontSize];
	[self selectUserDefaultFont:MAPref_MessageListFont control:messageListFont sizeControl:messageListFontSize];
	[self selectUserDefaultFont:MAPref_PlainTextFont control:plainTextFont sizeControl:plainTextFontSize];
	[self selectUserDefaultFont:MAPref_FolderFont control:folderFont sizeControl:folderFontSize];
	
	// Set the check frequency
	[checkFrequency selectItemAtIndex:[checkFrequency indexOfItemWithTag:[NSApp checkFrequency]]];

	// Handle double-clicks in the list
	[signaturesList setDoubleAction:@selector(editSignature:)];
	[signaturesList setTarget:self];

	// Set the state for auto-collapsing folders
	[autoCollapseFolders setState:[defaults boolForKey:MAPref_AutoCollapseFolders] ? NSOnState : NSOffState];

	// Set check for updates when starting
	[checkForUpdates setState:[defaults boolForKey:MAPref_CheckForUpdatesOnStartup] ? NSOnState : NSOffState];
	
	// Set online option
	[onlineWhenStarting setState:[defaults boolForKey:MAPref_OnlineMode] ? NSOnState : NSOffState];
	
	// Set Connection type (ssh/telnet)
	[connectionType selectItemAtIndex:[defaults integerForKey:MAPref_ConnectionType]];
		
	// Number of log versions to keep
	// #warning 64BIT dje integerValue -> intValue
	[logVersions setIntValue:[defaults integerForKey:MAPref_LogVersions]];
	
	// Mugshots prefs
	[enableMugshots setState:[defaults boolForKey:MAPref_MugshotsEnabled] ? NSOnState : NSOffState];
	mugshotsFolderName = [defaults stringForKey:MAPref_MugshotsFolder];
	[mugshotFolder setStringValue: mugshotsFolderName];
	
	// Downloading prefs
	[downloadFolder setStringValue: [defaults stringForKey: MAPref_DownloadFolder]];
	[downloadMugshots setState:[defaults boolForKey:MAPref_DetectMugshotDownload] ? NSOnState : NSOffState];	
	
	// Spotlight metadata saving
	[saveSpotlightMetadata setState:[defaults boolForKey:MAPref_SaveSpotlightMetadata] ? NSOnState : NSOffState];
	
	// Load the signatures list
	arrayOfSignatures = [[[Signatures defaultSignatures] signatureTitles] retain];
	[deleteSignatureButton setEnabled:NO];
	[editSignatureButton setEnabled:NO];
	signatureBeingEdited = nil;
	
	// Get some info about us
	NSBundle * appBundle = [NSBundle mainBundle];
	NSString * appName = [[NSApp delegate] appName];
	NSString * fullAppName = @"";
	OSType appCode = 0L;
	if (appBundle != nil)
	{
		NSDictionary * fileAttributes = [appBundle infoDictionary];
		NSString * creatorString = [NSString stringWithFormat:@"'%@'", [fileAttributes objectForKey:@"CFBundleSignature"]];
		appCode = NSHFSTypeCodeFromFileType(creatorString);
		fullAppName = [NSString stringWithFormat:@"%@ (%@)", appName, [fileAttributes objectForKey:@"CFBundleShortVersionString"]];
	}
	
	// Populate links handler combo
	if (!internetConfigHandler)
	{
		if (ICStart(&internetConfigHandler, appCode) != noErr)
			internetConfigHandler = nil;
	}
	if (internetConfigHandler)
	{
		if (ICBegin(internetConfigHandler, icReadWritePerm) == noErr)
		{
			NSString * defaultHandler = nil;
			BOOL onTheList = NO;
// #warning 64BIT: Inspect use of long -its OK (DJE)
			long size;
			ICAttr attr;

			// Get the default handler for the CIX URL. If there's no existing default
			// handler for some reason, we register ourselves.
			ICAppSpec spec;
			if (ICGetPref(internetConfigHandler, kICHelper "cix", &attr, &spec, &size) == noErr)
				defaultHandler = [self stringFromPascalString:spec.name];
			else
			{
				defaultHandler = appName;
				[self setDefaultLinksHandler:appName creatorCode:appCode];
			}

			// Fill the list with all registered helpers for the CIX URL.
			ICAppSpecList * specList;
			size = 256;
			if ((specList = (ICAppSpecList *)malloc(size)) != nil)
			{
				[linksHandler removeAllItems];
				if (ICGetPref(internetConfigHandler, kICHelperList "cix", &attr, specList, &size) == noErr)
				{
					NSInteger c;
					for (c = 0; c < specList->numberOfItems; ++c)
					{
						ICAppSpec * spec = &specList->appSpecs[c];
						NSString * handler = [self stringFromPascalString:spec->name];
						NSMenuItem * item;

						if ([appName isEqualToString:handler])
						{
							[linksHandler addItemWithTitle:fullAppName];
							item = (NSMenuItem *)[linksHandler itemWithTitle:fullAppName];
							[item setTag:appCode];
							onTheList = YES;
						}
						else
						{
							[linksHandler addItemWithTitle:handler];
							item = (NSMenuItem *)[linksHandler itemWithTitle:handler];
							[item setTag:spec->fCreator];
						}
						if ([defaultHandler isEqualToString:handler])
							[linksHandler selectItem:item];
					}
				}
				free(specList);
			}
			
			// Were we on the list? If not, add ourselves
			if (!onTheList)
			{
				[linksHandler addItemWithTitle:fullAppName];
				NSMenuItem * item = [linksHandler itemWithTitle:fullAppName];
				[item setTag:appCode];
			}

			// Done
			ICEnd(internetConfigHandler);
		}
	}
	
	// Load the list of default signatures and select the actual default
	[defaultSignature addItemsWithTitles:arrayOfSignatures];
	
	// Display your profile details, if any
	PersonManager * personManager = [[NSApp delegate] personManager];
	[currentPerson release];
	currentPerson = [personManager personFromPerson:[credentials username]];
	if (currentPerson != nil)
	{	[ currentPerson retain ];  // DJE added 2012-09-21
		if ([currentPerson name] != nil)
			[profileFullName setStringValue:[currentPerson name]];
		if ([currentPerson emailAddress] != nil)
			[profileEmailAddress setStringValue:[currentPerson emailAddress]];
		if ([currentPerson parsedInfo] != nil)
			[profileResume setStringValue:[currentPerson parsedInfo]];
	}
}

/* changeAutoCollapseFolders
 * Respond when the user changes the state of auto-collapsing folders.
 */
-(IBAction)changeAutoCollapseFolders:(id)sender
{
	NSNumber * boolFlag = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_AutoCollapseFolders];

	// Post notification so that folders list knows when autocollapse has changed
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"MA_Notify_AutoCollapseChange" object:nil];
}

/* changeOnlineWhenStarting
 * Set whether Vienna starts in online mode.
 */
-(IBAction)changeOnlineWhenStarting:(id)sender
{
	NSNumber * boolFlag = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_OnlineMode];
}

/* changeCheckForUpdates
 * Set whether Vienna checks for updates when it starts.
 */
-(IBAction)changeCheckForUpdates:(id)sender
{
	NSNumber * boolFlag = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_CheckForUpdatesOnStartup];
}

/* selectDefaultLinksHandler
 * The user picked something from the list of handlers.
 */
-(IBAction)selectDefaultLinksHandler:(id)sender
{
	NSMenuItem * selectedItem = [linksHandler selectedItem];
	if (selectedItem != nil)
	{
		NSString * name = [selectedItem title];
		OSType creator = [selectedItem tag];
		[self setDefaultLinksHandler:name creatorCode:creator];
	}
}

/* selectConnectionType
 */
-(IBAction)selectConnectionType:(id)sender
{
	NSMenuItem * selectedItem = [connectionType selectedItem];
	if (selectedItem != nil)
	{
		NSInteger conType = [selectedItem tag];
		[[NSUserDefaults standardUserDefaults] setInteger:conType forKey:MAPref_ConnectionType];
	}
}

/* Number of log versions changed
*/
-(IBAction)changeLogVersions:(id)sender
{
	// #warning 64BIT dje integerValue -> intValue
	NSInteger versions = [logVersions intValue];
	[[NSUserDefaults standardUserDefaults] setInteger:versions forKey:MAPref_LogVersions];
}

/* setDefaultLinksHandler
 * Set the default handler for cix links via Internet Config.
 */
-(void)setDefaultLinksHandler:(NSString *)newHandler creatorCode:(OSType)creatorCode
{
	ICAppSpec spec;
	NSInteger attr = 0;

	spec.fCreator = creatorCode;
	// Make a Pascal string.
	// deprecated API was here DJE
	memcpy(&spec.name[1], [newHandler cStringUsingEncoding:NSWindowsCP1252StringEncoding], [newHandler length]);
	spec.name[0] = [newHandler length];
// #warning 64BIT: Inspect use of sizeof
	ICSetPref(internetConfigHandler, kICHelper "cix", attr, &spec, sizeof(spec));
}

/* numberOfRowsInTableView [datasource]
 * Datasource for the table view. Return the total number of signatures in the
 * arrayOfSignatures array.
 */
-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [arrayOfSignatures count];
}

/* objectValueForTableColumn [datasource]
 * Called by the table view to obtain the object at the specified column and row. This is
 * called often so it needs to be fast.
 */
-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [arrayOfSignatures objectAtIndex:rowIndex];
}

/* tableViewSelectionDidChange [delegate]
 * Handle the selection changing in the table view.
 */
-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger row = [signaturesList selectedRow];
	[deleteSignatureButton setEnabled:(row >= 0)];
	[editSignatureButton setEnabled:(row >= 0)];
}

/* selectUserDefaultFont
 */
-(void)selectUserDefaultFont:(NSString *)preferenceName control:(NSPopUpButton *)control sizeControl:(NSComboBox *)sizeControl
{
	NSFontManager * fontManager = [NSFontManager sharedFontManager];
	NSArray * availableFonts = [[fontManager availableFonts] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSData * fontData = [[NSUserDefaults standardUserDefaults] objectForKey:preferenceName];
	NSFont * font = [NSUnarchiver unarchiveObjectWithData:fontData];

	[control removeAllItems];
	[control addItemsWithTitles:availableFonts];
	[control selectItemWithTitle:[font fontName]];

	NSUInteger i;
	for (i = 0; i < countOfAvailableFontSizes; ++i)
		[sizeControl addItemWithObjectValue:[NSNumber numberWithLong:(long)availableFontSizes[i]]];
	[sizeControl setDoubleValue:[font pointSize]];
}

/* changeQuoteColour
 * Handles changes in the colour well for the quote colour setting
 */
-(IBAction)changeQuoteColour:(id)sender
{
	[NSApp internalSetQuoteColour:[quoteColour color]];
}

/* changePriorityColour
 * Handles changes in the colour well for the priority colour setting
 */
-(IBAction)changePriorityColour:(id)sender
{
	[NSApp internalSetPriorityColour:[priorityColour color]];
}

/* changeIgnoredColour
 * Handles changes in the colour well for the ignored colour setting
 */
-(IBAction)changeIgnoredColour:(id)sender
{
	[NSApp internalSetIgnoredColour:[ignoredColour color]];
}

/* changeFont
 * Handle changes to any of the font selection options.
 */
-(IBAction)changeFont:(id)sender
{
	NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
	if (sender == messageListFont || sender == messageListFontSize)
	{
		NSString * newFontName = [messageListFont titleOfSelectedItem];
		CGFloat newFontSize = [messageListFontSize doubleValue];

		NSFont * msgListFont = [NSFont fontWithName:newFontName size:newFontSize];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:msgListFont] forKey:MAPref_MessageListFont];
		[nc postNotificationName:@"MA_Notify_MessageListFontChange" object:msgListFont];
	}
	else if (sender == messageFont || sender == messageFontSize)
	{
		NSString * newFontName = [messageFont titleOfSelectedItem];
		CGFloat newFontSize = [messageFontSize doubleValue];
		
		NSFont * msgFont = [NSFont fontWithName:newFontName size:newFontSize];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:msgFont] forKey:MAPref_MessageFont];
		[nc postNotificationName:@"MA_Notify_MessageFontChange" object:msgFont];
	}
	else if (sender == plainTextFont || sender == plainTextFontSize)
	{
		NSString * newFontName = [plainTextFont titleOfSelectedItem];
		CGFloat newFontSize = [plainTextFontSize doubleValue];
	
		NSFont * msgFont = [NSFont fontWithName:newFontName size:newFontSize];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:msgFont] forKey:MAPref_PlainTextFont];
		[nc postNotificationName:@"MA_Notify_MessageFontChange" object:msgFont];
	}
	else if (sender == folderFont || sender == folderFontSize)
	{
		NSString * newFontName = [folderFont titleOfSelectedItem];
		CGFloat newFontSize = [folderFontSize doubleValue];
		
		NSFont * fldrFont = [NSFont fontWithName:newFontName size:newFontSize];
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:fldrFont] forKey:MAPref_FolderFont];
		[nc postNotificationName:@"MA_Notify_FolderFontChange" object:fldrFont];
	}
}

/* changeCheckFrequency
 * The user changed the connect frequency drop down so save the new value and then
 * tell the main app that it changed.
 */
-(IBAction)changeCheckFrequency:(id)sender
{
	NSInteger newFrequency = [[checkFrequency selectedItem] tag];
	[NSApp internalSetCheckFrequency:newFrequency];
}

/* changeRecentCount
 * Update the number of messages to retrieve by default when the user joins a new topic.
 */
-(IBAction)changeRecentCount:(id)sender
{
	// #warning 64BIT dje integerValue -> intValue
	NSInteger newCount = [recentCount intValue];
	[[NSUserDefaults standardUserDefaults] setInteger:newCount forKey:MAPref_RecentOnJoin];
}

/* setSavedUsername
 * Saves the new user name.
 */
-(void)setSavedUsername:(NSString *)newUsername
{
	[newUsername retain];
	[savedUsername release];
	savedUsername = newUsername;
}

/* setSavedPassword
 * Saves the new password.
 */
-(void)setSavedPassword:(NSString *)newPassword
{
	[newPassword retain];
	[savedPassword release];
	savedPassword = newPassword;
}

/* changeUsername
 * Respond to the user changing the user name field. Save the new
 * user name then notify interested parties.
 */
-(IBAction)changeUsername:(id)sender
{
	NSString * newUsername = [sender stringValue];
	if (![newUsername isEqualToString:savedUsername])
	{
		[credentials setUsername:newUsername];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_UsernameChange" object:nil];
		[self setSavedUsername:newUsername];
	}
}

/* changePassword
 * Respond to the user changing the password. Save the new password in the
 * keychain.
 */
-(IBAction)changePassword:(id)sender
{
	NSString * newPassword = [sender stringValue];
	if (![newPassword isEqualToString:savedPassword])
	{
		[credentials setPassword:newPassword];
		[self setSavedPassword:newPassword];
	}
}

/* newSignature
 * Called when the user clicks the New Signature button. Start the UI to create
 * a new signature.
 */
-(IBAction)newSignature:(id)sender
{
	[signatureBeingEdited release];
	signatureBeingEdited = nil;

	[signatureText setString:@""];
	[signatureTitle setStringValue:@""];
	[saveSignatureButton setEnabled:NO];
	[NSApp beginSheet:signatureEditor
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(signatureSheetEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/* editSignature
 * Called when the user either clicks the Edit button or double-clicks an existing
 * signature. Start the UI to edit the signature.
 */
-(IBAction)editSignature:(id)sender
{
	NSAssert([signaturesList selectedRow] >= 0, @"Somehow editSignature got called without a selected row");
	
	NSString * title = [arrayOfSignatures objectAtIndex:[signaturesList selectedRow]];
	NSString * text = [[Signatures defaultSignatures] signatureForTitle:title];

	[signatureBeingEdited release];
	signatureBeingEdited = [title retain];

	[signatureText setString:text];
	[signatureTitle setStringValue:title];
	[saveSignatureButton setEnabled:YES];
	[NSApp beginSheet:signatureEditor
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(signatureSheetEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/* deleteSignature
 * Called when the user clicks the Delete signature button. Drop the selected signature
 * from the list and also drop it from the available default signatures. If this signature was
 * originally our default signature, the new default signature should become "None".
 */
-(IBAction)deleteSignature:(id)sender
{
	NSString * titleOfSignatureToDelete = [arrayOfSignatures objectAtIndex:[signaturesList selectedRow]];

	// Call a common function to both remove the signature and fix up the default
	// signatures if needed.
	[self removeSignature:titleOfSignatureToDelete];
	[self reloadSignatures];

	// Give all open message windows a chance to refresh their signature drop down list.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_SignaturesChange" object:nil];
}

/* saveSignature
 * Called when the user clicks Save 
 */
-(IBAction)saveSignature:(id)sender
{
	[NSApp endSheet:signatureEditor returnCode:NSOKButton];
}

/* cancelSignature
 * Just close the signature editor window.
 */
-(IBAction)cancelSignature:(id)sender
{
	[NSApp endSheet:signatureEditor returnCode:NSCancelButton];
}

/* signatureSheetEnd
 * Called when the Edit Signature sheet is dismissed. The returnCode is NSOKButton if the Save
 * button was pressed, or NSCancelButton otherwise.
 */
-(void)signatureSheetEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString * title = [signatureTitle stringValue];
		NSString * text = [NSString stringWithString:[signatureText string]];
		
		// If we changed the signature title, remove the old one.
		if (signatureBeingEdited)
		{
			if (![signatureBeingEdited isEqualToString:title])
				[self removeSignature:signatureBeingEdited];
		}
		
		[[Signatures defaultSignatures] addSignature:title withText:text];
		[self reloadSignatures];
		
		// Add this to the default signature collection
		[defaultSignature addItemWithTitle:title];

		// Select the newly added signature for convenience.
		NSInteger row = [arrayOfSignatures indexOfObject:title];
		[signaturesList selectRow:row byExtendingSelection:NO];
		
		// Give all open message windows a chance to refresh their signature drop down list.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_SignaturesChange" object:title];
	}
	[signatureEditor orderOut:self];
	[[self window] makeKeyAndOrderFront:self];
}

/* removeSignature
 * Remove the specified signature from the list AND remove it from the list of default
 * signatures.
 */
-(void)removeSignature:(NSString *)title
{
	NSString * currentDefault = [defaultSignature titleOfSelectedItem];
	if ([currentDefault isEqualToString:title])
	{
		[defaultSignature selectItemWithTitle:@"None"];
		[[NSUserDefaults standardUserDefaults] setObject:@"None" forKey:MAPref_DefaultSignature];
	}
	[defaultSignature removeItemWithTitle:title];

	// Now actually remove the signature.
	[[Signatures defaultSignatures] removeSignature:title];
}

/* selectDefaultSignature
 * The user selected a different default signature so save it.
 */
-(IBAction)selectDefaultSignature:(id)sender
{
	NSString * newDefaultSignature = [sender titleOfSelectedItem];
	[[NSUserDefaults standardUserDefaults] setObject:newDefaultSignature forKey:MAPref_DefaultSignature];
}

/* reloadSignatures
 * Re-initialise the arrayOfSignatures.
 */
-(void)reloadSignatures
{
	[arrayOfSignatures release];
	arrayOfSignatures = [[[Signatures defaultSignatures] signatureTitles] retain];
	[signaturesList reloadData];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the title field is changed.
 * We disable the Save button if the title field is empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
	NSString * title = [signatureTitle stringValue];
	[saveSignatureButton setEnabled:![title isEqualToString:@""]];
}

-(IBAction)changeSpotlight:(id)sender
{
	NSNumber * boolFlag = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_SaveSpotlightMetadata];
}


/* changeMugshots
 * Mugshots are enabled/disabled
 */
-(void)changeMugshots:(id)sender
{
	NSNumber * boolFlag = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_MugshotsEnabled];
	// #warning 64BIT dje integerValue -> intValue
	[mugshotFolder setEnabled: [boolFlag intValue]];
	// #warning 64BIT dje integerValue -> intValue
	[mugshotFolderBrowse setEnabled: [boolFlag intValue]];

	// Notify of the change
	// #warning 64BIT dje integerValue -> intValue
	if ([boolFlag intValue] == 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MugshotsFolderChanged" object:nil];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MugshotsFolderChanged" object:mugshotsFolderName];
}

/* updateMugshotFolder
 * Mugshots folder was changed either by browser or typing
 */
-(void)updateMugshotFolder:(NSString *)newFolder
{	
	[mugshotFolder setStringValue: newFolder];
	[newFolder retain];
	[mugshotsFolderName release];
	mugshotsFolderName = newFolder;
	[[NSUserDefaults standardUserDefaults] setObject:mugshotsFolderName forKey:MAPref_MugshotsFolder];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MA_Notify_MugshotsFolderChanged" object:mugshotsFolderName];	
}

/* browsePanelDidEnd
 * Called when the browser panel is dismissed. If the user selected OK, preserve the new
 * mugshot folder path.
 */
-(void)browsePanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)context
{
	if (returnCode == NSOKButton)
	{
		NSString *newFolder = [[panel filename] stringByAbbreviatingWithTildeInPath];
		[self updateMugshotFolder: newFolder];
	}
}

/* browseMugshotFolder
 * Handle the Browse button to show the UI for the user to choose a new
 * mugshot folder path.
 */
-(IBAction)browseMugshotFolder:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel beginSheetForDirectory: mugshotsFolderName
							 file: nil
							types: nil
				   modalForWindow: [self window]
					modalDelegate: self
				   didEndSelector: @selector(browsePanelDidEnd: returnCode: contextInfo: )
					  contextInfo: nil];
	
	[panel setCanChooseDirectories: YES];
	[panel setCanChooseFiles: NO];
}

/* defaultMugshotFolder
 * Set mugshots folder to it's default value.
 */
-(IBAction)defaultMugshotFolder:(id)sender
{
	[self updateMugshotFolder: @"~/Library/Vienna/Mugshots"];
}

/* changeMugshotFolder
 * Mugshot folder was changed.
 */
-(IBAction)changeMugshotFolder:(id)sender
{
	NSString * newFolder = [sender stringValue];
	[self updateMugshotFolder: newFolder];
}

-(IBAction)changeMugshotsDownload:(id)sender
{
	NSNumber * boolFlag = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[NSUserDefaults standardUserDefaults] setObject:boolFlag forKey:MAPref_DetectMugshotDownload];
}

-(IBAction)changeDownloadFolder:(id)sender
{
	NSString * newFolder = [sender stringValue];
	[[NSUserDefaults standardUserDefaults] setObject:newFolder forKey:MAPref_DownloadFolder];
}

-(void)downloadPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)context
{
	if (returnCode == NSOKButton)
	{
		NSString *newFolder = [[panel filename] stringByAbbreviatingWithTildeInPath];
		[[NSUserDefaults standardUserDefaults] setObject:newFolder forKey:MAPref_DownloadFolder];
		[downloadFolder setStringValue: newFolder];
	}
}

-(IBAction)browseDownloadFolder:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSString * defaultFolder = [[NSUserDefaults standardUserDefaults] stringForKey: MAPref_DownloadFolder];

	if (defaultFolder == nil)
		defaultFolder = @
			"~/";
	
	[panel beginSheetForDirectory: defaultFolder
							 file: nil
							types: nil
				   modalForWindow: [self window]
					modalDelegate: self
				   didEndSelector: @selector(downloadPanelDidEnd: returnCode: contextInfo: )
					  contextInfo: nil];
	
	[panel setCanChooseDirectories: YES];
	[panel setCanChooseFiles: NO];
}

/* changeProfileFullName
 * The user changed their profile full name.
 */
-(IBAction)changeProfileFullName:(id)sender
{
	PersonManager * personManager = [[NSApp delegate] personManager];
	[currentPerson setName:[sender stringValue]];
	[personManager updatePerson:currentPerson];
}

/* changeProfileEmailAddress
 * The user changed their profile e-mail address.
 */
-(IBAction)changeProfileEmailAddress:(id)sender
{
	PersonManager * personManager = [[NSApp delegate] personManager];
	[currentPerson setEmailAddress:[sender stringValue]];
	[personManager updatePerson:currentPerson];
}

/* editResume
 */
-(IBAction)editResume:(id)sender
{
	if ([currentPerson parsedInfo] != nil)
		[resumeText setString:[currentPerson parsedInfo]];
	[saveResumeButton setEnabled:YES];
	[NSApp beginSheet:resumeEditor
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(resumeSheetEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/* resumeSheetEnd
 */
-(void)resumeSheetEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString * text = [NSString stringWithString:[resumeText string]];
		PersonManager * personManager = [[NSApp delegate] personManager];
		[currentPerson setParsedInfo:text];
		[personManager updatePerson:currentPerson];
		[profileResume setStringValue:[currentPerson parsedInfo]];
	}
	[resumeEditor orderOut:self];
	[[self window] makeKeyAndOrderFront:self];
}

/* saveResume
 * Called when the user clicks Save 
 */
-(IBAction)saveResume:(id)sender
{
	[NSApp endSheet:resumeEditor returnCode:NSOKButton];
}

/* cancelResume
 * Just close the signature editor window.
 */
-(IBAction)cancelResume:(id)sender
{
	[NSApp endSheet:resumeEditor returnCode:NSCancelButton];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	if (internetConfigHandler != nil)
		ICEnd(internetConfigHandler);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[arrayOfSignatures release];
	[signatureBeingEdited release];
	[mugshotsFolderName release];
	[currentPerson release];
	[savedUsername release];
	[savedPassword release];
	[super dealloc];
}
@end
