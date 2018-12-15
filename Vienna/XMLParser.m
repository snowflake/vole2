//
//  XMLParser.m
//  Vienna
//
//  Created by Steve on 5/27/05.
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
// 

#import "XMLParser.h"
#import "StringExtensions.h"
#import "sanitise_string.h"

@interface XMLParser (Private)
	-(id)initWithCFXMLTreeRef:(CFXMLTreeRef)treeRef;
	+(XMLParser *)treeWithCFXMLTreeRef:(CFXMLTreeRef)ref;
	-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict closed:(BOOL)flag;
@end

@implementation XMLParser

/* initWithData
 * Initialises the XMLParser with a data block which contains the XML data.
 */
-(id)initWithData:(NSData *)data
{
	CFXMLTreeRef newTree;

	NS_DURING
		newTree = CFXMLTreeCreateFromData(kCFAllocatorDefault, (CFDataRef)data, NULL, kCFXMLParserSkipWhitespace, kCFXMLNodeCurrentVersion);
	NS_HANDLER
		newTree = nil;
	NS_ENDHANDLER
	if (newTree != nil)
	{
		XMLParser * newParser = [self initWithCFXMLTreeRef:newTree];
		CFRelease(newTree);
		return newParser;
	}
	return nil;
}

/* treeWithCFXMLTreeRef
 * Allocates a new instance of an XMLParser with the specified tree.
 */
+(XMLParser *)treeWithCFXMLTreeRef:(CFXMLTreeRef)ref
{
	return [[XMLParser alloc] initWithCFXMLTreeRef:ref];
}

/* initWithCFXMLTreeRef
 * Initialises the XMLParser with a data block which contains the XML data.
 */
-(id)initWithCFXMLTreeRef:(CFXMLTreeRef)treeRef
{
	if ((self = [self init]) != nil)
	{
		if (tree != nil)
			CFRelease(tree);
		if (node != nil)
			CFRelease(node);
		tree = treeRef;
		node = CFXMLTreeGetNode(tree);
		CFRetain(tree);
		CFRetain(node);
	}
	return self;
}

/* initWithEmptyTree
 * Creates an empty XML tree to which we can add nodes.
 */
-(id)initWithEmptyTree
{
	if ((self = [self init]) != nil)
	{
		// Create the document node
		CFXMLDocumentInfo documentInfo;
		documentInfo.sourceURL = NULL;
		documentInfo.encoding = kCFStringEncodingUTF8;
		CFXMLNodeRef docNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeDocument, CFSTR(""), &documentInfo, kCFXMLNodeCurrentVersion);
		CFXMLTreeRef xmlDocument = CFXMLTreeCreateWithNode(kCFAllocatorDefault, docNode);
		CFRelease(docNode);
		
		// Add the XML header to the document
		CFXMLProcessingInstructionInfo instructionInfo;
		instructionInfo.dataString = CFSTR("version=\"1.0\" encoding=\"utf-8\"");
		CFXMLNodeRef instructionNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeProcessingInstruction, CFSTR("xml"), &instructionInfo, kCFXMLNodeCurrentVersion);
		CFXMLTreeRef instructionTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, instructionNode);
		CFTreeAppendChild(xmlDocument, instructionTree);
		
		// Create the parser object from this
		XMLParser * newParser = [self initWithCFXMLTreeRef:instructionTree];
		CFRelease(instructionTree);
		CFRelease(instructionNode);
		return newParser;
	}
	return self;
}

/* init
 * Designated initialiser.
 */
-(id)init
{
	if ((self = [super init]) != nil)
	{
		tree = nil;
		node = nil;
	}
	return self;
}

/* addTree
 * Adds a sub-tree to the current tree and returns its XMLParser object.
 */
-(XMLParser *)addTree:(NSString *)name
{
	CFXMLElementInfo info;
	info.attributes = NULL;
	info.attributeOrder = NULL;
	info.isEmpty = NO;

	CFXMLNodeRef newTreeNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeElement, (CFStringRef)name, &info, kCFXMLNodeCurrentVersion);
	CFXMLTreeRef newTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, newTreeNode);
	CFTreeAppendChild(tree, newTree);

	// Create the parser object from this
	XMLParser * newParser = [XMLParser treeWithCFXMLTreeRef:newTree];
	CFRelease(newTreeNode);
	return newParser;
}

/* addTree:withElement
 * Add a new tree and give it the specified element.
 */
-(XMLParser *)addTree:(NSString *)name withElement:(NSString *)value
{
	XMLParser * newTree = [self addTree:name];
	[newTree addElement:value];
	return newTree;
}

/* addElement
 * Add an element to the tree.
 */
-(void)addElement:(NSString *)value
{
	CFXMLNodeRef newNode = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeText, (CFStringRef)value, NULL, kCFXMLNodeCurrentVersion);   
	CFXMLTreeRef newTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, newNode);
	CFTreeAppendChild(tree, newTree);
	CFRelease(newTree);
	CFRelease(newNode);
}

/* addClosedTree:withAttributes
 * Add a new tree with attributes to the tree.
 */
-(XMLParser *)addClosedTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict
{
	return [self addTree:name withAttributes:attributesDict closed:YES];
}

/* addTree:withAttributes
 * Add a new tree with attributes to the tree.
 */
-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict
{
	return [self addTree:name withAttributes:attributesDict closed:NO];
}

/* addTree:withAttributes:closed
 * Add a new tree with attributes to the tree.
 */
-(XMLParser *)addTree:(NSString *)name withAttributes:(NSDictionary *)attributesDict closed:(BOOL)flag
{
	CFXMLElementInfo info;
	info.attributes = (__bridge CFDictionaryRef)attributesDict;
	info.attributeOrder = (__bridge CFArrayRef)[attributesDict allKeys];
	info.isEmpty = flag;

	CFXMLNodeRef newNode = CFXMLNodeCreate (kCFAllocatorDefault, kCFXMLNodeTypeElement, (CFStringRef)name, &info, kCFXMLNodeCurrentVersion);   
	CFXMLTreeRef newTree = CFXMLTreeCreateWithNode(kCFAllocatorDefault, newNode);
	CFTreeAppendChild(tree, newTree);

	// Create the parser object from this
	XMLParser * newParser = [XMLParser treeWithCFXMLTreeRef:newTree];
	CFRelease(newTree);
	CFRelease(newNode);
	return newParser;
}

/* treeByIndex
 * Returns an XMLParser object for the child tree at the specified index.
 */
-(XMLParser *)treeByIndex:(NSInteger)index
{
	return [XMLParser treeWithCFXMLTreeRef:CFTreeGetChildAtIndex(tree, index)];
}

/* treeByPath
 * Retrieves a tree located by a specified sub-nesting of XML nodes. For example, given the
 * following XML document:
 *
 *   <root>
 *		<body>
 *			<element></element>
 *		</body>
 *   </root>
 *
 * Then treeByPath:@"root/body/element" will return the tree for the <element> node. If any
 * element does not exist, it returns nil.
 */
-(XMLParser *)treeByPath:(NSString *)path
{
	NSArray * pathElements = [path componentsSeparatedByString:@"/"];
	NSEnumerator * enumerator = [pathElements objectEnumerator];
	XMLParser * treeFound = self;
	NSString * treeName;
	
	while ((treeName = [enumerator nextObject]) != nil)
	{
		treeFound = [treeFound treeByName:treeName];
		if (treeFound == nil)
			return nil;
	}
	return treeFound;
}

/* treeByName
 * Given a node in the XML tree, this returns the sub-tree with the specified name or nil
 * if the tree cannot be found.
 */
-(XMLParser *)treeByName:(NSString *)name
{
	NSInteger count = CFTreeGetChildCount(tree);
	NSInteger index;
	
	for (index = count - 1; index >= 0; --index)
	{
		CFXMLTreeRef subTree = CFTreeGetChildAtIndex(tree, index);
		CFXMLNodeRef subNode = CFXMLTreeGetNode(subTree);
		if ([name isEqualToString:(NSString *)CFXMLNodeGetString(subNode)])
			return [XMLParser treeWithCFXMLTreeRef:subTree];
	}
	return nil;
}

/* countOfChildren
 * Count of children of this tree
 */
-(NSInteger)countOfChildren
{
	return CFTreeGetChildCount(tree);
}

/* xmlForTree
 * Returns the XML text for the specified tree.
 */
-(NSString *)xmlForTree
{
	NSData * data = (NSData *)CFBridgingRelease(CFXMLTreeCreateXMLData(kCFAllocatorDefault, tree));
	// DJE deprecated API here
	//	NSString * xmlString = [NSString stringWithCString:[data bytes] length:[data length]];
	// replaced by
	//  XXX does [data bytes ] return a read only pointer, thus the string cannot be sanitised?
	size_t length = [ data length];
	char *cp = malloc(length+1);
	if(cp == NULL){CFRelease((__bridge CFTypeRef)(data)); return nil;}
	[data getBytes: (void *) cp length:length ];
	*(cp +length) = '\0';
#ifdef VOLE2
	NSString *xmlString = [[NSString alloc] initWithBytes: cp
													length: length 
                                                  encoding: NSUTF8StringEncoding];
#else /* vole 1 code, this is broken, but it should not be changed */
    NSString *xmlString = [[NSString alloc] initWithBytes: sanitise_string( cp )
													length: length 
                                                  encoding: NSWindowsCP1252StringEncoding];
#endif
    free(cp);
	// end of new changes
	CFRelease((__bridge CFTypeRef)(data));
	return xmlString;
}

/* description
 * Make this return the XML string which is pretty useful.
 */
-(NSString *)description
{
	return [self xmlForTree];
}

/* attributesForTree
 * Returns a dictionary of all attributes on the current tree.
 */
-(NSDictionary *)attributesForTree
{
	if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement )
	{
		CFXMLElementInfo eInfo = *(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
		return (__bridge NSDictionary *)eInfo.attributes;
	}
	return nil;
}

/* valueOfAttribute
 * Returns the value of the named attribute of the specified node. If the node is a processing instruction
 * then what we obtain from CFXMLNodeGetInfoPtr is a pointer to a CFXMLProcessingInstructionInfo structure
 * which encodes the entire processing instructions as a single string. Thus to obtain the 'attribute' that
 * equates to the processing instruction element we're interested in we need to parse that string to extract
 * the value.
 */
-(NSString *)valueOfAttribute:(NSString *)attributeName
{
	if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeElement)
	{
		CFXMLElementInfo eInfo = *(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
		if (eInfo.attributes != nil)
		{
			return (NSString *)CFDictionaryGetValue(eInfo.attributes, (__bridge const void *)(attributeName));
		}
	}
	else if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeProcessingInstruction)
	{
		CFXMLProcessingInstructionInfo eInfo = *(CFXMLProcessingInstructionInfo *)CFXMLNodeGetInfoPtr(node);
		NSScanner * scanner = [NSScanner scannerWithString:(__bridge NSString *)eInfo.dataString];
		while (![scanner isAtEnd])
		{
			NSString * instructionName = nil;
			NSString * instructionValue = nil;

			[scanner scanUpToString:@"=" intoString:&instructionName];
			[scanner scanString:@"=" intoString:nil];
			[scanner scanUpToString:@" " intoString:&instructionValue];
			
			if (instructionName != nil && instructionValue != nil)
			{
				if ([instructionName isEqualToString:attributeName])
					return [instructionValue stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
			}
		}
	}
	return nil;
}

/* nodeName
 * Returns the name of the node of this tree.
 */
-(NSString *)nodeName
{
	return (NSString *)CFXMLNodeGetString(node);
}

/* valueOfElement
 * Returns the value of the element of the specified tree. Special case for handling application/xhtml+xml which
 * is a bunch of XML/HTML embedded in the tree without a CDATA. In order to get the raw text, we need to extract
 * the XML data itself and append it as we go along.
 */
-(NSString *)valueOfElement
{
	NSMutableString * valueString = [NSMutableString stringWithCapacity:16];
	BOOL isXMLContent = [[self valueOfAttribute:@"type"] isEqualToString:@"application/xhtml+xml"];
	
	if ([[self valueOfAttribute:@"type"] isEqualToString:@"text/html"] && [[self valueOfAttribute:@"mode"] isEqualToString:@"xml"])
		isXMLContent = YES;
	
	if (isXMLContent)
	{
		NSInteger count = CFTreeGetChildCount(tree);
		NSInteger index;
		
		for (index = 0; index < count; ++index)
		{
			CFXMLTreeRef subTree = CFTreeGetChildAtIndex(tree, index);
			CFDataRef valueData = CFXMLTreeCreateXMLData(NULL, subTree);
		//	DJE Deprecated API here
		//	[valueString appendString:[NSString stringWithCString:(char *)CFDataGetBytePtr(valueData) length:CFDataGetLength(valueData)]];
		//
		// replaced by	
#ifdef VOLE2
            // Vole 2 (added 22-3-2017)
            [valueString appendString:[[NSString alloc] initWithBytes: (char *)CFDataGetBytePtr(valueData)
																length: CFDataGetLength(valueData)
															  encoding:	NSUTF8StringEncoding]];
#else
            // Vole 1 broken code. Does not work for searches for codepoints >0x7f
            [valueString appendString:[[NSString alloc] initWithBytes: sanitise_string((char *)CFDataGetBytePtr(valueData))
                                                                length:CFDataGetLength(valueData)
                                                              encoding:	NSWindowsCP1252StringEncoding]];
#endif  // VOLE2
            CFRelease(valueData);
            
            
		}
	}
	else
	{
		NSInteger count = CFTreeGetChildCount(tree);
		NSInteger index;
		
		for (index = 0; index < count; ++index)
		{
			CFXMLTreeRef subTree = CFTreeGetChildAtIndex(tree, index);
			CFXMLNodeRef subNode = CFXMLTreeGetNode(subTree);
			NSString * valueName = (NSString *)CFXMLNodeGetString(subNode);
			if (valueName != nil)
			{
				if (CFXMLNodeGetTypeCode(subNode) == kCFXMLNodeTypeEntityReference)
				{
					if ([valueName isEqualTo:@"lt"])	valueName = @"<";
					else if ([valueName isEqualTo: @"gt"]) valueName = @">";
					else if ([valueName isEqualTo: @"quot"]) valueName = @"\"";
					else if ([valueName isEqualTo: @"amp"]) valueName = @"&";
					else if ([valueName isEqualTo: @"rsquo"]) valueName = @"'";
					else if ([valueName isEqualTo: @"lsquo"]) valueName = @"'";
					else if ([valueName isEqualTo: @"apos"]) valueName = @"'";				
					else valueName = [NSString stringWithFormat: @"&%@;", valueName];
				}
				[valueString appendString:valueName];
			}
		}
	}
	return valueString;
}

/* quoteAttributes
 * Scan the specified string and convert HTML literal characters to their entity equivalents.
 */
+(NSString *)quoteAttributes:(NSString *)stringToProcess
{
	NSMutableString * newString = [NSMutableString stringWithString:stringToProcess];
	[newString replaceString:@"&" withString:@"&amp;"];
	[newString replaceString:@"<" withString:@"&lt;"];
	[newString replaceString:@">" withString:@"&gt;"];
	[newString replaceString:@"\"" withString:@"&quot;"];
	[newString replaceString:@"'" withString:@"&apos;"];
	return newString;
}

/* processAttributes
 * Scan the specified string and convert attribute characters to their literals. Also trim leading and trailing
 * whitespace.
 */
+(NSString *)processAttributes:(NSString *)stringToProcess
{
	if (stringToProcess == nil)
		return nil;
	
	NSMutableString * processedString = [[NSMutableString alloc] initWithString:stringToProcess];
	NSInteger entityStart;
	NSInteger entityEnd;
	
	entityStart = [processedString indexOfCharacterInString:'&' afterIndex:0];
	while (entityStart != NSNotFound)
	{
		entityEnd = [processedString indexOfCharacterInString:';' afterIndex:entityStart + 1];
		if (entityEnd != NSNotFound)
		{
			NSRange entityRange = NSMakeRange(entityStart, (entityEnd - entityStart) + 1);
			NSString * entityString = [processedString substringWithRange:entityRange];
			NSString * stringToAppend;
			
			if ([entityString characterAtIndex:1] == '#' && entityRange.length > 3)
// #warning 64BIT dje
				stringToAppend = [NSString stringWithFormat:@"%c", [[entityString substringFromIndex:2] intValue]];
			else
			{
				if ([entityString isEqualTo:@"&lt;"])				stringToAppend = @"<";
				else if ([entityString isEqualTo: @"&gt;"])			stringToAppend = @">";
				else if ([entityString isEqualTo: @"&quot;"])		stringToAppend = @"\"";
				else if ([entityString isEqualTo: @"&amp;"])		stringToAppend = @"&";
				else if ([entityString isEqualTo: @"&rsquo;"])		stringToAppend = @"'";
				else if ([entityString isEqualTo: @"&lsquo;"])		stringToAppend = @"'";
				else if ([entityString isEqualTo: @"&apos;"])		stringToAppend = @"'";				
				else												stringToAppend = entityString;
			}
			[processedString replaceCharactersInRange:entityRange withString:stringToAppend];
		}
		entityStart = [processedString indexOfCharacterInString:'&' afterIndex:entityStart + 1];
	}
	
	NSString * returnString = [processedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return returnString;
}

/* parseXMLDate
 * Parse a date in an XML header into an NSCalendarDate. This is horribly expensive and needs
 * to be replaced with a parser that can handle these formats:
 *
 *   2005-10-23T10:12:22-4:00
 *   2005-10-23T10:12:22.003-4:00
 *   2005-10-23T10:12:22
 *   2005-10-23T10:12:22Z
 *   Mon, 10 Oct 2005 10:12:22 -4:00
 *   10 Oct 2005 10:12:22 -4:00
 *
 * These are the formats that I've discovered so far.
 */
+(NSCalendarDate *)parseXMLDate:(NSString *)dateString
{
	NSCalendarDate * date;
	
	date = [NSCalendarDate dateWithString:dateString calendarFormat:@"%Y-%m-%dT%H:%M:%S%z"];
	if (date == nil)
	{
		NSCalendarDate *datetmp = [NSCalendarDate dateWithString:dateString calendarFormat:@"%Y-%m-%dT%H:%M:%S.%F%z"];
		if (datetmp)
		{
			// PJC Disgusting way to get rid of the milliseconds that cause so much trouble
			NSString *tmp = [datetmp descriptionWithCalendarFormat: @"%Y-%m-%dT%H:%M:%S%z"];
			date = [NSCalendarDate dateWithString:tmp calendarFormat:@"%Y-%m-%dT%H:%M:%S%z"];
		}
	}
	if (date == nil)
		date = [NSCalendarDate dateWithString:dateString calendarFormat:@"%Y-%m-%dT%H:%M%z"];
	if (date == nil)
		date = [NSCalendarDate dateWithString:dateString calendarFormat:@"%Y-%m-%dT%H:%M:%SZ"];
	if (date == nil)
		date = [NSCalendarDate dateWithString:dateString calendarFormat:@"%a, %d %b %Y %H:%M:%S %Z"];
	if (date == nil)
		date = [NSCalendarDate dateWithString:dateString calendarFormat:@"%d %b %Y %H:%M:%S %Z"];
	return date;
}

/* dealloc
 * Clean up when we're done.
 */
-(void)dealloc
{
	if (node != nil)
		CFRelease(node);
	if (tree != nil)
		CFRelease(tree);
}
@end
