//
//  UncaughtExceptionHandler.m
//  UncaughtExceptions
//
//  Created by Matt Gallagher on 2010/05/25.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//

#import "UncaughtExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>

NSString* const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString* const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString* const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

static UncaughtExceptionBlock _uncaughtExceptionBlock = nil;

@implementation UncaughtExceptionHandler {
    BOOL dismissed;
}

+ (NSArray*)backtrace
{
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char** strs = backtrace_symbols(callstack, frames);

    int i;
    NSMutableArray* backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (
        i = UncaughtExceptionHandlerSkipAddressCount;
        i < UncaughtExceptionHandlerSkipAddressCount + UncaughtExceptionHandlerReportAddressCount;
        i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);

    return backtrace;
}

- (void)alertView:(UIAlertView*)anAlertView clickedButtonAtIndex:(NSInteger)anIndex
{
    if (anIndex == 0) {
        dismissed = YES;
    }
}

- (void)saveException:(NSException*)exception
{
    NSMutableArray *UncaughtExceptions = [[NSUserDefaults standardUserDefaults] mutableArrayValueForKey:@"UncaughtExceptions"];
    if (UncaughtExceptions == nil) {
        UncaughtExceptions = [NSMutableArray array];
    }
    [UncaughtExceptions addObject: @{
                                     @"When": [NSDate date],
                                     @"Name": [exception name],
                                     @"Reason": [exception reason],
                                     @"UserInfo": [exception userInfo]
                                     }];
    
    [[NSUserDefaults standardUserDefaults] setObject:UncaughtExceptions forKey:@"UncaughtExceptions"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)handleException:(NSException*)exception
{
    [self saveException:exception];

    if (_uncaughtExceptionBlock) {
        UncaughtExceptionBlock block = [_uncaughtExceptionBlock copy];
        block(exception);
    }
    
    BOOL releaseMode;
#ifndef DEBUG
    releaseMode = YES;
#elif DEBUG == 0
    releaseMode = YES;
#else
    releaseMode = NO;
#endif
    if (!releaseMode) {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Uncaught Exception"
                                                        message:[NSString stringWithFormat: @"Debug details follow:\n%@\n%@",
                                                                            [exception reason],
                                                                            [exception userInfo][UncaughtExceptionHandlerAddressesKey]]
                                                       delegate:self
                                              cancelButtonTitle:@"Quit"
                                              otherButtonTitles:@"Continue", nil];
        [alert show];
    }

    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);

    while (!dismissed) {
        for (NSString* mode in(__bridge NSArray*)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }

    CFRelease(allModes);

    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);

    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[exception userInfo][UncaughtExceptionHandlerSignalKey] intValue]);
    }
    else {
        [exception raise];
    }
}

@end

void HandleException(NSException* exception)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }

    NSArray* callStack = [UncaughtExceptionHandler backtrace];

    NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    userInfo[UncaughtExceptionHandlerAddressesKey] = callStack;

    [[UncaughtExceptionHandler new]
        performSelectorOnMainThread:@selector(handleException:)
                         withObject:[NSException exceptionWithName:[exception name]
                                                            reason:[exception reason]
                                                          userInfo:userInfo]
                      waitUntilDone:YES];
}

void SignalHandler(int signal)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }

    NSDictionary* userInfo = @{
        UncaughtExceptionHandlerSignalKey : [NSNumber numberWithInt:signal],
        UncaughtExceptionHandlerAddressesKey : [UncaughtExceptionHandler backtrace]
    };

    [[UncaughtExceptionHandler new]
        performSelectorOnMainThread:@selector(handleException:)
                         withObject:[NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                                                            reason:[NSString stringWithFormat:@"Signal %d was raised.", signal]
                                                          userInfo:userInfo]
                      waitUntilDone:YES];
}

void InstallUncaughtExceptionHandler(UncaughtExceptionBlock block)
{
    _uncaughtExceptionBlock = block;
    
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT, SignalHandler);
    signal(SIGILL, SignalHandler);
    signal(SIGSEGV, SignalHandler);
    signal(SIGFPE, SignalHandler);
    signal(SIGBUS, SignalHandler);
    signal(SIGPIPE, SignalHandler);
}