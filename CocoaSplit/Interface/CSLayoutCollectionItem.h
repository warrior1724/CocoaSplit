//
//  CSLayoutCollectionItem.h
//  CocoaSplit
//
//  Created by Zakk on 10/4/15.
//  Copyright © 2015 Zakk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CaptureController.h"


@interface CSLayoutCollectionItem : NSCollectionViewItem


@property (weak) IBOutlet CaptureController *captureController;
@property (strong) NSMenu *layoutMenu;

- (IBAction)layoutButtonPushed:(id)sender;

-(void)buildLayoutMenu;
-(void)showLayoutMenu:(NSEvent *)clickEvent;


@end
