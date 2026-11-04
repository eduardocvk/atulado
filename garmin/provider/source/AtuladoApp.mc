import Toybox.Application;
import Toybox.Activity;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Media;
import Toybox.System;
import Toybox.WatchUi;

class AtuladoApp extends Application.AudioContentProviderApp {
    var queue;
    var refs = [];
    function initialize() { AudioContentProviderApp.initialize(); queue = new DistanceQueue(); }
    function onStart(state) {
        var saved = Application.Storage.getValue("nativeAudioV2");
        if (saved != null) { refs = saved; }
        log("inicio v2; archivos=" + refs.size());
    }
    function getPlaybackConfigurationView() { return [new ProbeView(), new ProbeInput()]; }
    function getSyncDelegate() { return new ProbeSync(); }
    function ready() {
        if (refs.size() != 3) { return false; }
        for (var i = 0; i < 3; i += 1) {
            if (Media.getCachedContentObj(new Media.ContentRef(refs[i], Media.CONTENT_TYPE_AUDIO)) == null) { return false; }
        }
        return true;
    }
    function getContentDelegate(args) { log("playback v2"); var voice = false; if (args instanceof Dictionary) { voice = args.hasKey("voice") && args["voice"] == true; } return new ProbeContent(voice); }
    function content(index) {
        if (!ready()) { return null; }
        return Media.getCachedContentObj(new Media.ContentRef(refs[index], Media.CONTENT_TYPE_AUDIO));
    }
    function start() {
        if (ready()) { Media.startPlayback({}); }
        else { Communications.startSync2(null); }
    }
    function log(message) { System.println("ATULADO;" + System.getTimer() + ";" + message); }
}
class ProbeSync extends Communications.SyncDelegate {
    var index = 0;
    var ids = [];
    var cancelled = false;
    var files = ["wait.mp3", "message-200.mp3", "message-400.mp3"];
    function initialize() { SyncDelegate.initialize(); }
    function isSyncNeeded() { return true; }
    function onStartSync() as Void { index = 0; ids = []; cancelled = false; downloadNext(); }
    function onStopSync() as Void {
        cancelled = true;
        Communications.cancelAllRequests();
        Communications.notifySyncComplete("Descarga cancelada");
    }
    function downloadNext() {
        if (cancelled) { return; }
        if (index == files.size()) {
            Application.Storage.setValue("nativeAudioV2", ids);
            Application.getApp().refs = ids;
            Communications.notifySyncComplete(null);
            return;
        }
        var url = "https://raw.githubusercontent.com/eduardocvk/atulado/codex/garmin-proof-of-concept/assets/audio/" + files[index];
        Communications.makeWebRequest(url, null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
            :mediaEncoding => Media.ENCODING_MP3
        }, method(:downloaded));
    }
    function downloaded(code as Number, data as Null or Lang.ByteArray or Dictionary or String or Toybox.PersistedContent.Iterator) as Void { handleAudioResponse(code, data); }
    // El SDK omite ContentRef en el tipo del callback, aunque AUDIO lo devuelve.
    function handleAudioResponse(code, data) {
        if (cancelled) { return; }
        if (code != 200 || !(data instanceof Media.ContentRef)) {
            Application.getApp().log("descarga fallida=" + code);
            Communications.notifySyncComplete("Error descargando audio: " + code);
            return;
        }
        ids.add(data.getId());
        var cached = Media.getCachedContentObj(data);
        var metadata = new Media.ContentMetadata();
        metadata.title = index == 0 ? "Esperando 200 / 400 m" : "Animo " + (index * 200) + " m";
        metadata.artist = "A tu lado - prueba v2";
        cached.setMetadata(metadata);
        index += 1;
        Communications.notifySyncProgress((index * 100) / 3);
        downloadNext();
    }
}
class ProbeContent extends Media.ContentDelegate {
    var iterator;
    function initialize(voice) { ContentDelegate.initialize(); iterator = new ProbeIterator(voice); }
    function getContentIterator() { return iterator; }
    function resetContentIterator() { return iterator; }
    function onSong(id, event, position) {
        var app = Application.getApp();
        app.log("evento=" + event + ";id=" + id + ";pos=" + position);
        if (!app.ready()) { return; }
        if (event == Media.SONG_EVENT_COMPLETE && app.queue.active >= 0) {
            var expected = app.refs[app.queue.active + 1];
            if (id.equals(expected)) {
                app.queue.finish();
                app.log("completado;pendientes=" + app.queue.pending());
            }
        }
    }
}
class ProbeIterator extends Media.ContentIterator {
    var current;
    var upcoming = -1;
    function initialize(voice) { ContentIterator.initialize(); current = Application.getApp().content(voice ? 1 : 0); }
    function get() { return current; }
    function planned() {
        if (upcoming < 0) {
            var app = Application.getApp();
            var info = Activity.getActivityInfo();
            var due = app.queue.due(info.elapsedDistance, info.timerState == Activity.TIMER_STATE_ON);
            upcoming = due + 1;
        }
        return upcoming;
    }
    function next() {
        var app = Application.getApp();
        var selected = planned();
        if (selected > 0) {
            app.queue.begin(selected - 1);
            app.log("seleccion=" + selected + ";m=" + Activity.getActivityInfo().elapsedDistance);
        }
        current = app.content(selected);
        upcoming = -1;
        return current;
    }
    function previous() { return current; }
    // La precarga no puede modificar la cola de mensajes.
    function peekNext() { return Application.getApp().content(planned()); }
    function peekPrevious() { return current; }
    function canSkip() { return false; }
    function shuffling() { return false; }
    function repeatMode() { return Media.REPEAT_MODE_OFF; }
    function getPlaybackProfile() {
        var profile = new Media.PlaybackProfile();
        profile.playbackControls = [Media.PLAYBACK_CONTROL_PLAYBACK];
        return profile;
    }
}
class ProbeView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc) {
        var app = Application.getApp();
        var cx = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(cx, 80, Graphics.FONT_SMALL, "A TU LADO / V2", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 135, Graphics.FONT_SMALL, app.ready() ? "3 audios preparados" : "Descargar por wifi", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 195, Graphics.FONT_SMALL, app.ready() ? "START: iniciar" : "START: descargar", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 245, Graphics.FONT_XTINY, "DOWN: probar voz / MENU: wifi", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 280, Graphics.FONT_XTINY, "Objetivos: 200 y 400 m", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
class ProbeInput extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onSelect() { Application.getApp().start(); return true; }
    function onMenu() { Communications.startSync2(null); return true; }
    function onNextPage() { if (Application.getApp().ready()) { Media.startPlayback({"voice" => true}); } return true; }
}
