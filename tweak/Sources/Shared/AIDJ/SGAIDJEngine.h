#import <Foundation/Foundation.h>

@interface SGAIDJEngine : NSObject

+ (instancetype)sharedEngine;

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, copy, readonly) NSString *apiEndpoint;
@property (nonatomic, copy, readonly) NSString *modelName;

- (void)generateSessionForPrompt:(NSString *)prompt
                   includeCurrent:(BOOL)includeCurrent
                       completion:(void (^)(NSString *djMessage, NSArray<NSString *> *trackURIs, NSError *error))completion;

- (void)queueTracks:(NSArray<NSString *> *)trackURIs;

@end
