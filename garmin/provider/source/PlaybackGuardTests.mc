(:test)
function playbackStopsAfterSavedActivity(logger) {
    var g = new PlaybackGuard(0);
    return g.stopReason(0, Toybox.Activity.TIMER_STATE_OFF, 2) == null && g.stopReason(1000, Toybox.Activity.TIMER_STATE_ON, 2) == null && g.stopReason(2000, Toybox.Activity.TIMER_STATE_OFF, 2) != null;
}
(:test)
function playbackDoesNotWaitAllDay(logger) {
    var g = new PlaybackGuard(0);
    if (g.stopReason(299999, null, 2) != null || g.stopReason(300000, null, 2) == null) { return false; }
    g = new PlaybackGuard(0); g.stopReason(1000, Toybox.Activity.TIMER_STATE_ON, 2);
    return g.stopReason(899999, Toybox.Activity.TIMER_STATE_STOPPED, 2) == null && g.stopReason(901000, Toybox.Activity.TIMER_STATE_PAUSED, 2) != null;
}
(:test)
function playbackAllowsLongRacesAndShortPauses(logger) {
    var g = new PlaybackGuard(0);
    for (var i = 0; i < 200; i += 1) { if (g.stopReason(i * 600000, Toybox.Activity.TIMER_STATE_ON, 1) != null) { return false; } }
    return g.stopReason(199 * 600000 + 60000, Toybox.Activity.TIMER_STATE_PAUSED, 1) == null && g.stopReason(199 * 600000 + 60000, Toybox.Activity.TIMER_STATE_PAUSED, 0) != null;
}
