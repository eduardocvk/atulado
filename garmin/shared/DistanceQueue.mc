import Toybox.Lang;
// No descuenta un mensaje hasta recibir confirmación del reproductor.
class DistanceQueue {
    var thresholds as Array<Number or Float> = [200.0, 400.0];
    var ids as Array<String> = ["probe200", "probe400"];
    var completed as Array<Boolean> = [false, false];
    var active = -1;
    var retries as Array<Number> = [0, 0];
    function initialize() {}
    function configure(messageIds, distances) {
        if (!(messageIds instanceof Array) || !(distances instanceof Array) || messageIds.size() == 0 || messageIds.size() > 100 || messageIds.size() != distances.size()) { return false; }
        var seen = {};
        for (var i = 0; i < messageIds.size(); i += 1) {
            if (!(messageIds[i] instanceof String) || seen.hasKey(messageIds[i]) || !(distances[i] instanceof Number || distances[i] instanceof Float) || distances[i] < 0 || (i > 0 && distances[i] < distances[i-1])) { return false; }
            seen[messageIds[i]] = true;
        }
        ids = messageIds; thresholds = distances; completed = []; retries = []; active = -1;
        for (var i = 0; i < ids.size(); i += 1) { completed.add(false); retries.add(0); }
        return true;
    }
    function due(distance, running) {
        if (!running || distance == null || distance < 0 || active >= 0) { return -1; }
        for (var i = 0; i < thresholds.size(); i += 1) {
            if (!completed[i] && retries[i] < 3 && distance >= thresholds[i]) { return i; }
        }
        return -1;
    }
    function begin(index) {
        if (index < 0 || index >= completed.size() || active >= 0 || completed[index] || retries[index] >= 3) { return false; }
        active = index;
        return true;
    }
    function finish() {
        if (active >= 0) { completed[active] = true; }
        active = -1;
    }
    function fail() {
        if (active >= 0) { retries[active] += 1; }
        active = -1;
    }
    function snapshot() {
        var entries = {};
        for (var i = 0; i < ids.size(); i += 1) { entries[ids[i]] = {"completed" => completed[i], "retries" => retries[i]}; }
        return {"version" => 2, "entries" => entries};
    }
    function restore(saved) {
        // La selección precargada no equivale a un audio terminado. No restaurar active.
        if (!(saved instanceof Dictionary) || !saved.hasKey("version")) { return false; }
        if (saved["version"] == 2) {
            var entries = saved.hasKey("entries") ? saved["entries"] : null;
            if (!(entries instanceof Dictionary)) { return false; }
            for (var i = 0; i < ids.size(); i += 1) {
                if (!entries.hasKey(ids[i])) { continue; }
                var e = entries[ids[i]];
                if (!(e instanceof Dictionary) || !e.hasKey("completed") || !e.hasKey("retries") || !(e["completed"] instanceof Boolean) || !(e["retries"] instanceof Number) || e["retries"] < 0 || e["retries"] > 3) { return false; }
            }
            for (var i = 0; i < ids.size(); i += 1) {
                if (entries.hasKey(ids[i])) { completed[i] = entries[ids[i]]["completed"]; retries[i] = entries[ids[i]]["retries"]; }
            }
            active = -1;
            return true;
        }
        if (saved["version"] != 1 || ids.size() != 2 || ids[0] != "probe200" || ids[1] != "probe400") { return false; }
        var done = saved.hasKey("completed") ? saved["completed"] : null;
        var attempts = saved.hasKey("retries") ? saved["retries"] : null;
        if (!(done instanceof Array) || !(attempts instanceof Array) || done.size() != 2 || attempts.size() != 2) { return false; }
        for (var i = 0; i < 2; i += 1) {
            if (!(done[i] instanceof Boolean) || !(attempts[i] instanceof Number) || attempts[i] < 0 || attempts[i] > 3) { return false; }
        }
        for (var i = 0; i < 2; i += 1) { completed[i] = done[i]; retries[i] = attempts[i]; }
        active = -1;
        return true;
    }
    function pending() {
        var count = 0;
        for (var i = 0; i < completed.size(); i += 1) {
            if (!completed[i]) { count += 1; }
        }
        return count;
    }
    function blocked() {
        var count = 0;
        for (var i = 0; i < completed.size(); i += 1) { if (!completed[i] && retries[i] >= 3) { count += 1; } }
        return count;
    }
}
