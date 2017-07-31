//
//  CSFFMpegCaptureViewController.m
//  CSFFMpegCapturePlugin
//
//  Created by Zakk on 6/14/16.
//  Copyright © 2016 Zakk. All rights reserved.
//

#import "CSFFMpegCaptureViewController.h"

@interface CSFFMpegCaptureViewController ()

@end

@implementation CSFFMpegCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.queueTableView registerForDraggedTypes:@[NSFilenamesPboardType]];
    // Do view setup here.
    if (self.captureObj && self.captureObj.player)
    {
        self.captureObj.player.pauseStateChanged = ^{
            [self pauseStateChanged];
        };
    }
}


-(NSSet *)contentTypesForPath:(NSString *)path
{
    MDItemRef mditem = MDItemCreate(NULL, (__bridge CFStringRef)path);
    if (mditem)
    {
        NSArray *attrs = @[(__bridge NSString *)kMDItemContentTypeTree];
        NSDictionary *attrMap = CFBridgingRelease(MDItemCopyAttributes(mditem, (__bridge CFArrayRef)attrs));
        NSArray *fileTypes = attrMap[(__bridge NSString *)kMDItemContentTypeTree];
        if (fileTypes)
        {
            NSSet *typeSet = [NSSet setWithArray:fileTypes];
            return typeSet;
        }
    }
    return nil;
}


-(NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pb = [info draggingPasteboard];
    
    for(NSPasteboardItem *item in pb.pasteboardItems)
    {
        if ([item.types containsObject:@"public.file-url"])
        {
            NSString *draggedPath = [item stringForType:@"public.file-url"];
            if (draggedPath)
            {
                NSURL *fileURL = [NSURL URLWithString:draggedPath];
                NSString *realPath = [fileURL path];
                NSSet *fileTypes = [self contentTypesForPath:realPath];
                NSSet *myTypes = [CSFFMpegCapture mediaUTIs];
                if ([fileTypes intersectsSet:myTypes])
                {
                    return NSDragOperationCopy;
                }
            }
        }
    }
    return NSDragOperationNone;
}

-(BOOL) tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
 
    NSPasteboard *pb = [info draggingPasteboard];
    
    for(NSPasteboardItem *item in pb.pasteboardItems)
    {
        if ([item.types containsObject:@"public.file-url"])
        {
            NSString *draggedPath = [item stringForType:@"public.file-url"];
            if (draggedPath)
            {
                NSURL *fileURL = [NSURL URLWithString:draggedPath];
                NSString *realPath = [fileURL path];
                [self.captureObj queuePath:realPath];
            }
        }
    }

    return YES;
}


- (IBAction)queueTableDoubleClick:(NSTableView *)sender
{
    CSFFMpegInput *inp = [self.queueArrayController.arrangedObjects objectAtIndex:sender.clickedRow];
    if (inp)
    {
        [self.captureObj.player playAndAddItem:inp];
    }
}



- (IBAction)chooseFile:(id)sender
{
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = NO;
    panel.canCreateDirectories = NO;
    panel.canChooseFiles = YES;
    panel.allowsMultipleSelection = YES;
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
        {
            for (NSURL *openURL in panel.URLs)
            {
                [self.captureObj queuePath:openURL.path];
            }
        }
        
    }];
    
}

- (IBAction)tableControlAction:(NSSegmentedControl *)sender
{
    NSUInteger clicked = sender.selectedSegment;
    
    switch (clicked)
    {
        case 0:
            [self.queueArrayController removeObjectsAtArrangedObjectIndexes:self.queueArrayController.selectionIndexes];
            break;
        case 1:
            [self.captureObj back];
            break;
        case 2:
            if (!self.captureObj.player.playing)// || self.captureObj.player.paused)
            {
                [self.captureObj play];
            } else {
                [self.captureObj pause];
            }
            break;
        case 3:
            [self.captureObj next];
            break;
    }
}

- (IBAction)manualAddItem:(id)sender
{
    if (self.stringItem)
    {
        [self.captureObj queuePath:self.stringItem];
        self.stringItem = nil;
    }
}




-(void)pauseStateChanged
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.captureObj.player.paused)
        {
            NSImage *playImage = [[NSBundle bundleForClass:[self class]] imageForResource:@"play"];
            
            [self.playlistControl setImage:playImage forSegment:2];
            
        } else {
            NSImage *pauseImage = [[NSBundle bundleForClass:[self class]] imageForResource:@"pause"];
            
            [self.playlistControl setImage:pauseImage forSegment:2];
            
        }
    });
    

}
- (IBAction)sliderValueChanged:(id)sender
{
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    BOOL startingDrag = event.type == NSLeftMouseDown;
    BOOL endingDrag = event.type == NSLeftMouseUp;
    
    
    if (startingDrag) {
        self.captureObj.updateMovieTime = NO;
        [self.captureObj mute];
    }
    
    
    if (endingDrag) {
        self.captureObj.updateMovieTime = YES;
        [self.captureObj mute];
    }
}
    

@end
