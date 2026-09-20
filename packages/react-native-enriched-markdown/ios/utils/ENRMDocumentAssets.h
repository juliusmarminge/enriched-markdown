#pragma once
#import "MarkdownASTNode.h"
#import <Foundation/Foundation.h>

// Traverses the accepted native AST without mutating it. IDs identify occurrences.
FOUNDATION_EXPORT NSArray<NSDictionary *> *ENRMPrepareDocumentAssets(MarkdownASTNode *ast);
