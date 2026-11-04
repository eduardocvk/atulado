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
