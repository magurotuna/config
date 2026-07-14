// toggle-app: visibility toggle for a macOS app, done entirely in-process
// via Cocoa (NSWorkspace / NSRunningApplication) so there is no Apple Event
// round-trip to System Events (which costs ~190ms per call). Bound to ctrl+.
// via a Karabiner shell_command (see ../karabiner/karabiner.json). Usage:
//
//   toggle-app <App Name>
//
// Behaviour: if the named app is frontmost, hide it completely; else if it is
// running, activate it (bring all windows forward); else launch it. App-name
// matching is case-insensitive (an app's localizedName may differ in case from
// what you configure, e.g. process "ghostty" vs bundle "Ghostty").
#import <AppKit/AppKit.h>

static BOOL matches(NSRunningApplication *app, NSString *target) {
    return app.localizedName != nil &&
           [app.localizedName caseInsensitiveCompare:target] == NSOrderedSame;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: toggle-app <App Name>\n");
            return 1;
        }
        NSString *target = [NSString stringWithUTF8String:argv[1]];
        NSWorkspace *ws = NSWorkspace.sharedWorkspace;

        NSRunningApplication *front = ws.frontmostApplication;
        if (front != nil && matches(front, target)) {
            [front hide];
            return 0;
        }
        for (NSRunningApplication *app in ws.runningApplications) {
            if (matches(app, target)) {
                [app activateWithOptions:NSApplicationActivateAllWindows];
                return 0;
            }
        }
        // Cold path: app not running. Launch it (the only path that spawns).
        [ws launchApplication:target];
    }
    return 0;
}
