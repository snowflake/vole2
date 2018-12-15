//
//  ImageAndTextCell.m
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

#import "ImageAndTextCell.h"

@implementation ImageAndTextCell

-(ImageAndTextCell *) 
copyWithZone:(NSZone *)zone        \
{
    ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
    cell->image = image;
	cell->offset = offset;
    return cell;
}

-(void)setOffset:(NSInteger)newOffset
{
	offset = newOffset;
}

-(NSInteger)offset
{
	return offset;
}

-(void)setImage:(NSImage *)anImage
{
    if (anImage != image)
	{
		image = nil;
		if (anImage)
			image = anImage;
    }
}

-(NSImage *)image
{
    return image;
}

-(NSRect)imageFrameForCellFrame:(NSRect)cellFrame
{
    if (image != nil)
	{
        NSRect imageFrame;
        imageFrame.size = [image size];
        imageFrame.origin = cellFrame.origin;
        imageFrame.origin.x += 3;
        imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
        return imageFrame;
    }
	return NSZeroRect;
}

-(void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    [super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

-(void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
    NSRect textFrame, imageFrame;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    [super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSInteger drawingOffset = (offset * 10);
	NSInteger cellContentWidth;

	cellContentWidth = [self cellSizeForBounds:cellFrame].width;
	if (image != nil)
		cellContentWidth += [image size].width + 3;
	if (drawingOffset + cellContentWidth > cellFrame.size.width)
	{
		drawingOffset = cellFrame.size.width - cellContentWidth;
		if (drawingOffset < 0)
			drawingOffset = 0;
	}
	cellFrame.origin.x += drawingOffset;
    if (image != nil)
	{
        NSSize	imageSize;
        NSRect	imageFrame;

        imageSize = [image size];
        NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
        if ([self drawsBackground])
		{
            [[self backgroundColor] set];
            NSRectFill(imageFrame);
        }
        imageFrame.origin.x += 3;
        imageFrame.size = imageSize;
#if ( VOLE_DEPLOYMENT_TARGET < VOLE_MACOSX_10_6)
            // Tiger and Leopard Code.
			if ([controlView isFlipped])
                imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
            else
                imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
            // deprecated API in 10.8 (DJE)
            [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
#else
            // replacement for deprecated API (works on OSX 10.6 and later)
            // see http://git.chromium.org/gitweb/?p=chromium/chromium.git;a=commitdiff;h=27a103d09d5a52e293f075fa6468a3039e92e8fe
            imageFrame.origin.y += ceil((cellFrame.size.height - imageSize.height) / 2);
            [image drawInRect:imageFrame
                     fromRect:NSZeroRect
                    operation:NSCompositeSourceOver
                     fraction:1.0
               respectFlipped:YES
                        hints:nil];
#endif // VOLE_DEPLOYMENT_TARGET
    }
    [super drawWithFrame:cellFrame inView:controlView];
}

-(NSSize)cellSize
{
    NSSize cellSize = [super cellSize];
    cellSize.width += (image ? [image size].width : 0) + 3;
	cellSize.height = [image size].height + 4;
    return cellSize;
}

-(void)dealloc
{
    image = nil;
}
@end
