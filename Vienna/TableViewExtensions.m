//
//  TableViewExtensions.m
//  Vienna
//
//  Created by Steve on Thu Jun 17 2004.
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

#import "TableViewExtensions.h"

@implementation ExtendedTableView

/* setDelegate
 * Override the setDelegate for NSTableView so that we record whether or not the
 * delegate supports tooltips.
 */
-(void)setDelegate:(id)delegate
{
    if (delegate != [self delegate])
	{
        [super setDelegate:delegate];
        delegateImplementsShouldDisplayToolTips = ((delegate && [delegate respondsToSelector:@selector(tableViewShouldDisplayCellToolTips:)]) ? YES : NO);
        delegateImplementsToolTip = ((delegate && [delegate respondsToSelector:@selector(tableView:toolTipForTableColumn:row:)]) ? YES : NO);
    }
}

/* reloadData
 * Override the reloadData for NSTableView to reset the tooltip cursor
 * rectangles.
 */
-(void)reloadData
{
    [super reloadData];
    [self resetCursorRects];
}

/* resetCursorRects
 * Compute the tooltip cursor rectangles based on the height and position of the tableview rows.
 */
-(void)resetCursorRects
{
    [self removeAllToolTips];
#warning How should we cast self delegate?
    if (delegateImplementsShouldDisplayToolTips && [(NSObject *)[self delegate] tableViewShouldDisplayCellToolTips:self])
	{
        NSRect visibleRect = [self visibleRect];
        NSRange colRange = [self columnsInRect:visibleRect];
        NSRange rowRange = [self rowsInRect:visibleRect];
        NSRect frameOfCell;
		NSUInteger col, row;
		
        for (col = colRange.location; col < colRange.location + colRange.length; col++)
		{
            for (row = rowRange.location; row < rowRange.location + rowRange.length; row++)
			{
                frameOfCell = [self frameOfCellAtColumn:col row:row];
                [self addToolTipRect:frameOfCell owner:self userData:NULL];
            }
        }
    }
}

/* stringForToolTip
 * Request the delegate to retrieve the string to be displayed in the tooltip.
 */
-(NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)matrix
{
    (void) matrix; (void)tag; (void)view;
    NSInteger rowIndex = [self rowAtPoint:point];
    NSInteger columnIndex = [self columnAtPoint:point];
    NSTableColumn *tableColumn = (columnIndex != -1) ? [[self tableColumns] objectAtIndex:columnIndex] : nil;
    // added cast here (dje)
#warning how should we cast  self delegate
    return (columnIndex != -1) ? [(NSObject *)[self delegate] tableView:self toolTipForTableColumn:tableColumn row:rowIndex] : @"";
}

/* setHeaderImage
 * Set the image in the header for a column
 */
-(void)setHeaderImage:(NSString *)identifier imageName:(NSString *)name
{
	NSTableColumn * tableColumn = [self tableColumnWithIdentifier:identifier];
	NSTableHeaderCell * headerCell = [tableColumn headerCell];
	[headerCell setImage:[NSImage imageNamed:name]];
	
	NSImageCell * imageCell = [[NSImageCell alloc] init];
	[tableColumn setDataCell:imageCell];
}
@end  

