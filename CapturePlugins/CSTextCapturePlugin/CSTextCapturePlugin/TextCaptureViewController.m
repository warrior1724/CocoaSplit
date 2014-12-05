//
//  TextCaptureViewController.m
//  CocoaSplit
//
//  Created by Zakk on 8/28/14.
//  Copyright (c) 2014 Zakk. All rights reserved.
//

#import "TextCaptureViewController.h"

@interface TextCaptureViewController ()

@end

@implementation TextCaptureViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (IBAction)openFontPanel:(id)sender
{
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    fontManager.delegate = self;
    
    NSFontPanel *fontPanel = [fontManager fontPanel:YES];
    fontPanel.delegate = self;
    
    [fontPanel makeKeyAndOrderFront:self];
    [fontManager setSelectedFont:self.captureObj.font isMultiple:NO];
    [fontManager setAction:@selector(fontChanged:)];
    [fontManager setSelectedAttributes:self.captureObj.fontAttributes isMultiple:NO];
    
}

- (void)fontChanged:(id)sender
{
    NSFont *currentFont = self.captureObj.font;
    NSFont *newFont = [sender convertFont:currentFont];
    
    self.captureObj.font = newFont;
}

-(void)changeAttributes:(id)sender
{
    self.captureObj.fontAttributes = [sender convertAttributes:self.captureObj.fontAttributes];
}

-(void)dealloc
{
    
    [[NSFontPanel sharedFontPanel] setDelegate:nil];
    if ([[NSFontPanel sharedFontPanel] isVisible])
    {
        [[NSFontPanel sharedFontPanel] orderOut:self];
    }
}

@end