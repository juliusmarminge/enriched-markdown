#pragma once
#import "ENRMUIKit.h"
@class MarkdownASTNode;
@interface ENRMMediaSlotView : RCTUIView
@property (nonatomic, strong) MarkdownASTNode *mediaNode;
@end
