/*
 Copyright 2013-2014 appPlant UG
 
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "APPPrinter.h"
#import <Cordova/CDVAvailability.h>

@interface APPPrinter ()

@property (retain) NSString* callbackId;
@property (retain) NSString* printerId;
@property (retain) NSURL *printerURL;
@property (strong, nonatomic) NSMutableArray *printersArray;
@end


@implementation APPPrinter

/**
* Method of attribute
*
**/
- (NSMutableArray *)printersArray {
    if (!_printersArray) {
        _printersArray = [NSMutableArray new];
    }
    return _printersArray;
}
/*
 * Checks if the printing service is available.
 *
 * @param {Function} callback
 *      A callback function to be called with the result
 */
- (void) isAvailable:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult;
        BOOL isAvailable = [self isPrintingAvailable];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                           messageAsBool:isAvailable];
        
        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
    }];
}

/**
 * Sends the printing content to the printer controller and opens them.
 *
 * @param {NSString} content
 *      The (HTML encoded) content
 */
- (void) print:(CDVInvokedUrlCommand*)command
{
    if (!self.isPrintingAvailable) {
        return;
    }
    
    _callbackId = command.callbackId;
    
    NSArray*  arguments           = [command arguments];
    NSString* content             = [arguments objectAtIndex:0];
    NSMutableDictionary* settings = [arguments objectAtIndex:1];
    
    UIPrintInteractionController* controller = [self printController];
    
    NSString* printerId = [settings objectForKey:@"printerId"];
    
    [self adjustPrintController:controller withSettings:settings];
    [self loadContent:content intoPrintController:controller];
    
    if (printerId) {
        //[self sendToPrinter:controller];
    }
    else {
        CGRect rect = [self convertIntoRect:[settings objectForKey:@"bounds"]];
        
        [self presentPrintController:controller fromRect:rect];
    }
}

/**
 * Sends the printing content to the printer controller and opens them.
 *
 * @param {NSString} content
 *      The (HTML encoded) content
 */
- (void) superPrint:(CDVInvokedUrlCommand*)command
{
    // check whether printer is available and count of selected printers equals minimum 2 items
    if (!self.isPrintingAvailable || [self.printersArray count] < 2) {
        return;
    }

    _callbackId = command.callbackId;

    NSArray*  arguments           = [command arguments];
    NSString* content             = [arguments objectAtIndex:0];
    NSMutableDictionary* settings = [arguments objectAtIndex:1];
    NSNumber *indexAtPrintersArray = [arguments objectAtIndex:2]; // index of printer at printers Array

    UIPrintInteractionController* controller = [UIPrintInteractionController sharedPrintController];

    [self adjustPrintController:controller withSettings:settings];
    UIMarkupTextPrintFormatter *htmlFormatter = [[UIMarkupTextPrintFormatter alloc]
                                                 initWithMarkupText:content];
    htmlFormatter.startPage = 0;
    htmlFormatter.contentInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0); // 1 inch margins
    controller.printFormatter = htmlFormatter;

    NSLog(@"%@", controller.printPageRenderer );
    [self sendToPrinter:controller printerID:indexAtPrintersArray]; // send to second printer

    controller = nil;
}

/**
 * Retrieves an instance of shared print controller.
 *
 * @return {UIPrintInteractionController*}
 */
- (UIPrintInteractionController*) printController
{
    return [UIPrintInteractionController sharedPrintController];
}

/**
 * Adjusts the settings for the print controller.
 *
 * @param {UIPrintInteractionController} controller
 *      The print controller instance
 *
 * @return {UIPrintInteractionController} controller
 *      The modified print controller instance
 */
- (UIPrintInteractionController*) adjustPrintController:(UIPrintInteractionController*)controller
                                           withSettings:(NSMutableDictionary*)settings
{
    UIPrintInfo* printInfo             = [UIPrintInfo printInfo];
    UIPrintInfoOrientation orientation = UIPrintInfoOrientationPortrait;
    UIPrintInfoOutputType outputType   = UIPrintInfoOutputGeneral;

    if ([[settings objectForKey:@"landscape"] boolValue]) {
        orientation = UIPrintInfoOrientationLandscape;
    }

    if ([[settings objectForKey:@"graystyle"] boolValue]) {
        outputType = UIPrintInfoOutputGrayscale;
    }

    printInfo.outputType  = outputType;
    printInfo.orientation = orientation;
    printInfo.jobName     = [settings objectForKey:@"name"];
    printInfo.duplex      = [[settings objectForKey:@"duplex"] boolValue];

    controller.printInfo      = printInfo;
    controller.showsPageRange = YES;

    return controller;
}

// "-" start declaration of method
// "(void)" - type of return value
// "settingsButtonPressed" - method's name
// "(CDVInvokedUrlCommand*)command" - parameter. Object named as "command" with type  CDVInvokedUrlCommand
- (void) settingsButtonPressed:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        // call method rect of CGRect type
        CGRect rect = CGRectMake(0, 50, 0, 0);
        // init print picker
        UIPrinterPickerController *printPicker = [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:nil];
        // call method presentFromRect of object printPicker with first param as "rect", second param "inView" as self.webView, third ...
        [printPicker presentFromRect:rect inView:self.webView animated:YES completionHandler:
        ^(UIPrinterPickerController *printerPicker, BOOL userDidSelect, NSError *error)
        {
            if (userDidSelect)
            {
                // User selected the item in the UIPrinterPickerController and got the printer details.

                [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:printerPicker.selectedPrinter];

                // Here you will get the printer and printer details.ie,
                // printerPicker.selectedPrinter, printerPicker.selectedPrinter.displayName, printerPicker.selectedPrinter.URL etc. So you can display the printer name in your label text or button title.

                NSLog(@"%@",printerPicker.selectedPrinter.displayName);
                NSLog(@"%@",printerPicker);

                //===================================================================
                [self.printersArray addObject:printerPicker.selectedPrinter];
                //===================================================================
                // get names of all printers
                NSMutableArray *printersNames = [NSMutableArray new];
                for (UIPrinter *printer in self.printersArray) {
                    [printersNames addObject:printer.displayName];
                }

                // init result response
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:printersNames];
                // send result response
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }];
    }];
}

/**
 * Adjusts the web view and page renderer.
 */
- (void) adjustWebView:(UIWebView*)page
  andPrintPageRenderer:(UIPrintPageRenderer*)renderer
{
    UIViewPrintFormatter* formatter = [page viewPrintFormatter];
    // margin not required - done in web page
    formatter.contentInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);

    renderer.headerHeight = -30.0f;
    renderer.footerHeight = -30.0f;
    [renderer addPrintFormatter:formatter startingAtPageAtIndex:0];

    page.scalesPageToFit        = YES;
    page.dataDetectorTypes      = UIDataDetectorTypeNone;
    page.userInteractionEnabled = NO;
    page.autoresizingMask       = (UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight);
}

/**
 * Loads the content into the print controller.
 *
 * @param {NSString} content
 *      The (HTML encoded) content
 * @param {UIPrintInteractionController} controller
 *      The print controller instance
 */
- (void) loadContent:(NSString*)content intoPrintController:(UIPrintInteractionController*)controller
{
    UIWebView* page               = [[UIWebView alloc] init];
    UIPrintPageRenderer* renderer = [[UIPrintPageRenderer alloc] init];

    [self adjustWebView:page andPrintPageRenderer:renderer];

    if ([NSURL URLWithString:content]) {
        NSURL *url = [NSURL URLWithString:content];

        [page loadRequest:[NSURLRequest requestWithURL:url]];
    }
    else {
        // Set the base URL to be the www directory.
        NSString* wwwFilePath = [[NSBundle mainBundle] pathForResource:@"www"
                                                                ofType:nil];
        NSURL* baseURL        = [NSURL fileURLWithPath:wwwFilePath];


        [page loadHTMLString:content baseURL:baseURL];
    }

    controller.printPageRenderer = renderer;
}

/**
 * Opens the print controller so that the user can choose between
 * available iPrinters.
 *
 * @param {UIPrintInteractionController} controller
 *      The prepared print controller with a content
 */
- (void) presentPrintController:(UIPrintInteractionController*)controller
                       fromRect:(CGRect)rect
{
    //    if(CDV_IsIPad()) {
    [controller presentFromRect:rect inView:self.webView animated:YES completionHandler:
     ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
         _printerId = ctrl.printInfo.printerID;
         NSLog(@"%@, %@", _printerId, ctrl.printInfo);
         CDVPluginResult* pluginResult =
         [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsString:_printerId];

         [self.commandDelegate sendPluginResult:pluginResult
                                     callbackId:_callbackId];
     }];
}
//    else {
//        [controller presentAnimated:YES completionHandler:
//         ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
//             _printerId = ctrl.printInfo.printerID;
//             CDVPluginResult* pluginResult =
//             [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
//
//             [self.commandDelegate sendPluginResult:pluginResult
//                                         callbackId:_callbackId];
//         }];
//    }
//}

/**
 * Sends the content directly to the specified printer.
 *
 * @param controller
 *      The prepared print controller with the content
 * @param printerID
 *      The printer ID, specified in printersArray
 */
- (void) sendToPrinter:(UIPrintInteractionController*)controller
                    printerID:(NSNumber*)printerID
{
    
    //    UIPrinter* printer = [UIPrinter printerWithURL:self.printer.URL];
    //    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    //    UIPrinter *currentPrinterObj = [UIPrinter printerWithURL:[NSURL URLWithString:[userDefault stringForKey:@"yourKey"]]];
    UIPrinter* printer = [self.printersArray objectAtIndex:[printerID intValue]];

    [printer contactPrinter:^(BOOL available) {
        if(available){
            NSLog(@"%d", available);
            [controller printToPrinter:printer completionHandler:
             ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
                 CDVPluginResult* pluginResult =
                 [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

                 [self.commandDelegate sendPluginResult:pluginResult
                                             callbackId:_callbackId];
             }];
        }
    }];

    
    //    if([UIPrintInteractionController isPrintingAvailable]){
    //        NSLog(@"%@", controller.printPageRenderer.printFormatters);
    //        [controller printToPrinter: self.printer completionHandler: nil];
    //         ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
    //             NSLog(@"%@", ctrl.printInfo.printerID);
    //             CDVPluginResult* pluginResult =
    //             [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsString:ctrl.printInfo.printerID];
    //
    //
    //             [self.commandDelegate sendPluginResult:pluginResult
    //                                         callbackId:_callbackId];
    //         }];
    //
    //        controller = nil;
    //        NSLog(@"%@", controller.printPageRenderer);
    //    }
    //    NSLog(@"%@", printer.displayName);
    //    NSLog(@"%@", printer.URL);
    //    NSLog(@"%@", controller);
    //    NSLog(@"%@", self.printer.displayName);
    //    NSLog(@"%@", self.printer.URL);
    //    [controller printToPrinter: self.printer completionHandler:
    //     ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
    //         CDVPluginResult* pluginResult =
    //         [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    //
    //         [self.commandDelegate sendPluginResult:pluginResult
    //                                     callbackId:_callbackId];
    //     }];
}

/**
 * Convert Array into Rect object.
 *
 * @param bounds
 *      The bounds
 *
 * @return
 *      A converted Rect object
 */
- (CGRect) convertIntoRect:(NSArray*)bounds
{
    return CGRectMake([[bounds objectAtIndex:0] floatValue],
                      [[bounds objectAtIndex:1] floatValue],
                      [[bounds objectAtIndex:2] floatValue],
                      [[bounds objectAtIndex:3] floatValue]);
}

/**
 * Checks either the printing service is available or not.
 *
 * @return {BOOL}
 */
- (BOOL) isPrintingAvailable
{
    Class controllerCls = NSClassFromString(@"UIPrintInteractionController");
    
    if (!controllerCls) {
        return NO;
    }
    
    return [self printController] && [UIPrintInteractionController
                                      isPrintingAvailable];
}

/**
 *
 * Clear array of chosen printers (serial printing).
 *
 **/
- (void)resetChosenPrintersArray:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        self.printersArray = [NSMutableArray new];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:self.printersArray];
        // The sendPluginResult method is thread-safe.
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];

}

@end