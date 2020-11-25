
#import "RNMlKit.h"

#import <React/RCTBridge.h>

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseMLVision/FirebaseMLVision.h>
#import <React/RCTImageLoader.h>

@implementation RNMlKit

@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

static NSString *const detectionNoResultsMessage = @"Something went wrong";

RCT_REMAP_METHOD(deviceTextRecognition, deviceTextRecognition:(NSString *)imagePath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (!imagePath) {
        resolve(@NO);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        [[_bridge moduleForName:@"ImageLoader" lazilyLoadIfNecessary:YES] loadImageWithURLRequest:[RCTConvert NSURLRequest:imagePath] callback:^(NSError *error, UIImage *image) {

            if (error || image == nil) {
                if ([imagePath hasPrefix:@"data:"] || [imagePath hasPrefix:@"file:"]) {
                    NSURL *imageUrl = [[NSURL alloc] initWithString:imagePath];
                    image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageUrl]];
                } else {
                    image = [[UIImage alloc] initWithContentsOfFile:imagePath];
                }
                if (image == nil) {
                    // callback(@[@"Can't retrieve the file from the path.", @""]);
                    return;
                }
            }
            
            FIRVision *vision = [FIRVision vision];
            FIRVisionTextRecognizer *textRecognizer = [vision onDeviceTextRecognizer];
            NSDictionary *d = [[NSDictionary alloc] init];
            
            if (!image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    resolve(@NO);
                });
                return;
            }
            
            FIRVisionImage *handler = [[FIRVisionImage alloc] initWithImage:image];
            
            [textRecognizer processImage:handler completion:^(FIRVisionText *_Nullable result, NSError *_Nullable error) {
                if (error != nil || result == nil) {
                    NSString *errorString = error ? error.localizedDescription : detectionNoResultsMessage;
                    NSDictionary *pData = @{
                                            @"error": [NSMutableString stringWithFormat:@"On-Device text detection failed with error: %@", errorString],
                                            };
                    // Running on background thread, don't call UIKit
                    dispatch_async(dispatch_get_main_queue(), ^{
                        resolve(pData);
                    });
                    return;
                }
                
                CGRect boundingBox;
                CGSize size;
                CGPoint origin;
                NSMutableArray *output = [NSMutableArray array];
                
                for (FIRVisionTextBlock *block in result.blocks) {
                    NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
                    NSMutableDictionary *bounding = [NSMutableDictionary dictionary];
                    NSString *blockText = block.text;
                    
                    blocks[@"resultText"] = result.text;
                    blocks[@"blockText"] = block.text;
                    blocks[@"bounding"] = bounding;
                    [output addObject:blocks];
                    
                    for (FIRVisionTextLine *line in block.lines) {
                        NSMutableDictionary *lines = [NSMutableDictionary dictionary];
                        lines[@"lineText"] = line.text;
                        [output addObject:lines];
                        
                        for (FIRVisionTextElement *element in line.elements) {
                            NSMutableDictionary *elements = [NSMutableDictionary dictionary];
                            elements[@"elementText"] = element.text;
                            [output addObject:elements];
                            
                        }
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    resolve(output);
                });
            }];
        }];
    });
        
}

@end
