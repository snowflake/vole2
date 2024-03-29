//
//  SearchFolder.m
//  Vienna
//
//  Created by Steve on Sun Apr 18 2004.
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

#import "SearchFolder.h"

// Tags for the three fields that define a criteria. We set these here
// rather than in IB to be consistent.
#define MA_SFEdit_FieldTag			1000
#define MA_SFEdit_OperatorTag		1001
#define MA_SFEdit_ValueTag			1002
#define MA_SFEdit_FlagValueTag		1003
#define MA_SFEdit_DateValueTag		1004
#define MA_SFEdit_NumberValueTag	1005
#define MA_SFEdit_AddTag			1006
#define MA_SFEdit_RemoveTag			1007

// Default field
static NSString * defaultField = @"Read";

@implementation SearchFolder

/* init
 * Just init the search criteria class.
 */
-(id)initWithDatabase:(Database *)newDb
{
	if ((self = [super init]) != nil)
	{
		totalCriteria = 0;
		searchFolderId = -1;
		db = newDb;
		firstRun = YES;
		arrayOfViews = [[NSMutableArray alloc] init];
	}
	return self;
}

/* newCriteria
 * Initialises the search folder panel with a single empty criteria to get
 * started.
 */
-(void)newCriteria:(NSWindow *)window
{
	[self initSearchSheet:@""];
	searchFolderId = -1;
	[searchFolderName setEnabled:YES];

	// Add a default criteria.
	[self addDefaultCriteria:0];
	[self displaySearchSheet:window];
}

/* loadCriteria
 * Loads the criteria for the specified folder.
 */
-(void)loadCriteria:(NSWindow *)window folderId:(NSInteger)folderId
{
	Folder * folder = [db folderFromID:folderId];
	if (folder != nil)
	{
		NSInteger index = 0;

		[self initSearchSheet:[folder name]];
		searchFolderId = folderId;
		[searchFolderName setEnabled:YES];

		// Load the criteria into the fields.
		VCriteriaTree * criteriaTree = [db searchStringForSearchFolder:folderId];
		NSEnumerator * enumerator = [criteriaTree criteriaEnumerator];
		VCriteria * criteria;

		while ((criteria = [enumerator nextObject]) != nil)
		{
			[self initForField:[criteria field] inRow:searchCriteriaView];

			[fieldNamePopup selectItemWithTitle:[criteria field]];
			[operatorPopup selectItemWithTitle:NSLocalizedString([VCriteria stringFromOperator:[criteria operator]], nil)];

			VField * field = [nameToFieldMap valueForKey:[criteria field]];
			switch ([field type])
			{
				case MA_FieldType_Flag: {
					[flagValueField selectItemWithTitle:[criteria value]];
					break;
				}
					
				case MA_FieldType_String: {
					[valueField setStringValue:[criteria value]];
					break;
				}
					
				case MA_FieldType_Integer: {
					[numberValueField setStringValue:[criteria value]];
					break;
				}
					
				case MA_FieldType_Date: {
					[dateValueField setStringValue:[criteria value]];
					break;
				}
			}
			
			[self addCriteria:index++];
		}

		// We defer sizing the window until all the criteria are
		// added otherwise it looks crap.
		[self displaySearchSheet:window];
		[self resizeSearchWindow];
	}
}

/* initSearchSheet
 */
-(void)initSearchSheet:(NSString *)folderName
{
	// Clean up from any last run.
	if (totalCriteria > 0)
		[self removeAllCriteria];
	
	// Initialize UI
	if (!searchWindow)
	{
		[NSBundle loadNibNamed:@"SearchFolder" owner:self];

		// Register our notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextDidChange:) name:NSControlTextDidChangeNotification object:searchFolderName];

		// Create a mapping for field to column names
		nameToFieldMap = [NSMutableDictionary dictionary];

		// Initialize the search criteria view popups with all the
		// fields in the database.
		NSArray * fields = [db arrayOfFields];
		NSEnumerator * enumerator = [fields objectEnumerator];
		VField * field;

		[fieldNamePopup removeAllItems];
		while ((field = [enumerator nextObject]) != nil)
		{
			// Leave off fields that make no sense really
			if ([field type] == MA_FieldType_Folder)
				continue;

			[fieldNamePopup addItemWithTitle:[field title]];
			[nameToFieldMap setValue:field forKey:[field title]];
		}

		// Set the tags on the controls
		[fieldNamePopup setTag:MA_SFEdit_FieldTag];
		[operatorPopup setTag:MA_SFEdit_OperatorTag];
		[valueField setTag:MA_SFEdit_ValueTag];
		[flagValueField setTag:MA_SFEdit_FlagValueTag];
		[dateValueField setTag:MA_SFEdit_DateValueTag];
		[numberValueField setTag:MA_SFEdit_NumberValueTag];
		[removeCriteriaButton setTag:MA_SFEdit_RemoveTag];
		[addCriteriaButton setTag:MA_SFEdit_AddTag];
	}

	// Init the folder name field and disable the Save button if it is blank
	[searchFolderName setStringValue:folderName];
	[saveButton setEnabled:![folderName isEqualToString:@""]];
}

/* displaySearchSheet
 * Display the search sheet.
 */
-(void)displaySearchSheet:(NSWindow *)window
{
	// Begin the sheet
	[NSApp beginSheet:searchWindow modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];

	// Remember the intial window size after it is first
	// loaded and before any criteria are added that will
	// cause it to be resized. We need to know this to shrink
	// it back to it's default size.
	if (firstRun)
	{
		searchWindowFrame = [NSWindow contentRectForFrameRect:[searchWindow frame] styleMask:[searchWindow styleMask]]; 
		firstRun = NO;
	}
}

/* removeCurrentCriteria
 * Remove the current criteria row
 */
-(IBAction)removeCurrentCriteria:(id)sender
{
	NSInteger index = [arrayOfViews indexOfObject:[sender superview]];
	NSAssert(index >= 0 && index < totalCriteria, @"Got an out of bounds index of view in superview");
	[self removeCriteria:index];
	[self resizeSearchWindow];
}

/* addNewCriteria
 * Add another criteria row.
 */
-(IBAction)addNewCriteria:(id)sender
{
	NSInteger index = [arrayOfViews indexOfObject:[sender superview]];
	NSAssert(index >= 0 && index < totalCriteria, @"Got an out of bounds index of view in superview");
	[self addDefaultCriteria:index + 1];
	[self resizeSearchWindow];
}

/* addDefaultCriteria
 * Add a new default criteria row. For this we use the static defaultField declared at
 * the start of this source and the default operator for that field, and an empty value.
 */
-(void)addDefaultCriteria:(NSInteger)index
{
	[self initForField:defaultField inRow:searchCriteriaView];
	[fieldNamePopup selectItemWithTitle:defaultField];
	[valueField setStringValue:@""];
	[self addCriteria:index];
}

/* fieldChanged
 * Handle the case where the field has changed. Update the valid list of
 * operators for the selected field.
 */
-(IBAction)fieldChanged:(id)sender
{
	[self initForField:[sender titleOfSelectedItem] inRow:[sender superview]];
}

/* initForField
 * Initialise the operator and value fields for the specified field.
 */
-(void)initForField:(NSString *)fieldName inRow:(NSView *)row
{
	VField * field = [nameToFieldMap valueForKey:fieldName];
	NSAssert1(field != nil, @"Got nil field for field '%@'", fieldName);

	// Need to flip on the operator popup for the field that changed
	NSPopUpButton * theOperatorPopup = [row viewWithTag:MA_SFEdit_OperatorTag];
	[theOperatorPopup removeAllItems];	
	switch ([field type])
	{
		case MA_FieldType_Flag:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									0];
			break;

		case MA_FieldType_String:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsNot,
									MA_CritOper_Contains,
									MA_CritOper_NotContains,
									0];
			break;

		case MA_FieldType_Integer:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsNot,
									MA_CritOper_IsGreaterThan,
									MA_CritOper_IsGreaterThanOrEqual,
									MA_CritOper_IsLessThan,
									MA_CritOper_IsLessThanOrEqual,
									0];
			break;

		case MA_FieldType_Date:
			[self setOperatorsPopup:theOperatorPopup,
									MA_CritOper_Is,
									MA_CritOper_IsAfter,
									MA_CritOper_IsBefore,
									MA_CritOper_IsOnOrAfter,
									MA_CritOper_IsOnOrBefore,
									0];
			break;
	}

	// Show and hide the value fields depending on the type
	NSView * theValueField = [row viewWithTag:MA_SFEdit_ValueTag];
	NSView * theFlagValueField = [row viewWithTag:MA_SFEdit_FlagValueTag];
	NSView * theNumberValueField = [row viewWithTag:MA_SFEdit_NumberValueTag];
	NSView * theDateValueField = [row viewWithTag:MA_SFEdit_DateValueTag];

	[theFlagValueField setHidden:[field type] != MA_FieldType_Flag];
	[theValueField setHidden:[field type] != MA_FieldType_String];
	[theDateValueField setHidden:[field type] != MA_FieldType_Date];
	[theNumberValueField setHidden:[field type] != MA_FieldType_Integer];
}

/* setOperatorsPopup
 * Fills the specified pop up button field with a list of valid operators.
 */
-(void)setOperatorsPopup:(NSPopUpButton *)popUpButton, ...
{
	va_list arguments;
	va_start(arguments, popUpButton);
	CriteriaOperator operator;

	while ((operator = va_arg(arguments, NSInteger)) != 0)
	{
		NSString * operatorString = NSLocalizedString([VCriteria stringFromOperator:operator], nil);
		[popUpButton addItemWithTitle:operatorString];
	}
}

/* doSave
 * Create a CriteriaTree from the criteria rows and save this to the
 * database.
 */
-(IBAction)doSave:(id)sender
{
    (void)sender;
	NSString * folderName = [searchFolderName stringValue];
	NSUInteger c;

	// Build the criteria string
	VCriteriaTree * criteriaTree = [[VCriteriaTree alloc] init];
	for (c = 0; c < [arrayOfViews count]; ++c)
	{
		NSView * row = [arrayOfViews objectAtIndex:c];
		NSPopUpButton * theField = [row viewWithTag:MA_SFEdit_FieldTag];
		NSPopUpButton * theOperator = [row viewWithTag:MA_SFEdit_OperatorTag];
		
		NSString * fieldString = [theField titleOfSelectedItem];
		NSString * operatorString = [theOperator titleOfSelectedItem];
		NSString * valueString;

		VField * field = [nameToFieldMap valueForKey:fieldString];
		if ([field type] == MA_FieldType_Flag)
		{
			NSPopUpButton * theValue = [row viewWithTag:MA_SFEdit_FlagValueTag];
			valueString = [theValue titleOfSelectedItem];
		}
		else if ([field type] == MA_FieldType_Date)
		{
			NSTextField * theValue = [row viewWithTag:MA_SFEdit_DateValueTag];
			valueString = [theValue stringValue];
		}
		else if ([field type] == MA_FieldType_Integer)
		{
			NSTextField * theValue = [row viewWithTag:MA_SFEdit_NumberValueTag];
			valueString = [theValue stringValue];
		}
		else
		{
			NSTextField * theValue = [row viewWithTag:MA_SFEdit_ValueTag];
			valueString = [theValue stringValue];
		}

		CriteriaOperator operator = [VCriteria operatorFromString:operatorString];
		VCriteria * newCriteria = [[VCriteria alloc] initWithField:fieldString withOperator:operator withValue:valueString];
		[criteriaTree addCriteria:newCriteria];
	}

	// Get the folder name then either create a new search folder entry in the database
	// or update the one we're editing.
	folderName = [folderName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSAssert(![folderName isEqualToString:@""], @"doSave called with empty folder name");
	if (searchFolderId == -1)
		[db createSearchFolder:folderName withQuery:criteriaTree];
	else
		[db updateSearchFolder:searchFolderId withFolder:folderName withQuery:criteriaTree];

	
	[NSApp endSheet:searchWindow];
	[searchWindow orderOut:self];
}

/* doCancel
 */
-(IBAction)doCancel:(id)sender
{
    (void)sender;
	[NSApp endSheet:searchWindow];
	[searchWindow orderOut:self];
}

/* handleTextDidChange [delegate]
 * This function is called when the contents of the input field is changed.
 * We disable the Save button if the input field is empty or enable it otherwise.
 */
-(void)handleTextDidChange:(NSNotification *)aNotification
{
    (void)aNotification;
	NSString * folderName = [searchFolderName stringValue];
	folderName = [folderName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[saveButton setEnabled:![folderName isEqualToString:@""]];
}

/* removeAllCriteria
 * Remove all existing criteria (i.e. reset the views back to defaults).
 */
-(void)removeAllCriteria
{
	NSInteger c;

	NSArray * subviews = [searchCriteriaSuperview subviews];
	for (c = [subviews count] - 1; c >= 0; --c)
	{
		NSView * row = [subviews objectAtIndex:c];
		[row removeFromSuperview];
	}
	[arrayOfViews removeAllObjects];
	totalCriteria = 0;
}

/* removeCriteria
 * Remove the criteria at the specified index.
 */
-(void)removeCriteria:(NSInteger)index
{
	NSInteger rowHeight = [searchCriteriaView frame].size.height;
	NSInteger c;

	// Remove the view from the parent view
	NSAssert(totalCriteria > 0, @"Attempting to remove the last criteria!");
	NSView * row = [arrayOfViews objectAtIndex:index];
	[row removeFromSuperview];
	[arrayOfViews removeObject:row];
	--totalCriteria;
	
	// Shift the subviews
	for (c = 0; c < index; ++c)
	{
		NSView * row = [arrayOfViews objectAtIndex:c];
		NSPoint origin = [row frame].origin;
		[row setFrameOrigin:NSMakePoint(origin.x, origin.y - rowHeight)];
	}

	// If we removed the first criteria, disable the new first criteria
	// remove button
	if (index == 0)
	{
		row = [arrayOfViews objectAtIndex:0];
		NSButton * removeButton = [row viewWithTag:MA_SFEdit_RemoveTag];
		NSAssert(removeButton != nil, @"Didn't match remove button with its tag in row");
		[removeButton setEnabled:NO];
	}
}

/* addCriteria
 * Add a new criteria clause. Before calling this function, initialise the
 * searchView with the settings to be added.
 */
-(void)addCriteria:(NSUInteger)index
{
	NSData * archRow;
	NSView * previousRow = nil;
	NSInteger rowHeight = [searchCriteriaView frame].size.height;
	NSUInteger c;

	// Disable remove button if this is the first criteria
	[removeCriteriaButton setEnabled:index > 0];

	// Bump up the criteria count
	++totalCriteria;
	if (!firstRun)
		[self resizeSearchWindow];

	// Shift the existing subviews up by rowHeight
	if (index > [arrayOfViews count])
		index = [arrayOfViews count];
	for (c = 0; c < index; ++c)
	{
		NSView * row = [arrayOfViews objectAtIndex:c];
		NSPoint origin = [row frame].origin;
		[row setFrameOrigin:NSMakePoint(origin.x, origin.y + rowHeight)];
		previousRow = row;
	}

	// Now add the new subview
	archRow = [NSArchiver archivedDataWithRootObject:searchCriteriaView];
	NSRect bounds = [searchCriteriaSuperview bounds];
	NSView *row = (NSView *)[NSUnarchiver unarchiveObjectWithData:archRow];
	[row setFrameOrigin:NSMakePoint(bounds.origin.x, bounds.origin.y + (((totalCriteria - 1) - index) * rowHeight))];
	[searchCriteriaSuperview addSubview:row];
	[arrayOfViews insertObject:row atIndex:index];

	// Link the previous row to the next one so that the Tab key behaves
	// properly through the entire sheet.
	// BUGBUG: This doesn't work and I can't figure out why not yet. This needs to be fixed.
	if (previousRow)
	{
		NSView * lastKeyView = [previousRow nextKeyView];
		[previousRow setNextKeyView:row];
		[row setNextKeyView:lastKeyView];
	}
	[searchCriteriaSuperview display];
}

/* resizeSearchWindow
 * Resize the search window for the number of criteria 
 */
-(void)resizeSearchWindow
{
	NSRect newFrame;

	newFrame = searchWindowFrame;
	if (totalCriteria > 0)
	{
		NSInteger rowHeight = [searchCriteriaView frame].size.height;
		NSInteger newHeight = newFrame.size.height + rowHeight * (totalCriteria - 1);
		newFrame.origin.y += newFrame.size.height;
		newFrame.origin.y -= newHeight;
		newFrame.size.height = newHeight;
		newFrame = [NSWindow frameRectForContentRect:newFrame styleMask:[searchWindow styleMask]];
	}
	[searchWindow setFrame:newFrame display:YES animate:YES];
}

/* dealloc
 * Clean up and release resources.
 */
-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
