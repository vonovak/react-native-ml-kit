#import "TextRecognition.h"
//#import "VisionCamera-Swift.h"

@import MLKitVision.MLKVisionImage;
@import MLKitTextRecognition;
@import MLKitTextRecognitionCommon;
@import MLKitTextRecognitionChinese;
@import MLKitTextRecognitionJapanese;
@import MLKitTextRecognitionKorean;
@import MLKitTextRecognitionDevanagari;


@implementation TextRecognition

+ (UIImage *)lastImage {
//   return TextRecognitionLastImage;
//  NSData* data = [PhotoCaptureDelegate lastPhotoOutput];
  UIImage* img = [TextRecognition imageWithCorrectOrientationFromData:nil];
  return img;
}



RCT_EXPORT_MODULE()

- (NSDictionary*)frameToDict: (CGRect)frame {
    return @{
        @"width": @(frame.size.width),
        @"height": @(frame.size.height),
        @"top": @(frame.origin.y),
        @"left": @(frame.origin.x)
    };
}

- (NSArray<NSDictionary*>*)pointsToDicts: (NSArray<NSValue*>*)points {
    NSMutableArray *array = [NSMutableArray array];
    for (NSValue* point in points) {
        [array addObject:@{
            @"x": [NSNumber numberWithFloat:point.CGPointValue.x],
            @"y": [NSNumber numberWithFloat:point.CGPointValue.y]
        }];
    }
    return array;
}

- (NSArray<NSDictionary*>*)langsToDicts: (NSArray<MLKTextRecognizedLanguage*>*)langs {
    NSMutableArray *array = [NSMutableArray array];
    for (MLKTextRecognizedLanguage* lang in langs) {
        [array addObject:@{ @"languageCode": lang.languageCode }];
    }
    return array;
}

- (NSDictionary*)lineToDict: (MLKTextLine*)line {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setObject:line.text forKey:@"text"];
    [dict setObject:[self frameToDict:line.frame] forKey:@"frame"];
    [dict setObject:[self pointsToDicts:line.cornerPoints] forKey:@"cornerPoints"];
    [dict setObject:[self langsToDicts:line.recognizedLanguages] forKey:@"recognizedLanguages"];

    NSMutableArray *elements = [NSMutableArray arrayWithCapacity:line.elements.count];
    MLKTextElement* lastElement = line.elements.lastObject;
    for (MLKTextElement* element in line.elements) {
//      BOOL isLast = element == lastElement;
//      NSString* text = isLast ? [NSString stringWithFormat:@"%@ ", element.text] : element.text;
        [elements addObject:@{
            @"text": element.text,
            @"frame": [self frameToDict:element.frame],
            @"cornerPoints": [self pointsToDicts:element.cornerPoints]
        }];
    }
    [dict setObject:elements forKey:@"elements"];

    return dict;
}

- (NSDictionary*)blockToDict: (MLKTextBlock*)block {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setObject:block.text forKey:@"text"];
//    [dict setObject:[self frameToDict:block.frame] forKey:@"frame"];
    [dict setObject:[self pointsToDicts:block.cornerPoints] forKey:@"cornerPoints"];
    [dict setObject:[self langsToDicts:block.recognizedLanguages] forKey:@"recognizedLanguages"];

    NSMutableArray *lines = [NSMutableArray arrayWithCapacity:block.lines.count];
    for (MLKTextLine *line in block.lines) {
        [lines addObject:[self lineToDict:line]];
    }
    [dict setObject:lines forKey:@"lines"];

    return dict;
}

RCT_EXPORT_METHOD(recognize: (nonnull NSString*)url
                  script:(NSString*)script
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  UIImage* image = [TextRecognition lastImage];
  if (!image) {
    image = fixImageOrientation([[UIImage alloc] initWithContentsOfFile:url]);
  }

    MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithImage:image];
    visionImage.orientation = image.imageOrientation;

    // text recognizer options based on the script params
    MLKCommonTextRecognizerOptions *options = nil;

    // if the language param isn't specified, we can assume the user requirement is Latin text recognition
    if (script == nil || [script isEqualToString:@"Latin"]) {
        options = [[MLKTextRecognizerOptions alloc] init];
    } else if ([script isEqualToString:@"Chinese"]) {
        options = [[MLKChineseTextRecognizerOptions alloc] init];
    } else if ([script isEqualToString:@"Devanagari"]) {
        options = [[MLKDevanagariTextRecognizerOptions alloc] init];
    } else if ([script isEqualToString:@"Japanese"]) {
        options = [[MLKJapaneseTextRecognizerOptions alloc] init];
    } else if ([script isEqualToString:@"Korean"]) {
        options = [[MLKKoreanTextRecognizerOptions alloc] init];
    } else {
        return reject(@"Text Recognition", @"Unsupported script", nil);
    }

    MLKTextRecognizer *textRecognizer = [MLKTextRecognizer textRecognizerWithOptions:options];

    [textRecognizer processImage:visionImage
                      completion:^(MLKText *_Nullable _result,
                                   NSError *_Nullable error) {
        if (error != nil || _result == nil) {
            return reject(@"Text Recognition", @"Text recognition failed", error);
        }

        NSMutableDictionary *result = [NSMutableDictionary dictionary];

        [result setObject:_result.text forKey:@"text"];

        NSMutableArray *blocks = [NSMutableArray array];
        for (MLKTextBlock *block in _result.blocks) {
            [blocks addObject:[self blockToDict:block]];
        }
        [result setObject:blocks forKey:@"blocks"];

        resolve(result);
    }];

}

UIImage* fixImageOrientation(UIImage* sourceImage) {
    if (sourceImage.imageOrientation == UIImageOrientationUp) {
        return sourceImage;
    }
    UIGraphicsBeginImageContextWithOptions(sourceImage.size, NO, sourceImage.scale);
    [sourceImage drawInRect:CGRectMake(0,0,sourceImage.size.width, sourceImage.size.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (UIImage *)imageWithCorrectOrientationFromData:(NSData *)data {
    UIImage *image = [UIImage imageWithData:data];
    if (image.imageOrientation == UIImageOrientationUp) return image;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];

    UIImage *normalizedImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        [image drawInRect:(CGRect){.origin = CGPointZero, .size = image.size}];
    }];

    return normalizedImage;
}


@end
