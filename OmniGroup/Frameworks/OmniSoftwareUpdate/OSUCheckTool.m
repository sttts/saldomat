// Copyright 2002-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSUCheckTool.h"

#import <SystemConfiguration/SCDynamicStore.h>
#import <SystemConfiguration/SCNetwork.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSoftwareUpdate/OSUCheckTool.m 98466 2008-03-10 18:34:15Z bungi $");

static void contemplate_reachability(const char *hostname);
static NSURL *check_url(const char *baseURLCString, const char *appIdentifierCString, const char *appVersionCString, const char *trackCString, const char *osuVersionCString, CFDictionaryRef info);
static void perform_check(NSURL *url);
static NSBundle *OSUFrameworkBundle = nil;

static char *programName;

static void fwriteData(CFDataRef buf, FILE *fp);

static void exit_with_plist(id plist)
{
#if 0 && defined(DEBUG)
    NSLog(@"exiting with plist:\n%@\n", plist);
#endif
    NSString *errorDescription = nil;
    NSData *outputData = [NSPropertyListSerialization dataFromPropertyList:plist format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorDescription];
    if (outputData)
        fwriteData((CFDataRef)outputData, stdout);
    else {
#ifdef DEBUG    
        NSLog(@"Error archiving result dictionary: %@", errorDescription);
#endif	
        exit(OSUTool_Failure);
    }
    
    exit(0); // The result status is in the plist -- if there was an error, it is in the OSUTool_ResultsErrorKey entry.
}

static void exit_with_error(NSError *error)
{
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:[error toPropertyList], OSUTool_ResultsErrorKey, nil];
    exit_with_plist(dict);
}


static void usage()
{
    fprintf(stderr,
            "usage: %s firsthophost url app-identifier app-version track {with|without}-hardware {query,report} license-type osu-version\n"
            "\tUnobtrusively retrieves the specified URL, which must contain\n"
            "\ta plist, and writes its contents to stdout.\n\tExit code indicates reason for failure.\n",
            programName);
    exit(OSUTool_Failure);
}

int main(int _argc, char **_argv) // Don't use these directly
{
    programName = _argv[0];

    if (_argc != 10)
        usage();

    // Extract arguments by position.  We have a lot of them, so lets keep that code right here.
    const char *firstHopHostCString = _argv[1];
    const char *baseURLCString = _argv[2];
    const char *appIdentifierCString = _argv[3];
    const char *appVersionCString = _argv[4];
    const char *trackCString = _argv[5];
    const char *includeHardwareCString = _argv[6];
    const char *reportModeCString = _argv[7];
    const char *licenseTypeCString = _argv[8];
    const char *osuVersionCString = _argv[9];
    
    if (!strchr(baseURLCString, ':'))
        usage();
    
    
    // We are short lived -- we'll just create a top-level pool and leak everything that goes into it.
    [[NSAutoreleasePool alloc] init];
    
    // In order to return localized error strings, we need a bundle from which to get .strings files.  We expect to be inside the OmniSoftwareUpdate.framework bundle.  This bundle isn't in our process, so we need to find it by path instead of identifier.  We assume that our path is absolute here.
    NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:programName length:strlen(programName)];
    NSString *bundlePath = [[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    OSUFrameworkBundle = [[NSBundle bundleWithPath:bundlePath] retain];
    OBASSERT(OSUFrameworkBundle);
    
    bool collectHardwareInformation = true;
    if (strcmp(includeHardwareCString, "with-hardware") == 0)
        collectHardwareInformation = true;
    else if (strcmp(includeHardwareCString, "without-hardware") == 0)
        collectHardwareInformation = false;
    else
        usage();

    bool reportMode = false;
    
    if (strcmp(reportModeCString, "report") == 0)
        reportMode = true;
    else if (strcmp(reportModeCString, "query") == 0)
        reportMode = false;
    else
        usage();

    // Don't check for network availability if we are just going to report the system info
    if (!reportMode) {
        // Don't collect info if we are in non-report mode and we can't connect anyway.
        contemplate_reachability(firstHopHostCString);
    }
    
    @try {
        CFDictionaryRef hardwareInfo = OSUCheckToolCollectHardwareInfo(appIdentifierCString, collectHardwareInformation, licenseTypeCString, reportMode);

        NSURL *url = check_url(baseURLCString, appIdentifierCString, appVersionCString, trackCString, osuVersionCString, reportMode ? NULL : hardwareInfo);
        
        if (reportMode) {
            CFMutableDictionaryRef result = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            if (hardwareInfo)
                CFDictionarySetValue(result, CFSTR("info"), hardwareInfo);
            CFStringRef urlString = (CFStringRef)[url absoluteString];
            if (urlString)
                CFDictionarySetValue(result, CFSTR("url"), urlString);

            CFDataRef xml = CFPropertyListCreateXMLData(kCFAllocatorDefault, result);
            fwriteData(xml, stdout);
            CFRelease(xml);
        } else {
            perform_check(url);
        }
    } @catch (NSException *exc) {
        NSString *description = NSLocalizedStringFromTableInBundle(@"Error while checking for updated version.", nil, OSUFrameworkBundle, @"error description");
        NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Exception raised: %@", nil, OSUFrameworkBundle, @"error reason"), exc];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, nil];
        exit_with_error([NSError errorWithDomain:OSUToolErrorDomain code:OSUToolExceptionRaised userInfo:userInfo]);
    }

    return OSUTool_Success;
}

static void contemplate_reachability(const char *hostname)
{
    SCNetworkConnectionFlags status;

    if (!hostname || !*hostname)
        return;

    if (!SCNetworkCheckReachabilityByName(hostname, &status)) {
        // Unable to determine whether the host is reachable. Most likely problem is that we failed to look up the host name. Most likely reason for that is a network partition, or a multiple failure of name servers (because, of course, EVERYONE actually READS the dns specs and maintains at least two nameservers with decent geographical and topological separation, RIGHT?). Another possibility is that configd is screwed up somehow. At any rate, it's unlikely that we'd be able to retrieve the status info, so return an error.
        // TODO: Localize these.  We are running in a tool that doesn't have direct access to the .strings files, so we'll need to look them up out of our containing .framework's bundle.
        NSString *description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Could not contact %s.", nil, OSUFrameworkBundle, @"error text generated when software update is unable to retrieve the list of current software versions"), hostname];
        NSString *suggestion = NSLocalizedStringFromTableInBundle(@"Your Internet connection might not be active, or there might be a problem somewhere along the network.", nil, OSUFrameworkBundle, @"error text generated when software update is unable to retrieve the list of current software versions");
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, suggestion, NSLocalizedRecoverySuggestionErrorKey, nil];
        exit_with_error([NSError errorWithDomain:OSUToolErrorDomain code:OSUToolRemoteNetworkFailure userInfo:userInfo]);
    }

    if (!(status & kSCNetworkFlagsReachable)) {
        NSString *description = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%s is not reachable.", nil, OSUFrameworkBundle, @"error description"), hostname];
        NSString *suggestion = NSLocalizedStringFromTableInBundle(@"Your Internet connection might not be active, or there might be a problem somewhere along the network.", nil, OSUFrameworkBundle, @"error reason");
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, suggestion, NSLocalizedRecoverySuggestionErrorKey, nil];
        exit_with_error([NSError errorWithDomain:OSUToolErrorDomain code:OSUToolLocalNetworkFailure userInfo:userInfo]);
    }
}

static void _queryStringApplier(const void *key, const void *value, void *context)
{
    CFStringRef escapedKey   = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)key, NULL, NULL, kCFStringEncodingUTF8);
    CFStringRef escapedValue = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)value, NULL, NULL, kCFStringEncodingUTF8);
    CFMutableStringRef query = (CFMutableStringRef)context;

    
    CFStringRef format;
    if (CFStringGetLength(query) > 1)
        format = CFSTR(";%@=%@");
    else
        format = CFSTR("%@=%@");

    CFStringAppendFormat((CFMutableStringRef)context, NULL, format, escapedKey, escapedValue);
    CFRelease(escapedKey);
    CFRelease(escapedValue);
}

static NSURL *check_url(const char *baseURLCString, const char *appIdentifierCString, const char *appVersionCString, const char *trackCString, const char *osuVersionCString, CFDictionaryRef info)
{
    // Build a query string from all the key/value pairs in the info dictionary.
    CFMutableStringRef queryString = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, CFSTR("?"));
    CFStringAppendFormat(queryString, NULL, CFSTR("OSU=%s"), osuVersionCString);
    if (info)
        CFDictionaryApplyFunction(info, _queryStringApplier, queryString);
    
    // Build up the URL based on the scope of the query.
    NSURL *rootURL = [NSURL URLWithString:[NSString stringWithUTF8String:baseURLCString]];
    OBASSERT([rootURL query] == nil);  // The input URL should _not_ have a query already (since +URLWithString:relativeToURL: will toss it if it does).
    
    // The root URL might be a file URL; if it is use the file raw w/o adding our extra scoping.
    NSURL *url;
    
    if ([rootURL isFileURL]) {
        url = rootURL;
    } else {
        NSString *scopePath = [[NSString stringWithUTF8String:appIdentifierCString] stringByAppendingPathComponent:[NSString stringWithUTF8String:appVersionCString]];
        if (trackCString && strlen(trackCString) > 0)
            scopePath = [scopePath stringByAppendingPathComponent:[NSString stringWithUTF8String:trackCString]];
        
        NSURL *scopeURL = [NSURL URLWithString:[[rootURL path] stringByAppendingPathComponent:scopePath] relativeToURL:rootURL];
        
        // Build a URL from what was given and the query string
        url = [[NSURL URLWithString:(NSString *)queryString relativeToURL:scopeURL] absoluteURL];
    }
    
    if (baseURLCString[0] == '-') {
        // Just log the URL, instead of actually fetching it
        CFShow((CFURLRef)url);
        exit(0);
    }
    
    return url;
}

static void perform_check(NSURL *url)
{
    
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];

#ifdef DEBUG_bungi
    NSLog(@"OSU URL = %@", url);
#endif
    [resultDict setObject:[url absoluteString] forKey:OSUTool_ResultsURLKey];
    
    NSError *error = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLResponse *response = nil;
    NSData *resourceData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if ([response MIMEType])
        [resultDict setObject:[response MIMEType] forKey:OSUTool_ResultsMIMETypeKey];
    if ([response textEncodingName])
        [resultDict setObject:[response textEncodingName] forKey:OSUTool_ResultsTextEncodingNameKey];

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

        int statusCode = [httpResponse statusCode];
        
        if ([httpResponse allHeaderFields])
            [resultDict setObject:[httpResponse allHeaderFields] forKey:OSUTool_ResultsHeadersKey];
        
        [resultDict setObject:[NSNumber numberWithInt:statusCode] forKey:OSUTool_ResultsStatusCodeKey];
        
        if (statusCode >= 400) {
            // While we may have gotten back a result data, it is an error response.
            NSString *description = NSLocalizedStringFromTableInBundle(@"Error fetching software update information.", nil, OSUFrameworkBundle, @"error description");
            NSString *reason = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
            NSString *suggestion = NSLocalizedStringFromTableInBundle(@"Please try again later or contact us to let us know this is broken.", nil, OSUFrameworkBundle, @"error reason");
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, suggestion, NSLocalizedRecoverySuggestionErrorKey, nil];
            error = [NSError errorWithDomain:OSUToolErrorDomain code:OSUToolServerError userInfo:userInfo];
        }
    }
    
    if (!error) {        
        // Ensure that the response is parsable as XML.  We don't do anything with the parsed response here, but we want to ensure that any parse errors/crashes don't destroy the main app, just our little fetching tool.
        // Note that we don't currently check if we got a XML-ish content type back.  The normal cause of this would be getting HTML back for a 404 page, but we check for that above.
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:resourceData options:NSXMLNodeOptionsNone error:&error];
        if (document)
            [resultDict setObject:resourceData forKey:OSUTool_ResultsDataKey];
        else {
            NSString *description = NSLocalizedStringFromTableInBundle(@"Unable to parse response from the software update server.", nil, OSUFrameworkBundle, @"error description");
            NSString *reason = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The data returned from <%@> was not a valid XML document.", nil, OSUFrameworkBundle, @"error description"), [url absoluteString]];
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, reason, NSLocalizedFailureReasonErrorKey, error, NSUnderlyingErrorKey, nil];
            error = [NSError errorWithDomain:OSUToolErrorDomain code:OSUToolUnableToParseSoftwareUpdateData userInfo:userInfo];
        }
    }
    
    if (error)
        [resultDict setObject:[error toPropertyList] forKey:OSUTool_ResultsErrorKey];
    
    exit_with_plist(resultDict);
}

static void fwriteData(CFDataRef buf, FILE *fp)
{
    fwrite(CFDataGetBytePtr(buf), 1, CFDataGetLength(buf), fp);
}

