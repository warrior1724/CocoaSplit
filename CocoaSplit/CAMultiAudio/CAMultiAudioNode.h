//
//  CAMultiAudioNode.h
//  CocoaSplit
//
//  Created by Zakk on 11/13/14.
//

#import <AppKit/AppKit.h>

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <JavaScriptCore/JavaScriptCore.h>


@class CAMultiAudioGraph;
@class CAMultiAudioDownmixer;
@class CAMultiAudioMatrixMixerWindowController;
@class CAMultiAudioDelay;
@class CAMultiAudioNode;
@class CAMultiAudioEqualizer;
@class CAMultiAudioEngine;

@interface CAMultiAudioVolumeAnimation : NSAnimation

@property (assign) float target_volume;
@property (assign) float original_volume;

@end

@protocol CAMultiAudioNodeJSExport <JSExport>
@property (assign) AudioUnit audioUnit;
@property (assign) int channelCount;
@property (readonly) UInt32 inputElement;
@property (readonly) UInt32 outputElement;
@property (weak) CAMultiAudioGraph *graph;

@property (strong) NSString *name;
@property (strong) NSString *nodeUID;
@property (assign) float volume;
@property (assign) bool muted;
@property (assign) bool enabled;

-(instancetype)initWithSubType:(OSType)subType unitType:(OSType)unitType;
-(instancetype)initWithSubType:(OSType)subType unitType:(OSType)unitType manufacturer:(OSType)manufacturer;

-(bool)createNode:(void(^)(void))completionHandler;
-(bool)createNode;

-(void)willConnectToNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)connectedToNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)nodeConnected:(CAMultiAudioNode *)toNode inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)willConnectNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus;

-(void)willInitializeNode;
-(void)didInitializeNode;
-(bool)setInputStreamFormat:(AVAudioFormat *)format bus:(UInt32)bus;
-(bool)setOutputStreamFormat:(AVAudioFormat *)format bus:(UInt32)bus;
-(AVAudioFormat *)outputFormatForBus:(UInt32)bus;
-(AVAudioFormat *)inputFormatForBus:(UInt32)bus;
-(void)rebuildEffectChain;

-(void)setVolumeAnimated:(float)volume withDuration:(float)duration;
-(NSView *)audioUnitNSView;
-(void)saveDataToDict:(NSMutableDictionary *)saveDict;
-(void)restoreDataFromDict:(NSDictionary *)restoreDict;


@end

@interface CAMultiAudioNode : NSObject <CAMultiAudioNodeJSExport, NSAnimationDelegate>
{
    float _saved_volume;
    
    AudioComponentDescription unitDescr;
    CAMultiAudioVolumeAnimation *_volumeAnimation;
    NSMutableArray *_currentEffectChain;
}

@property (assign) AudioUnit audioUnit;
@property (assign) int channelCount;
@property (readonly) UInt32 inputElement;
@property (readonly) UInt32 outputElement;

@property (weak) CAMultiAudioGraph *graph;
@property (weak) CAMultiAudioEngine *engine;

@property (strong) NSString *name;
@property (strong) NSString *nodeUID;
@property (weak) CAMultiAudioNode *headNode;
@property (weak) CAMultiAudioNode *effectsHead;
@property (strong) NSMutableArray *effectChain;
@property (assign) bool deleteNode;
@property (readonly) NSString *uuid;
@property (strong) NSMutableDictionary *inputConnections;
@property (strong) NSMutableDictionary *outputConnections;

@property (readonly) CAMultiAudioNode *connectedTo;


@property (assign) float volume;
@property (assign) bool muted;

@property (assign) bool enabled;
@property (assign) double theta;


-(instancetype)initWithSubType:(OSType)subType unitType:(OSType)unitType;
-(instancetype)initWithSubType:(OSType)subType unitType:(OSType)unitType manufacturer:(OSType)manufacturer NS_DESIGNATED_INITIALIZER;
-(void)willConnectToNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)connectedToNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)nodeConnected:(CAMultiAudioNode *)toNode inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)willConnectNode:(CAMultiAudioNode *)node inBus:(UInt32)inBus outBus:(UInt32)outBus;
-(void)setupEffectsChain;
-(void)removeEffectsChain;
-(void)addEffect:(CAMultiAudioNode *)effect;
-(void)addEffect:(CAMultiAudioNode *)effect atIndex:(NSUInteger)idx;
-(void)generateTone;
-(void)reset;



@end
