#import "SGAIDJEngine.h"
#import "Core/SGPrefs.h"
#import "Shared/Player/PlayerState.h"

@implementation SGAIDJEngine

+ (instancetype)sharedEngine {
    static SGAIDJEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SGAIDJEngine alloc] init];
    });
    return instance;
}

- (NSString *)apiKey {
    return SGPrefString(@"spotifyglass.ai_dj_api_key", @"");
}

- (NSString *)apiEndpoint {
    NSString *endpoint = SGPrefString(@"spotifyglass.ai_dj_endpoint", @"https://api.openai.com/v1/chat/completions");
    return endpoint.length > 0 ? endpoint : @"https://api.openai.com/v1/chat/completions";
}

- (NSString *)modelName {
    NSString *model = SGPrefString(@"spotifyglass.ai_dj_model", @"gpt-4o-mini");
    return model.length > 0 ? model : @"gpt-4o-mini";
}

- (void)generateSessionForPrompt:(NSString *)prompt
                   includeCurrent:(BOOL)includeCurrent
                       completion:(void (^)(NSString *djMessage, NSArray<NSString *> *trackURIs, NSError *error))completion {
    
    NSString *key = self.apiKey;
    if (key.length == 0) {
        if (completion) {
            completion(nil, nil, [NSError errorWithDomain:@"VitrineAIDJ" code:401 userInfo:@{NSLocalizedDescriptionKey: @"Please set your API key in Mod Settings."}]);
        }
        return;
    }

    NSString *context = @"";
    if (includeCurrent) {
        SGPlayerState *state = [SGPlayerState currentState];
        if (state.trackTitle && state.artistName) {
            context = [NSString stringWithFormat:@"Currently playing: '%@' by '%@'. ", state.trackTitle, state.artistName];
        }
    }

    NSString *systemPrompt = @"You are Spotify DJ / Martini. The user will give a vibe, mood, or prompt. "
                             @"Return STRICT JSON with two keys:\n"
                             @"1. 'dj_message': A short, cool 1-sentence radio host commentary intro.\n"
                             @"2. 'tracks': An array of 5 songs, each an object with 'artist' and 'title'.\n"
                             @"Output ONLY valid JSON without markdown wrapping.";

    NSDictionary *payload = @{
        @"model": self.modelName,
        @"messages": @[
            @{@"role": @"system", @"content": systemPrompt},
            @{@"role": @"user", @"content": [NSString stringWithFormat:@"%@Prompt: %@", context, prompt]}
        ],
        @"temperature": @0.7
    };

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.apiEndpoint]];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, nil, error);
            });
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *content = json[@"choices"][0][@"message"][@"content"];
        
        // Strip markdown fences if present
        content = [content stringByReplacingOccurrencesOfString:@"```json" withString:@""];
        content = [content stringByReplacingOccurrencesOfString:@"```" withString:@""];
        content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSData *parsedData = [content dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:parsedData options:0 error:nil];
        
        NSString *djMessage = parsed[@"dj_message"] ?: @"Here are your custom curated tracks:";
        NSArray *tracks = parsed[@"tracks"] ?: @[];

        [self resolveTracksToURIs:tracks completion:^(NSArray<NSString *> *resolvedURIs) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(djMessage, resolvedURIs, nil);
            });
        }];
    }];
    [task resume];
}

- (void)resolveTracksToURIs:(NSArray *)tracks completion:(void (^)(NSArray<NSString *> *uris))completion {
    NSMutableArray *uris = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();

    for (NSDictionary *t in tracks) {
        NSString *query = [NSString stringWithFormat:@"%@ %@", t[@"title"], t[@"artist"]];
        NSString *escaped = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *searchURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.spotify.com/v1/search?type=track&limit=1&q=%@", escaped]];

        dispatch_group_enter(group);
        // Uses Spotify's internal auth token session
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:searchURL];
        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
            if (data) {
                NSDictionary *resJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSArray *items = resJson[@"tracks"][@"items"];
                if (items.count > 0 && items[0][@"uri"]) {
                    @synchronized(uris) {
                        [uris addObject:items[0][@"uri"]];
                    }
                }
            }
            dispatch_group_leave(group);
        }] resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        completion(uris);
    });
}

- (void)queueTracks:(NSArray<NSString *> *)trackURIs {
    if (trackURIs.count == 0) return;
    id playerCoordinator = [NSClassFromString(@"SPTPlayerFeature") performSelector:NSSelectorFromString(@"currentPlaybackCoordinator")];
    for (NSString *uri in trackURIs) {
        // Appends resolved tracks to Spotify's live playback queue
        if ([playerCoordinator respondsToSelector:NSSelectorFromString(@"queueTrackURI:")]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [playerCoordinator performSelector:NSSelectorFromString(@"queueTrackURI:") withObject:[NSURL URLWithString:uri]];
            #pragma clang diagnostic pop
        }
    }
}

@end
