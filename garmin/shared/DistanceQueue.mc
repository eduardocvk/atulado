// No descuenta un mensaje hasta recibir confirmación del reproductor.
class DistanceQueue {
    var thresholds = [200.0, 400.0];
    var completed = [false, false];
    var active = -1;
    function initialize() {}
    function due(distance, running) {
        if (!running || distance == null || active >= 0) { return -1; }
        for (var i = 0; i < thresholds.size(); i += 1) {
            if (!completed[i] && distance >= thresholds[i]) { return i; }
        }
        return -1;
    }
    function begin(index) { active = index; }
    function finish() {
        if (active >= 0) { completed[active] = true; }
        active = -1;
    }
    function fail() { active = -1; }
    function pending() {
        var count = 0;
        for (var i = 0; i < completed.size(); i += 1) {
            if (!completed[i]) { count += 1; }
        }
        return count;
    }
}
