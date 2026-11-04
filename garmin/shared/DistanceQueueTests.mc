(:test)
function distanceQueueRegression(logger) {
    var q = new DistanceQueue();
    if (q.due(null, true) != -1 || q.due(199.0, true) != -1) { return false; }
    if (q.due(200.0, false) != -1 || q.due(200.0, true) != 0) { return false; }
    q.begin(0);
    if (q.due(450.0, true) != -1 || q.pending() != 2) { return false; }
    q.fail();
    if (q.pending() != 2 || q.due(450.0, true) != 0) { return false; }
    q.begin(0);
    q.finish();
    if (q.pending() != 1 || q.due(450.0, true) != 1) { return false; }
    q.begin(1);
    q.finish();
    if (q.pending() != 0 || q.due(900.0, true) != -1) { return false; }
    return true;
}
(:test)
function progressSurvivesRestart(logger) {
    var q = new DistanceQueue();
    q.begin(0); q.finish(); q.begin(1);
    var recovered = new DistanceQueue();
    if (!recovered.restore(q.snapshot())) { return false; }
    return recovered.pending() == 1 && recovered.active == -1 && recovered.due(450.0, true) == 1;
}
(:test)
function invalidProgressDoesNotEraseSession(logger) {
    var q = new DistanceQueue(); q.begin(0); q.finish();
    if (q.restore({"version" => 1, "completed" => [true, "bad"], "retries" => [0, 0]})) { return false; }
    return q.pending() == 1 && !q.restore(null) && !q.restore({"version" => 99});
}
(:test)
function interruptedMessagesHaveBoundedRetries(logger) {
    var q = new DistanceQueue();
    for (var i = 0; i < 3; i += 1) {
        if (q.due(450.0, true) != 0 || !q.begin(0)) { return false; }
        q.fail();
    }
    var recovered = new DistanceQueue(); recovered.restore(q.snapshot());
    return recovered.pending() == 2 && recovered.blocked() == 1 && recovered.due(450.0, true) == 1 && !recovered.begin(0);
}
(:test)
function packageChangesPreserveStableMessageIds(logger) {
    var q = new DistanceQueue(); q.configure(["a", "b"], [200, 400]); q.begin(0); q.finish();
    var updated = new DistanceQueue();
    if (!updated.configure(["new", "a", "b"], [100, 200, 400]) || !updated.restore(q.snapshot())) { return false; }
    return updated.pending() == 2 && updated.completed[1] && updated.due(450, true) == 0;
}
(:test)
function equalKilometersQueueInOrder(logger) {
    var q = new DistanceQueue();
    if (!q.configure(["a", "b", "c"], [200, 200, 200])) { return false; }
    for (var i = 0; i < 3; i += 1) { if (q.due(200, true) != i) { return false; } q.begin(i); q.finish(); }
    return q.pending() == 0 && !q.configure(["a", "a"], [200,400]) && !q.configure(["b", "c"], [400,200]);
}
