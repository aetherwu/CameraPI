/*
 * QRCodeReaderViewController
 *
 * Copyright 2014-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import "ViewController.h"
#import "QRCodeReaderViewController.h"
#import "Reachability.h"

#import "AFNetworking.h"

#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <AudioToolbox/AudioServices.h>


@interface ViewController ()<AVAudioPlayerDelegate>
@property (strong, nonatomic) NSData *mp3Data;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) dispatch_source_t timerSource;
@property (getter = isObservingMessages) BOOL observingMessages;

@property (strong, nonatomic) AVCaptureSession *photoSession;
@property (strong, nonatomic) AVCaptureStillImageOutput *output;
@property (strong, nonatomic) AVCaptureConnection *videoConnection;

@property (strong, nonatomic) AFHTTPRequestOperationManager *manager;
@property (strong, nonatomic) NSArray *nextagents;
@property BOOL isWaitingAudio;
@end


@implementation ViewController

@synthesize photoSession;
@synthesize output;
@synthesize videoConnection;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isWaitingAudio = false;
    // Do any additional setup after loading the view, typically from a nib.
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    //[self playAudio:@"http://lostpub.com/27rauschenbergempire1.mp3"];
    
    //[self startCamera];
    //[self startTimer];
    
    //[self takePhoto];
    //[self sendPhoto];

    //scan and send stored photos when offline.
    
}

-(void) startCamera {
    //init camera
    NSLog(@"camera init");
    AVCaptureDevice *frontalCamera;
    NSArray *allCameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for ( int i = 0; i < allCameras.count; i++ )
    {
        AVCaptureDevice *camera = [allCameras objectAtIndex:i];
        if ( camera.position == AVCaptureDevicePositionBack )
            frontalCamera = camera;
    }
    
    if ( frontalCamera != nil )
    {
        photoSession = [[AVCaptureSession alloc] init];
        
        NSError *error;
        AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:frontalCamera error:&error];
        
        if ( !error && [photoSession canAddInput:input] )
        {
            [photoSession addInput:input];
            output = [[AVCaptureStillImageOutput alloc] init];
            [output setOutputSettings: [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil]];
            
            if ( [photoSession canAddOutput:output] )
            {
                [photoSession addOutput:output];
                videoConnection = nil;
                for (AVCaptureConnection *connection in output.connections)
                {
                    for (AVCaptureInputPort *port in [connection inputPorts])
                    {
                        if ([[port mediaType] isEqual:AVMediaTypeVideo] )
                        {
                            videoConnection = connection;
                            break;
                        }
                    }
                    if (videoConnection) { break; }
                }
                
                NSLog(@"found videoConnection");
                if ( videoConnection )
                {
                    [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                    
                    [photoSession startRunning];
                    
                }
            }
        }
    }
    //end init
}


-(void) startTimer {
    
    //[self takePhoto];
    NSLog(@"set camera timer ");
    self.observingMessages = YES;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.timerSource, dispatch_walltime(NULL, 1ull * NSEC_PER_SEC), 20ull * NSEC_PER_SEC, 2ull * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timerSource, ^{
        if (self.isObservingMessages) {
            [self takePhoto];
        }
    });
    dispatch_resume(self.timerSource);

}

-(void) takePhoto {
    [self.output captureStillImageAsynchronouslyFromConnection:self.videoConnection
         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
             
             NSLog(@"ready to shot");
             if(error) NSLog(@"%@", error);
             if (imageDataSampleBuffer != NULL)
             {
                 NSLog(@"ready to save");
                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                 UIImage *photo = [[UIImage alloc] initWithData:imageData];
                 
                 //compress
                 NSData *compressedImg = UIImageJPEGRepresentation(photo, 1 /*compressionQuality*/);
                 UIImage *compressedPhoto =[UIImage imageWithData:compressedImg];

                 //scale
                 UIImage *scaledImage = [UIImage imageWithCGImage:[compressedPhoto CGImage]
                                     scale:(compressedPhoto.scale * 0.3)
                               orientation:(compressedPhoto.imageOrientation)];
                 
                 //write to album
                 UIImageWriteToSavedPhotosAlbum(scaledImage, nil, nil, nil);
                 NSLog(@"photo saved");
                 
                 //send photo to server
                 //IF WI-FI
                 Reachability *reachability = [Reachability reachabilityForInternetConnection];
                 [reachability startNotifier];
                 
                 NetworkStatus status = [reachability currentReachabilityStatus];
                 if(status == NotReachable)
                 {
                     //No internet
                 }
                 else if (status == ReachableViaWiFi)
                 {
                     //WiFi
                     [self sendPhoto:scaledImage];
                 }
                 else if (status == ReachableViaWWAN) 
                 {
                     //3G
                 }
                 
                 //analyize QR code
                 
             }
         }];
}


- (void)sendPhoto: (UIImage *) scaledImage {
    
    //send to the sever directly when wifi availible
    
        UIImage *imgToPost = scaledImage;
        //UIImageWriteToSavedPhotosAlbum(imgToPost, nil, nil, nil);
        
        NSData *imageData = UIImageJPEGRepresentation(imgToPost, 0.8);
        // we only need the first (most recent) photo -- stop the enumeration
        
        // create request
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        //send photo to server
        //NSString *urlString = [NSString stringWithFormat:@"http://lostpub.com/camera.php"];
        NSString *urlString = [NSString stringWithFormat:@"http://lostpub.com/camera.php"];
        [request setURL:[NSURL URLWithString:urlString]];
        [request setHTTPMethod:@"POST"];
        
        // set Content-Type in HTTP header
        NSString *boundary = @"---------------------------14737809831466499882746641449";
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
        [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
        
        // post body
        NSMutableData *body = [NSMutableData data];
        
        // add image data
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Disposition: attachment; name=\"userfile\"; filename=\"img.jpg\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[NSData dataWithData:imageData]];
        [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        // setting the body of the post to the reqeust
        [request setHTTPBody:body];
        
        
        // make the connection to the web
        NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
        
        NSLog(@"Image post: %@", returnString);
    
    //save photos to album when wifi is not avaiable
    
}

- (void)sendAlbumPhoto: (UIImage *) scaledImage {

    
    //read photo
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
         usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
             if (nil != group) {
                 // be sure to filter the group so you only get photos
                 [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                 
                 
                 [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:group.numberOfAssets - 1] options:0
                          usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                              if (nil != result) {
                                  ALAssetRepresentation *repr = [result defaultRepresentation];
                                  // this is the most recent saved photo
                                  UIImage *imgToPost = [UIImage imageWithCGImage:[repr fullResolutionImage]];
                                  //UIImageWriteToSavedPhotosAlbum(imgToPost, nil, nil, nil);
                                  
                                  NSData *imageData = UIImageJPEGRepresentation(imgToPost, 0.8);
                                  // we only need the first (most recent) photo -- stop the enumeration
                                  
                                  // create request
                                  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                                  
                                  //send photo to server
                                  //NSString *urlString = [NSString stringWithFormat:@"http://lostpub.com/camera.php"];
                                  NSString *urlString = [NSString stringWithFormat:@"http://192.168.1.116/camera.php"];
                                  [request setURL:[NSURL URLWithString:urlString]];
                                  [request setHTTPMethod:@"POST"];
                                  
                                  // set Content-Type in HTTP header
                                  NSString *boundary = @"---------------------------14737809831466499882746641449";
                                  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
                                  [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
                                  
                                  // post body
                                  NSMutableData *body = [NSMutableData data];
                                  
                                  // add image data
                                  [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                                  [body appendData:[@"Content-Disposition: attachment; name=\"userfile\"; filename=\"img.jpg\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                                  [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                                  [body appendData:[NSData dataWithData:imageData]];
                                  [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                                  [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                                  
                                  // setting the body of the post to the reqeust
                                  [request setHTTPBody:body];
                                  
                                  
                                  // make the connection to the web
                                  NSData *returnData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
                                  NSString *returnString = [[NSString alloc] initWithData:returnData encoding:NSUTF8StringEncoding];
                                  
                                  NSLog(@"%@", returnString);
                                  
                                  *stop = YES;
                              }
                          }];
             }
             
             
             *stop = NO;
         } failureBlock:^(NSError *error) {
             NSLog(@"error: %@", error);
         }];


}


- (IBAction)shotAction:(id)sender {
    [self takePhoto];
}

- (IBAction)scanAction:(id)sender
{
    //////MODIFY IT TO: SHOT a photo and process
    //////OR stop at the first recognition
    
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    //dispatch_suspend(self.timerSource);
    
    static QRCodeReaderViewController *reader = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        reader                        = [QRCodeReaderViewController new];
        reader.modalPresentationStyle = UIModalPresentationFormSheet;
    });
    reader.delegate = self;
    
    [reader setCompletionWithBlock:^(NSString *resultAsString) {
        NSLog(@"Completion with result: %@", resultAsString);
    }];
    
    [self presentViewController:reader animated:YES completion:NULL];
}

#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result
{
    //if no QR found, send notification
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
    
    //prevent multuple threads
    
        //Valid url?
        NSURL *candidateURL = [NSURL URLWithString:result];
        if([candidateURL.host isEqualToString:@"lostpub.com"] && [candidateURL.scheme isEqualToString:@"http"]) {
            //validated url address
            [self fetchAgent:result];
        }else{
            NSLog(@"not an url");
            
        }
        //[self startCamera];
        //dispatch_resume(self.timerSource);

    
}

- (void)fetchAgent: (NSString *)url {

    NSLog(@"Start to fetch %@", url);

    //assmeble deviceid/userid/datetime in the future
    
    //fetch the agent json
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {

        //parse and sort
        //NSLog(@"%@", responseObject);
        [self executeAgent:responseObject];
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
}

- (void) executeAgent: (NSArray*)currentAgent {

    //implement first (two) steps
    NSString *audiourl = [currentAgent valueForKey:@"play"];
    NSString* processurl = [currentAgent valueForKey:@"process"];
    NSString* nextinput = [currentAgent valueForKey:@"nextinput"];
    int thisStepNumber = (int)[currentAgent valueForKey:@"step"];
    
    //if it has audio, fetch it and play
    if (audiourl != nil) {
        //Is it a mp3 file?
        //in case string is less than 4 characters long.
        NSString *trimmedString=[audiourl substringFromIndex:MAX((int)[audiourl length]-4, 0)];
        if ([trimmedString isEqual:@".mp3"]) {
            NSLog(@"audio file found: %@", audiourl);
            [self playAudio:audiourl];
        }else{
            NSLog(@"not an audio file");
        }
    }
    
    //if this action has a process to request
    if (processurl != nil) {
        //excute this url by requesting
        //In demo purchasing: step0 create an order; step1: place and complete the order.
    }
    
    //implement a button to trigger the next step
    if([nextinput isEqualToString:@"tap"]){
        
        NSArray* nextinput = [currentAgent valueForKey:@"next"];
        self.nextagents = nextinput;
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        button.tag = thisStepNumber++;
        [button addTarget:self
                   action:@selector(doTheNext:)
         forControlEvents:UIControlEventTouchUpInside];
        [button setTitle:@"NEXT" forState:UIControlStateNormal];
        button.frame = CGRectMake(0,0,620,620);
        button.backgroundColor = [UIColor redColor];
        
        [self.view addSubview:button];
        
    }
    
    if([nextinput isEqualToString:@"auto"]){
        NSArray* nextinput = [currentAgent valueForKey:@"next"];
        self.nextagents = nextinput;
        
        //[self doTheNext];
        //wait untill this audio is over?
        //set a singal for audioDidFinished?
        self.isWaitingAudio = true;
    }

}


- (void) doTheNext {
    [self executeAgent:self.nextagents];
}

- (void) doTheNext:(id)sender {
    [self executeAgent:self.nextagents];
    [sender removeFromSuperview];
}


- (void)playAudio:(NSString *)result
{
    NSLog(@"play: %@", result);
    NSError *error1;
    NSError *error2;
    NSURL *url = [NSURL URLWithString:result];
    self.mp3Data = [[NSData alloc] initWithContentsOfURL:url options:0 error:&error1 ];
    
    _audioPlayer = nil;
    self.audioPlayer = [[AVAudioPlayer alloc]
                        initWithData:self.mp3Data
                        error:&error2];
    self.audioPlayer.delegate = self;
    [self.audioPlayer prepareToPlay];
    [self.audioPlayer play];
    
    //dispatch_resume(self.timerSource);
}


- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"Audio finished");
    
    if(self.isWaitingAudio){
        //TODO: check the status of the current process
        [self doTheNext];
        
        self.isWaitingAudio = false;
    }
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader
{
    [self dismissViewControllerAnimated:YES completion:NULL];
    //dispatch_resume(self.timerSource);
}


@end
