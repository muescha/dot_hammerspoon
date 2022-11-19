-- collect all window filter events for the subscribe

local wf = hs.window.filter
local events = {
    wf.hasNoWindows,
    wf.hasWindow,
    wf.windowAllowed,
    wf.windowCreated,
    wf.windowDestroyed,
    wf.windowFocused,
    wf.windowFullscreened,
    wf.windowHidden,
    wf.windowInCurrentSpace,
    wf.windowMinimized,
    wf.windowMoved,
    wf.windowNotInCurrentSpace,
    wf.windowNotOnScreen,
    wf.windowNotVisible,
    wf.windowOnScreen,
    wf.windowRejected,
    wf.windowsChanged,
    wf.windowTitleChanged,
    wf.windowUnfocused,
    wf.windowUnfullscreened,
    wf.windowUnhidden,
    wf.windowUnminimized,
    wf.windowVisible,

}
hs.window.filter.events = events