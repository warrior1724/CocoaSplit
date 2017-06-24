//
//  SourceLayout.m
//  CocoaSplit
//
//  Created by Zakk on 8/31/14.
//  Copyright (c) 2014 Zakk. All rights reserved.
//

#import "SourceLayout.h"
#import "InputSource.h"
#import "CaptureController.h"
#import "CSTransitionAnimationDelegate.h"
#import "CSCaptureBase+TimerDelegate.h"



@implementation SourceLayout


@synthesize isActive = _isActive;
@synthesize frameRate = _frameRate;
@synthesize layoutTimingSource = _layoutTimingSource;

-(instancetype) init
{
    if (self = [super init])
    {
        _sourceDepthSorter = [[NSSortDescriptor alloc] initWithKey:@"depth" ascending:YES];
        _sourceUUIDSorter = [[NSSortDescriptor alloc] initWithKey:@"uuid" ascending:YES];
        self.sourceCache = [[SourceCache alloc] init];
        _frameRate = 30;
        _canvas_height = 720;
        _canvas_width = 1280;
        _fboTexture = 0;
        _rFbo = 0;
        _uuidMap = [NSMutableDictionary dictionary];
        _uuidMapPresentation = [NSMutableDictionary dictionary];
        
        _transitionScripts = [NSMutableDictionary dictionary];
        
        _pendingScripts = [NSMutableDictionary dictionary];
        
        _animationQueue = dispatch_queue_create("CSAnimationQueue", NULL);
        _containedLayouts = [[NSMutableArray alloc] init];
        _noSceneTransactions = NO;
        _topLevelSourceArray = [[NSMutableArray alloc] init];
        self.rootLayer = [self newRootLayer];
        
        //self.rootLayer.geometryFlipped = YES;
        _rootSize = NSMakeSize(_canvas_width, _canvas_height);
        self.sourceList = [NSMutableArray array];
        self.sourceListPresentation = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputAttachEvent:) name:CSNotificationInputAttached object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputAttachEvent:) name:CSNotificationInputDetached object:nil];

        
        
    }
    
    return self;
}


-(void)setLayoutTimingSource:(InputSource *)layoutTimingSource
{
    CSCaptureBase *currentTiming = (CSCaptureBase *)_layoutTimingSource.videoInput;
    
    if (currentTiming.timerDelegate)
    {
        [currentTiming.timerDelegate frameTimerWillStop:currentTiming.timerDelegateCtx];
    }
    
    
    _layoutTimingSource = layoutTimingSource;
}


-(InputSource *)layoutTimingSource
{
    return _layoutTimingSource;
}


-(void)inputAttachEvent:(NSNotification *)notification
{
    InputSource *src = notification.object;
    if (src.sourceLayout == self)
    {
        [self generateTopLevelSourceList];
    }
}


-(CALayer *)newRootLayer
{
    CALayer *newRoot = [CALayer layer];
    [CATransaction begin];
    newRoot.bounds = CGRectMake(0, 0, _canvas_width, _canvas_height);
    newRoot.anchorPoint = CGPointMake(0.0, 0.0);
    newRoot.position = CGPointMake(0.0, 0.0);
    newRoot.masksToBounds = YES;
    newRoot.backgroundColor = CGColorCreateGenericRGB(0, 0, 0, 1);
    newRoot.layoutManager = [CAConstraintLayoutManager layoutManager];

    //newRoot.autoresizingMask = kCALayerMinXMargin | kCALayerWidthSizable | kCALayerMaxXMargin | kCALayerMinYMargin | kCALayerHeightSizable | kCALayerMaxYMargin;
    
    
    newRoot.delegate = self;
    [CATransaction commit];

    return newRoot;
    
}

-(NSString *)MIDIIdentifier
{
    return [NSString stringWithFormat:@"Layout:%@", self.name];
}


-(MIKMIDIResponderType)MIDIResponderTypeForCommandIdentifier:(NSString *)commandID
{
    return MIKMIDIResponderTypeButton;
}

-(BOOL)respondsToMIDICommand:(MIKMIDICommand *)command
{
    return YES;
}

-(void)handleMIDICommand:(MIKMIDICommand *)command forIdentifier:(NSString *)identifier
{
    
    
    __weak SourceLayout *weakSelf = self;
    
    
}


-(NSArray *)commandIdentifiers
{
    
    NSMutableArray *ret = [NSMutableArray array];
    
    
    return ret;
}








-(NSString *)runAnimationString:(NSString *)animationCode withCompletionBlock:(void (^)(void))completionBlock withExceptionBlock:(void (^)(NSException *exception))exceptionBlock withExtraDictionary:(NSDictionary *)extraDictionary
{
    if (!animationCode)
    {
        return nil;
    }
    
    NSMutableDictionary *animMap = @{@"animationString": animationCode}.mutableCopy;
    if (completionBlock)
    {
        [animMap setObject:completionBlock forKey:@"completionBlock"];
    }
    
    if (exceptionBlock)
    {
        [animMap setObject:exceptionBlock forKey:@"exceptionBlock"];
        
    }
    
    if (extraDictionary)
    {
        [animMap setObject:extraDictionary forKey:@"extraDictionary"];
    }
    
    CFUUIDRef tmpUUID = CFUUIDCreate(NULL);
    NSString *runUUID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, tmpUUID);
    CFRelease(tmpUUID);
    
    [animMap setObject:runUUID forKey:@"runUUID"];
    

    //[self doAnimation:animMap];
    
    NSThread *runThread = [[NSThread alloc] initWithTarget:self selector:@selector(doAnimation:) object:animMap];
    [runThread start];
    return runUUID;
    

    
    
}



-(void)cancelScriptRun:(NSString *)runUUID
{
    if (self.pendingScripts[runUUID])
    {
        NSDictionary *pendingAnimations = self.pendingScripts[runUUID];
        
        for (NSString *anim_key in pendingAnimations)
        {
            CALayer *target = pendingAnimations[anim_key];
            [target removeAnimationForKey:anim_key];
        }
        [self.pendingScripts removeObjectForKey:runUUID];
    }
    
    [self cancelTransition];
    
}


-(void)doAnimation:(NSDictionary *)threadDict
{
    
    CSAnimationRunnerObj *runner = [CaptureController sharedAnimationObj];

    NSString *modName = threadDict[@"moduleName"];
    NSDictionary *inpMap = threadDict[@"inputs"];
    CALayer *rootLayer = threadDict[@"rootLayer"];
    NSString *animationCode = threadDict[@"animationString"];
    NSString *runUUID = threadDict[@"runUUID"];
    NSDictionary *extraDictRO = threadDict[@"extraDictionary"];
    NSMutableDictionary *extraDict = nil;
    if (extraDictRO)
    {
        extraDict = extraDictRO.mutableCopy;
    } else {
        extraDict = [NSMutableDictionary dictionary];
    }
    
    extraDict[@"__default_animation_time__"] = @([CaptureController sharedCaptureController].transitionDuration);
    
    
    void (^completionBlock)(void) = [threadDict objectForKey:@"completionBlock"];
    void (^exceptionBlock)(NSException *exception) = [threadDict objectForKey:@"exceptionBlock"];
    
    JSContext *jsCtx = [[CaptureController sharedCaptureController] setupJavascriptContext];
    
    //@try {

            [CATransaction begin];
            [CATransaction setCompletionBlock:^{
                [self.pendingScripts removeObjectForKey:runUUID];
                if (completionBlock)
                {
                    completionBlock();
                }
                
            }];
        
        if (animationCode)
        {
            jsCtx[@"extraDict"] = extraDict;
            jsCtx[@"useLayout"] = self;
            
            NSLog(@"RUN ANIMATION CODE %@", animationCode);
            
           // runAnimationForLayoutWithExtraDictionary = function(animation_string, layout, extraDictionary) {
            JSValue *runFunc = jsCtx[@"runAnimationForLayoutWithExtraDictionary"];
            JSValue *scriptRet = [runFunc callWithArguments:@[animationCode, self, extraDict]];
                                  

        
            NSLog(@"SCRIPT RET %@", scriptRet);
            NSDictionary *pendingAnimations = scriptRet.toDictionary;
            
            //NSDictionary *pendingAnimations = [runner runAnimation:animationCode forLayout:self withExtraDictionary:extraDict];
            self.pendingScripts[runUUID] = pendingAnimations;
        } else {
            [runner runAnimation:modName forLayout:self  withSuperlayer:rootLayer];
        }
    //}
    /*
    @catch (NSException *exception) {
        
        [self.pendingScripts removeObjectForKey:runUUID];

        if (exceptionBlock)
        {
            exceptionBlock(exception);
        }
        
        NSLog(@"Animation module %@ failed with exception: %@: %@", modName, [exception name], [exception reason]);
    }
    @finally {*/
            [CATransaction commit];

        //[CATransaction flush];
    //}
}







-(id)copyWithZone:(NSZone *)zone
{
    SourceLayout *newLayout = [[SourceLayout allocWithZone:zone] init];
    
    newLayout.savedSourceListData = self.savedSourceListData;
    newLayout.name = self.name;
    newLayout.canvas_height = self.canvas_height;
    newLayout.canvas_width = self.canvas_width;
    newLayout.frameRate = self.frameRate;
    newLayout.isActive = NO;
    newLayout.containedLayouts = self.containedLayouts.mutableCopy;
    newLayout.audioData = self.audioData;
    return newLayout;
}




-(void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    
    if (self.doSaveSourceList)
    {
        [self saveSourceList];
    }
    
    
    
    [aCoder encodeObject:self.savedSourceListData forKey:@"savedSourceData"];
    [aCoder encodeInt:self.canvas_width forKey:@"canvas_width"];
    [aCoder encodeInt:self.canvas_height forKey:@"canvas_height"];
    [aCoder encodeFloat:self.frameRate forKey:@"frameRate"];
    [aCoder encodeObject:self.transitionScripts forKey:@"transitionScripts"];
    
    if (self.containedLayouts)
    {
        [aCoder encodeObject:self.containedLayouts forKey:@"containedLayouts"];
    }
    
    if (self.audioData)
    {
        [aCoder encodeObject:self.audioData forKey:@"audioData"];
    }
    
    [aCoder encodeBool:self.recordingLayout forKey:@"recordingLayout"];
}





-(id) initWithCoder:(NSCoder *)aDecoder
{
    if (self = [self init])
    {
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.savedSourceListData = [aDecoder decodeObjectForKey:@"savedSourceData"];
        if ([aDecoder containsValueForKey:@"canvas_height"])
        {
            self.canvas_height = [aDecoder decodeIntForKey:@"canvas_height"];
        }
        
        if ([aDecoder containsValueForKey:@"canvas_width"])
        {
            self.canvas_width = [aDecoder decodeIntForKey:@"canvas_width"];
        }
        
        if ([aDecoder containsValueForKey:@"frameRate"])
        {
            self.frameRate = [aDecoder decodeFloatForKey:@"frameRate"];
        }
        
    
        if ([aDecoder containsValueForKey:@"transitionScripts"])
        {
            self.transitionScripts = [[aDecoder decodeObjectForKey:@"transitionScripts"] mutableCopy];
        }
        
        if ([aDecoder containsValueForKey:@"containedLayouts"])
        {
            self.containedLayouts = [[aDecoder decodeObjectForKey:@"containedLayouts"] mutableCopy];
            //set live/staging status for each layout
        }
        
        if ([aDecoder containsValueForKey:@"audioData"])
        {
            self.audioData = [aDecoder decodeObjectForKey:@"audioData"];
        }

        self.recordingLayout = [aDecoder decodeBoolForKey:@"recordingLayout"];
        
    }
    
    return self;
}



-(float)frameRate
{
    return _frameRate;
}


-(void)setFrameRate:(float)frameRate
{
    float oldframerate = _frameRate;
    
    _frameRate = frameRate;
    
    if (_frameRate != oldframerate)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationLayoutFramerateChanged object:self userInfo:nil];
    }
}



-(void)applyAddBlock
{
    if (self.addLayoutBlock)
    {
        for (SourceLayout *layout in self.containedLayouts)
        {
            self.addLayoutBlock(layout);
        }
    }
}


-(void)generateTopLevelSourceList
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self willChangeValueForKey:@"topLevelSourceList"];

        [_topLevelSourceArray removeAllObjects];
        for (InputSource *src in self.sourceListOrdered)
        {
            if (!src.parentInput)
            {
                [_topLevelSourceArray addObject:src];
            }
        }
        [self didChangeValueForKey:@"topLevelSourceList"];

    });
}


-(NSArray *)topLevelSourceList
{
    
    return _topLevelSourceArray;
    
}


-(NSString *)description
{
    return self.name;
}


-(NSArray *)sourceListOrdered
{
    NSArray *mylist;
    
    @synchronized(self)
    {
        mylist = self.sourceList;
    }
    
    
    NSArray *listCopy = [mylist sortedArrayUsingDescriptors:@[_sourceDepthSorter, _sourceUUIDSorter]];
    return listCopy;
}


-(InputSource *)findSource:(NSPoint)forPoint withExtra:(float)withExtra deepParent:(bool)deepParent
{
    /* invert the point due to layer rendering inversion/weirdness */
    
    CGPoint newPoint = CGPointMake(forPoint.x, self.canvas_height-forPoint.y);
    CALayer *foundLayer = [self.rootLayer hitTest:newPoint];
    
    InputSource *retInput = nil;
    
    if (foundLayer && [foundLayer isKindOfClass:[CSInputLayer class]])
    {
        retInput = ((CSInputLayer *)foundLayer).sourceInput;
    }
    

    if (deepParent)
    {
        while (retInput && retInput.parentInput && NSEqualRects(retInput.globalLayoutPosition, ((InputSource *)retInput.parentInput).globalLayoutPosition))
        {
            retInput = retInput.parentInput;
        }
    }
    
    
    return retInput;

}


-(void) resetAllRefCounts
{
    for (InputSource *src in self.sourceList)
    {
        src.refCount = 1;
    }
    
}




-(NSInteger)incrementInputRef:(InputSource *)input
{
    
    input.refCount++;
    
    return input.refCount;
}

-(NSInteger)decrementInputRef:(InputSource *)input
{
    
    input.refCount--;
    
    if (input.refCount < 0)
    {
        input.refCount = 0;
    }
    
    return input.refCount;
}


-(InputSource *)findSource:(NSPoint)forPoint deepParent:(bool)deepParent
{
    
    return [self findSource:forPoint withExtra:0 deepParent:deepParent];
}


-(NSData *)makeSaveData
{
    NSObject *timerSrc = self.layoutTimingSource;
    if (!timerSrc)
    {
        timerSrc = [NSNull null];
    }
    
    
    
    NSDictionary *saveDict = @{@"sourcelist": self.sourceList,  @"timingSource": timerSrc};
    NSMutableData *saveData = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:saveData];
    archiver.delegate = self;
    [archiver encodeObject:saveDict forKey:@"root"];
    [archiver finishEncoding];
    
    return saveData;
}


-(void) saveSourceList
{
    
    NSData *saveData = [self makeSaveData];
    self.savedSourceListData = saveData;
    [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationLayoutSaved object:self userInfo:nil];

}

-(id)archiver:(NSKeyedArchiver *)archiver willEncodeObject:(id)object
{
    if ([object isKindOfClass:[InputSource class]])
    {
        InputSource *src = (InputSource *)object;
        if (src.skipSave)
        {
            return nil;
        }
    }
    
    return object;
}


-(NSDictionary *)diffSourceListWithData:(NSData *)useData
{
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:useData];
    
    [unarchiver setDelegate:self];
    
    NSObject *mergeObj = [unarchiver decodeObjectForKey:@"root"];
    [unarchiver finishDecoding];
    
    NSArray *mergeList;
    
    NSLog(@"MERGE OBJ %@", mergeObj);
    
    if ([mergeObj isKindOfClass:[NSDictionary class]])
    {
        mergeList = [((NSDictionary *)mergeObj) objectForKey:@"sourcelist"];
    } else {
        mergeList = (NSArray *)mergeObj;
    }

    
    
    NSMutableDictionary *uuidMap = [NSMutableDictionary dictionary];
    
    NSMutableDictionary *retDict = [NSMutableDictionary dictionary];
    
    [retDict setObject:[NSMutableArray array] forKey:@"new"];
    [retDict setObject:[NSMutableArray array] forKey:@"changed"];
    [retDict setObject:[NSMutableArray array] forKey:@"same"];

    [retDict setObject:[NSMutableArray array] forKey:@"removed"];
    
    for (InputSource *oSrc in mergeList)
    {
        [uuidMap setObject:oSrc forKey:oSrc.uuid];
        
        InputSource *eSrc = [self inputForUUID:oSrc.uuid];
        if (eSrc)
        {
            if ([eSrc isDifferentInput:oSrc])
            {
                [retDict[@"changed"] addObject:oSrc];
                
            } else {
                [retDict[@"same"] addObject:oSrc];
            }
        } else {
            [retDict[@"new"] addObject:oSrc];
        }
        
    }
    
    for (InputSource *sSrc in self.sourceList)
    {
    
        InputSource *oSrc = [uuidMap objectForKey:sSrc.uuid];
        if (!oSrc)
        {
            [retDict[@"removed"] addObject:sSrc];

        }
    }

    return retDict;
    
}


-(void)undoReplaceSourceLayout:(NSData *)layoutData withContainedLayouts:(NSArray *)containedLayouts
{
    [self replaceWithSourceData:layoutData withCompletionBlock:nil];
    
    for (SourceLayout *cLayout in containedLayouts)
    {
        if (self.removeLayoutBlock)
        {
            self.removeLayoutBlock(cLayout);
        }
        
    }

    if (self.addLayoutBlock)
    {
        for (SourceLayout *newCont in containedLayouts)
        {
            self.addLayoutBlock(newCont);
        }
    }
}


-(void)replaceWithSourceLayoutViaScript:(SourceLayout *)layout withCompletionBlock:(void (^)(void))completionBlock withExceptionBlock:(void (^)(NSException *exception))exceptionBlock
{
    NSString *replaceScript = @"switchToLayout(extraDict['toLayout']);";
    NSDictionary *extraDict = @{@"toLayout": layout};
    [self runAnimationString:replaceScript withCompletionBlock:completionBlock withExceptionBlock:exceptionBlock withExtraDictionary:extraDict];
}


-(void)replaceWithSourceLayout:(SourceLayout *)layout
{
    
    
    [self replaceWithSourceLayout:layout withCompletionBlock:nil];
}


-(void)replaceWithSourceLayout:(SourceLayout *)layout withCompletionBlock:(void (^)(void))completionBlock
{

    
    
    if (self.undoManager)
    {
        [self.undoManager beginUndoGrouping];
        [self saveSourceList];
        [[self.undoManager prepareWithInvocationTarget:self] undoReplaceSourceLayout:self.savedSourceListData withContainedLayouts:self.containedLayouts.copy];
        [self.undoManager endUndoGrouping];
    }
    
    
    
    for (SourceLayout *cLayout in self.containedLayouts.copy)
    {
        if (self.removeLayoutBlock)
        {
            self.removeLayoutBlock(cLayout);
        }
        
        [self.containedLayouts removeObject:cLayout];
    }

    [self replaceWithSourceData:layout.savedSourceListData withCompletionBlock:completionBlock];
    
    if (self.addLayoutBlock)
    {
        self.addLayoutBlock(layout);
    }
    
    [self.containedLayouts addObject:layout];
    
    for (SourceLayout *cLayout in layout.containedLayouts.copy)
    {
        if (self.addLayoutBlock)
        {
            self.addLayoutBlock(cLayout);
        }
        
        [self.containedLayouts addObject:cLayout];
    }

    
    [self updateCanvasWidth:layout.canvas_width height:layout.canvas_height];
    self.frameRate = layout.frameRate;
    [self resetAllRefCounts];

}


-(void)replaceWithSourceData:(NSData *)sourceData withCompletionBlock:(void (^)(void))completionBlock
{
    NSDictionary *diffResult = [self diffSourceListWithData:sourceData];
    NSMutableArray *changedRemove = [NSMutableArray array];
    
    NSArray *changedInputs = diffResult[@"changed"];
    NSArray *removedInputs = diffResult[@"removed"];
    NSArray *sameInputs = diffResult[@"same"];
    NSArray *newInputs = diffResult[@"new"];
    
    NSNumber *aStart = nil;
    
    NSDictionary *blockObj = [CATransaction valueForKey:@"__CS_BLOCK_OBJECT__"];
    if (blockObj)
    {
            aStart = blockObj[@"current_begin_time"];
        if ([aStart isEqual:[NSNull null]])
        {
            aStart = [NSNumber numberWithDouble:CACurrentMediaTime()];
        }
    }
    
    
    CATransition *rTrans = nil;
    CABasicAnimation *bTrans = nil;
    
    CSTransitionAnimationDelegate *transitionDelegate = [[CSTransitionAnimationDelegate alloc] init];
    transitionDelegate.addedInputs = newInputs;
    transitionDelegate.changedInputs = changedInputs;
    transitionDelegate.removedInputs = removedInputs;
    
    
    if (self.transitionName || self.transitionFilter)
    {
        rTrans = [CATransition animation];
        
        if (aStart)
        {
            [rTrans setBeginTime:aStart.floatValue];
        }
        
        
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.removedOnCompletion = YES;
        rTrans.subtype = self.transitionDirection;
        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
        
    }
    //We always create a dummy animation so we play nice with scripts that do additional animations. This way we don't do final remove/reveal until the proper time
    NSString *dummyKey = [NSString stringWithFormat:@"__DUMMY_KEY_%f", aStart.floatValue];
    bTrans = [CABasicAnimation animationWithKeyPath:dummyKey];
    bTrans.removedOnCompletion = YES;
    bTrans.fillMode = kCAFillModeForwards;
    bTrans.beginTime = aStart.floatValue;
    if (rTrans)
    {
        bTrans.duration = self.transitionDuration;
    }
    transitionDelegate.useAnimation = rTrans;
    
    bTrans.fromValue = @0;
    bTrans.toValue = @1;
    bTrans.delegate = transitionDelegate;
    if (aStart)
    {
        bTrans.beginTime = aStart.floatValue;
    }
    
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        
        
        for (InputSource *rSrc in removedInputs)
        {
            [self deleteSource:rSrc];
        }
        
        for (InputSource *cSrc in changedRemove)
        {
            if (cSrc)
            {
                [self deleteSource:cSrc];
            }
        }
        
        if (completionBlock)
        {
            completionBlock();
        }
    }];
    
    
    if (bTrans)
    {
        transitionDelegate.forLayout = self;
        transitionDelegate.fullScreen = self.transitionFullScene;
        
        [self.rootLayer addAnimation:bTrans forKey:bTrans.keyPath];
    }
    
    
    for (InputSource *rSrc in removedInputs)
    {
        [self deleteSourceFromPresentation:rSrc];
    }
    
    for (InputSource *cSrc in changedInputs)
    {
        InputSource *mSrc = [self inputForUUID:cSrc.uuid];
        
        
        [self deleteSourceFromPresentation:mSrc];
        [changedRemove addObject:mSrc];
        
        cSrc.layer.hidden = YES;
        
        
        [self addSource:cSrc withParentLayer:mSrc.layer.superlayer];
        
    }
    transitionDelegate.changeremoveInputs = changedRemove;
    
    for (InputSource *nSrc in newInputs)
    {
        
        nSrc.layer.hidden = YES;
        
        [self addSource:nSrc];
        
    }
    
    
    
    
    
    [CATransaction commit];
    
    [CATransaction flush];
    _noSceneTransactions = NO;
    
    
}


-(bool)containsLayoutNamed:(NSString *)layoutName
{
    for (SourceLayout *clayout in self.containedLayouts)
    {
        if ([clayout.name isEqualToString:layoutName])
        {
            return YES;
        }
    }
    
    return NO;
}

-(bool)containsLayout:(SourceLayout *)layout
{
    return [self.containedLayouts containsObject:layout];
}





-(void)mergeSourceLayoutViaScript:(SourceLayout *)layout
{
    NSString *mergeScript = @"mergeLayout(extraDict['toLayout']);";
    
    NSDictionary *extraDict = @{@"toLayout": layout};
    [self runAnimationString:mergeScript withCompletionBlock:nil withExceptionBlock:nil withExtraDictionary:extraDict];
}


-(void)mergeSourceLayout:(SourceLayout *)toMerge
{
    [self mergeSourceLayout:toMerge withCompletionBlock:nil];
}

-(void)mergeSourceLayout:(SourceLayout *)toMerge withCompletionBlock:(void (^)(void))completionBlock
{
    
    if ([self.containedLayouts containsObject:toMerge])
    {
        return;
    }

    
    [self mergeSourceData:toMerge.savedSourceListData withCompletionBlock:completionBlock];
    
    
    if (self.undoManager)
    {
        [self.undoManager beginUndoGrouping];
        [[self.undoManager prepareWithInvocationTarget:self] removeSourceLayout:toMerge];
        [self.undoManager endUndoGrouping];
    }
    
    
    [self.containedLayouts addObject:toMerge];
    if (self.addLayoutBlock)
    {
        self.addLayoutBlock(toMerge);
    }

}


-(void)mergeSourceData:(NSData *)withData withCompletionBlock:(void (^)(void))completionBlock
{
    
    NSDictionary *diffResult = [self diffSourceListWithData:withData];
    NSMutableArray *changedRemove = [NSMutableArray array];
    
    NSArray *changedInputs = diffResult[@"changed"];
    NSArray *removedInputs = diffResult[@"removed"];
    NSArray *sameInputs = diffResult[@"same"];
    NSArray *newInputs = diffResult[@"new"];
    
    NSNumber *aStart = nil;
    
    NSDictionary *blockObj = [CATransaction valueForKey:@"__CS_BLOCK_OBJECT__"];
    if (blockObj)
    {
        aStart = blockObj[@"current_begin_time"];
        if ([aStart isEqual:[NSNull null]])
        {
            aStart = [NSNumber numberWithDouble:CACurrentMediaTime()];
        }
    }
    
    
    CATransition *rTrans = nil;
    CABasicAnimation *bTrans = nil;
    CSTransitionAnimationDelegate *transitionDelegate = [[CSTransitionAnimationDelegate alloc] init];
    transitionDelegate.addedInputs = newInputs;
    transitionDelegate.changedInputs = changedInputs;
    
    
    
    if (self.transitionName || self.transitionFilter)
    {
        rTrans = [CATransition animation];
        
        if (aStart)
        {
            [rTrans setBeginTime:aStart.floatValue];
        }
        
        
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.removedOnCompletion = YES;
        rTrans.subtype = self.transitionDirection;
        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
        
    }
    
    //We always create a dummy animation so we play nice with scripts that do additional animations. This way we don't do final remove/reveal until the proper time
    NSString *dummyKey = [NSString stringWithFormat:@"__DUMMY_KEY_%f", aStart.floatValue];
    bTrans = [CABasicAnimation animationWithKeyPath:dummyKey];
    bTrans.removedOnCompletion = YES;
    bTrans.fillMode = kCAFillModeForwards;
    if (aStart)
    {
        bTrans.beginTime = aStart.floatValue;
    }
    bTrans.fromValue = @0;
    bTrans.toValue = @1;
    if (rTrans)
    {
        bTrans.duration = self.transitionDuration;
    }
    transitionDelegate.useAnimation = rTrans;
    bTrans.delegate = transitionDelegate;
    
    
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        
        for (InputSource *cSrc in changedRemove)
        {
            [self deleteSource:cSrc];
        }
        
        if (bTrans)
        {
            for (InputSource *nSrc in newInputs)
            {
                nSrc.layer.hidden = NO;
            }
            
            for (InputSource *cSrc in changedInputs)
            {
                cSrc.layer.hidden = NO;
            }
            
            
            
        }
        
        
        if (completionBlock)
        {
            completionBlock();
        }
        
        
    }];
    
    if (bTrans)
    {
        transitionDelegate.forLayout = self;
        transitionDelegate.fullScreen = self.transitionFullScene;
        
        [self.rootLayer addAnimation:bTrans forKey:bTrans.keyPath];
    }
    
    
    for (InputSource *nSrc in newInputs)
    {
        
        nSrc.layer.hidden = YES;
        [self addSource:nSrc];
        
    }
    
    for (InputSource *cSrc in changedInputs)
    {
        InputSource *mSrc = [self inputForUUID:cSrc.uuid];
        [self deleteSourceFromPresentation:mSrc];
        [changedRemove addObject:mSrc];
        
        
        cSrc.layer.hidden = YES;
        
        [self addSource:cSrc withParentLayer:mSrc.layer.superlayer];
        [self incrementInputRef:cSrc];
    }
    transitionDelegate.changeremoveInputs = changedRemove;
    
    [CATransaction commit];
    [CATransaction flush];
    
    [self adjustAllInputs];
    
}


-(void)removeSourceLayoutViaScript:(SourceLayout *)layout
{
    NSString *removeScript = @"removeLayout(extraDict['toLayout']);";
    NSDictionary *extraDict = @{@"toLayout": layout};
    [self runAnimationString:removeScript withCompletionBlock:nil withExceptionBlock:nil withExtraDictionary:extraDict];
}

-(void)removeSourceLayout:(SourceLayout *)toRemove
{
    [self removeSourceLayout:toRemove withCompletionBlock:nil];
}

-(void)removeSourceLayout:(SourceLayout *)toRemove withCompletionBlock:(void (^)(void))completionBlock
{
    if (![self.containedLayouts containsObject:toRemove])
    {
        return;
    }

    if (self.undoManager)
    {
        [self.undoManager beginUndoGrouping];
        [[self.undoManager prepareWithInvocationTarget:self] mergeSourceLayout:toRemove];
        [self.undoManager endUndoGrouping];
    }

    [self removeSourceData:toRemove.savedSourceListData withCompletionBlock:completionBlock];
    
    [self.containedLayouts removeObject:toRemove];
    if (self.removeLayoutBlock)
    {
        self.removeLayoutBlock(toRemove);
    }

}


-(void)removeSourceData:(NSData *)toRemove withCompletionBlock:(void (^)(void))completionBlock
{
    
    
    NSDictionary *diffResult = [self diffSourceListWithData:toRemove];
    
    NSMutableArray *realRemove = [NSMutableArray array];
    
    NSArray *changedInputs = diffResult[@"changed"];
    NSArray *sameInputs = diffResult[@"same"];
    NSArray *newInputs = diffResult[@"new"];
    
    NSMutableArray *removeInputs = [NSMutableArray arrayWithArray:changedInputs];
    [removeInputs addObjectsFromArray:sameInputs];
    [removeInputs addObjectsFromArray:newInputs];
    NSNumber *aStart = nil;
    
    NSDictionary *blockObj = [CATransaction valueForKey:@"__CS_BLOCK_OBJECT__"];
    if (blockObj)
    {
        aStart = blockObj[@"current_begin_time"];
        if ([aStart isEqual:[NSNull null]])
        {
            aStart = [NSNumber numberWithDouble:CACurrentMediaTime()];
        }
    }
    
    
    CATransition *rTrans = nil;
    CABasicAnimation *bTrans = nil;
    
    CSTransitionAnimationDelegate *transitionDelegate = [[CSTransitionAnimationDelegate alloc] init];
    
    
    if (self.transitionName || self.transitionFilter)
    {
        rTrans = [CATransition animation];
        
        if (aStart)
        {
            [rTrans setBeginTime:aStart.floatValue];
        }
        
        
        rTrans.type = self.transitionName;
        rTrans.duration = self.transitionDuration;
        rTrans.removedOnCompletion = YES;
        rTrans.subtype = self.transitionDirection;
        if (self.transitionFilter)
        {
            rTrans.filter = self.transitionFilter;
        }
    }
    
    
    //We always create a dummy animation so we play nice with scripts that do additional animations. This way we don't do final remove/reveal until the proper time
    NSString *dummyKey = [NSString stringWithFormat:@"__DUMMY_KEY_%f", aStart.floatValue];
    bTrans = [CABasicAnimation animationWithKeyPath:dummyKey];
    bTrans.removedOnCompletion = YES;
    bTrans.fillMode = kCAFillModeForwards;
    if (aStart)
    {
        bTrans.beginTime = aStart.floatValue;
    }
    bTrans.fromValue = @0;
    bTrans.toValue = @1;
    if (rTrans)
    {
        bTrans.duration = self.transitionDuration;
    }
    transitionDelegate.useAnimation = rTrans;
    bTrans.delegate = transitionDelegate;
    
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        
        
        for (InputSource *rSrc in realRemove)
        {
            [self decrementInputRef:rSrc];
            [self deleteSource:rSrc];
        }
        
        if (completionBlock)
        {
            completionBlock();
        }
    }];
    
    
    if (bTrans)
    {
        transitionDelegate.forLayout = self;
        transitionDelegate.fullScreen = self.transitionFullScene;
        
        [self.rootLayer addAnimation:bTrans forKey:bTrans.keyPath];
    }
    
    
    if (self.transitionFullScene)
    {
        [self.rootLayer addAnimation:rTrans forKey:nil];
    }
    
    
    for (InputSource *rSrc in removeInputs)
    {
        InputSource *eSrc = [self inputForUUID:rSrc.uuid];
        
        if (eSrc)
        {
            [realRemove addObject:eSrc];
            [self deleteSourceFromPresentation:eSrc];
        }
        
        transitionDelegate.removedInputs = realRemove;
    }
    [CATransaction commit];
    
}








-(void)cancelTransition
{
    [self.rootLayer removeAnimationForKey:kCATransition];
    for (InputSource *src in self.sourceList)
    {
        [src.layer removeAnimationForKey:kCATransition];
    }
}





-(NSObject *)removeSourceListData:(NSData *)mergeData
{
    
    CALayer *withLayer = nil;
    
    if (!self.sourceList)
    {
        return nil;
    }

    if (!mergeData)
    {
        return nil;
    }
    
    if (!withLayer)
    {
        withLayer = self.rootLayer;
    }
    
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:mergeData];
    
    [unarchiver setDelegate:self];
    
    NSObject *mergeObj = [unarchiver decodeObjectForKey:@"root"];
    [unarchiver finishDecoding];
    
    NSArray *mergeList;
    
    if ([mergeObj isKindOfClass:[NSDictionary class]])
    {
        mergeList = [((NSDictionary *)mergeObj) objectForKey:@"sourcelist"];

    } else {
        mergeList = (NSArray *)mergeObj;
    }
    

    //[self removeSourceInputs:mergeList withLayer:withLayer];
    
    return mergeObj;
}


-(void)restoreSourceList:(NSData *)withData
{
    
    if (self.savedSourceListData)
    {
        
        [CATransaction begin];
        
        NSMutableArray *oldSourceList = self.sourceList;
        
        self.sourceList = [NSMutableArray array];
        _uuidMap = [NSMutableDictionary dictionary];
        self.sourceListPresentation = [NSMutableArray array];
        _uuidMapPresentation = [NSMutableDictionary dictionary];

        
        
        if (!withData)
        {
            withData = self.savedSourceListData;
        }
        
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:withData];
        
        [unarchiver setDelegate:self];
        
        NSObject *restData = [unarchiver decodeObjectForKey:@"root"];
        [unarchiver finishDecoding];
        
        NSArray *srcList = nil;
        
        if (restData && [restData isKindOfClass:[NSDictionary class]])
        {
            NSObject *timerSrc = nil;
            timerSrc = [((NSDictionary *)restData) objectForKey:@"timingSource"];
            if (timerSrc == [NSNull null])
            {
                timerSrc = nil;
            }
            
            srcList = [((NSDictionary *)restData) objectForKey:@"sourcelist"];
            
            self.layoutTimingSource = ((InputSource *)timerSrc);
            
            
        } else { 
            srcList = (NSArray *)restData;
        }
        
        
        
        for (InputSource *nSrc in srcList)
        {
            [self addSource:nSrc];
        }
        
        
        for(InputSource *src in oldSourceList)
        {
            [src willDelete];
            [src.layer removeFromSuperlayer];
        }

        
        
        [CATransaction commit];

    }
}


-(bool)containsInput:(InputSource *)cInput
{
    NSArray *listCopy = [self sourceListOrdered];
    
    for (InputSource *testSrc in listCopy)
    {
        if (testSrc == cInput)
        {
            return YES;
        }
    }

    return NO;
}



-(void)deleteSourceFromPresentation:(InputSource *)delSource
{
    @synchronized (self) {
        [self.sourceListPresentation removeObject:delSource];
    }

    InputSource *uSrc;
    
    uSrc = _uuidMapPresentation[delSource.uuid];
    if ([uSrc isEqual:delSource])
    {
        [_uuidMapPresentation removeObjectForKey:delSource.uuid];
    }

}
-(void)deleteSource:(InputSource *)delSource
{
    
    [delSource willDelete];
    
    [self willChangeValueForKey:@"topLevelSourceList"];
    @synchronized (self) {
        [[self mutableArrayValueForKey:@"sourceList" ] removeObject:delSource];
        [self.sourceListPresentation removeObject:delSource];
    }
    [self generateTopLevelSourceList];
    [self didChangeValueForKey:@"topLevelSourceList"];
    

    InputSource *uSrc;
    uSrc = _uuidMap[delSource.uuid];
    if ([uSrc isEqual:delSource])
    {
        [_uuidMap removeObjectForKey:delSource.uuid];
    }
    
    uSrc = _uuidMapPresentation[delSource.uuid];
    if ([uSrc isEqual:delSource])
    {
        [_uuidMapPresentation removeObjectForKey:delSource.uuid];
    }

    //[self.sourceList removeObject:delSource];
    if (delSource == self.layoutTimingSource)
    {
        self.layoutTimingSource = nil;
    }
    
    [delSource.layer removeFromSuperlayer];

    [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationInputDeleted  object:delSource userInfo:nil];
    delSource.sourceLayout = nil;

    
    

}



-(void)setupMIDI
{
    [NSApp registerMIDIResponder:self];
    for (InputSource *src in self.sourceList)
    {
        [NSApp registerMIDIResponder:src];

    }
}


-(void) adjustAllInputs
{
    
    NSArray *copiedInputs = [self sourceListOrdered];
    
    for (InputSource *src in copiedInputs)
    {
        src.needsAdjustPosition = YES;
        src.needsAdjustment = YES;
    }
}



-(void) addSource:(InputSource *)newSource
{
    [self addSource:newSource withParentLayer:self.rootLayer];
}


-(void) addSource:(InputSource *)newSource withParentLayer:(CALayer *)parentLayer
{
    newSource.sourceLayout = self;
    newSource.is_live = self.isActive;
    
    [self.sourceListPresentation addObject:newSource];
    [[self mutableArrayValueForKey:@"sourceList" ] addObject:newSource];
    

    [parentLayer addSublayer:newSource.layer];


    newSource.needsAdjustPosition = NO;
    newSource.needsAdjustment = YES;
    
    
    [_uuidMapPresentation setObject:newSource forKey:newSource.uuid];
    [_uuidMap setObject:newSource forKey:newSource.uuid];
    
    [self incrementInputRef:newSource];
    
    [self generateTopLevelSourceList];
    [NSApp registerMIDIResponder:newSource];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationInputAdded object:newSource userInfo:nil];
}


-(void)clearSourceList
{
    self.rootLayer.sublayers = [NSArray array];
    @synchronized(self)
    {
        [self.sourceList removeAllObjects];
        [self.sourceListPresentation removeAllObjects];
        [self generateTopLevelSourceList];

        
    }
    [_uuidMap removeAllObjects];
    [_uuidMapPresentation removeAllObjects];
}


/*
-(void) setIsActive:(bool)isActive
{
    
    
    bool oldActive = _isActive;
    
    _isActive = isActive;
    
    
    
    if (oldActive == isActive)
    {
        //If the value didn't change don't do anything
        return;
    }
    
    
    if (isActive)
    {
            [self restoreSourceList:nil];
            for(InputSource *src in self.sourceList)
            {
                src.sourceLayout = self;
                
            }

        
    } else {
        [self saveSourceList];
        for(InputSource *src in self.sourceList)
        {
            src.editorController = nil;
            
            
        }
        
        self.rootLayer.sublayers = [NSArray array];
        @synchronized(self)
        {
            [self.sourceList removeAllObjects];

        }
        [self.animationList removeAllObjects];
        self.selectedAnimation = nil;
        
        //self.sourceList = [NSMutableArray array];
    }
}

-(bool) isActive
{
    return _isActive;
}

*/





-(InputSource *)sourceUnder:(InputSource *)source
{
    
    NSRect sourceFrame = source.layer.frame;
    
    InputSource *ret = nil;
    
    NSArray *listCopy = [self sourceListOrdered];

    for (InputSource *src in listCopy)
    {
        if (src == source)
        {
            continue;
        }
        
        NSRect candidateFrame = src.layer.frame;
        
        NSRect tryFrame;
        
        tryFrame = [self.rootLayer convertRect:candidateFrame fromLayer:src.layer.superlayer];

        if (NSIntersectsRect(sourceFrame, tryFrame))
        {
            if (source.layer.zPosition >= src.layer.zPosition)
            {
                if (!ret || src.layer.zPosition > ret.layer.zPosition || src.layer.superlayer == ret.layer)
                {
                    ret = src;
                }
            }
        }
        
    }
    
    return ret;
}


-(id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
    return (id<CAAction>)[NSNull null];
}


-(void)updateCanvasWidth:(int)width height:(int)height 
{
    int old_height = self.canvas_height;
    int old_width = self.canvas_width;
    
    self.canvas_height = height;
    self.canvas_width = width;
    
    if ((old_height != height) || (old_width != width))
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:CSNotificationLayoutCanvasChanged object:self userInfo:nil];
    }
}


-(void)frameTick
{
    @autoreleasepool {
        
        bool needsResize = NO;
        NSSize curSize = NSMakeSize(self.canvas_width, self.canvas_height);
        
        if (!NSEqualSizes(curSize, _rootSize))
        {
            
            self.rootLayer.bounds = CGRectMake(0, 0, self.canvas_width, self.canvas_height);
            _rootSize = curSize;
            needsResize = YES;
        }
        
        
        NSArray *listCopy;
        
        listCopy = [self sourceListOrdered];
        
        
        
        for (InputSource *isource in listCopy)
        {
            if (needsResize)
            {
                isource.needsAdjustPosition = YES;
                isource.needsAdjustment = YES;
            }
            
            if (isource.active)
            {
                [isource frameTick];
            }
            
        }
    }
    
}


-(void)didBecomeVisible
{
    if (self.in_staging)
    {
        return;
    }
    
}



-(void)modifyUUID:(NSString *)uuid withBlock:(void (^)(InputSource *input))withBlock
{
    InputSource *useSource = [self inputForUUID:uuid];
    if (useSource)
    {
        withBlock(useSource);
    }
}




-(InputSource *)inputForName:(NSString *)name
{
    
    NSArray *useList = self.sourceListPresentation;
    
    for (InputSource *tSrc in useList)
    {
        if (tSrc.name && [tSrc.name isEqualToString:name])
        {
            return tSrc;
        }
    }
    return nil;
}


-(InputSource *)inputForUUID:(NSString *)uuid
{
    return [_uuidMapPresentation objectForKey:uuid];
}


-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

@end
