import Toybox.Application;
import Toybox.Activity;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Media;
import Toybox.System;
import Toybox.WatchUi;

const SERVICE = "https://a-tu-lado.eduardocvk.chatgpt.site";
class AtuladoApp extends Application.AudioContentProviderApp {
    var queue;
    var refs = [];
    var files = [];
    var raceId = "probe";
    var raceName = "Prueba 200 / 400 m";
    var deviceToken = null;
    var pairingCode = "";
    var notice = "";
    var loading = false;
    function initialize() { AudioContentProviderApp.initialize(); queue = new DistanceQueue(); }
    function onStart(state) {
        deviceToken = Application.Storage.getValue("deviceTokenV1");
        var code = Application.Storage.getValue("pairCodeV1");
        if (code instanceof String) { pairingCode = code; }
        var pack = Application.Storage.getValue("racePackageV1");
        if (pack != null) { applyPackage(pack); }
        else {
            var saved = Application.Storage.getValue("nativeAudioV2");
            if (saved instanceof Array && saved.size() == 3) {
                refs = saved;
                files = [{"id" => "wait"}, {"id" => "probe200"}, {"id" => "probe400"}];
                queue.restore(Application.Storage.getValue("probeProgressV3"));
            }
        }
        queue.restore(Application.Storage.getValue("progress:" + raceId));
        log("inicio v4;archivos=" + refs.size());
    }
    function applyPackage(pack) {
        if (!(pack instanceof Dictionary) || !pack.hasKey("files") || !pack.hasKey("refs") || !pack.hasKey("raceId")) { return false; }
        var entries = pack["files"]; var cached = pack["refs"];
        if (!(entries instanceof Array) || !(cached instanceof Array) || entries.size() < 2 || entries.size() != cached.size()) { return false; }
        var ids = []; var meters = [];
        for (var i = 1; i < entries.size(); i += 1) { ids.add(entries[i]["id"]); meters.add(entries[i]["meters"]); }
        var candidate = new DistanceQueue();
        if (!candidate.configure(ids, meters)) { return false; }
        queue = candidate; files = entries; refs = cached; raceId = pack["raceId"]; raceName = pack["name"];
        queue.restore(Application.Storage.getValue("progress:" + raceId));
        return true;
    }
    function saveProgress() { Application.Storage.setValue("progress:" + raceId, queue.snapshot()); }
    function onStop(state) { saveProgress(); }
    function getPlaybackConfigurationView() { return [new ProbeView(), new ProbeInput()]; }
    function getSyncDelegate() { return new RaceSync(); }
    function ready() {
        if (refs.size() < 2 || refs.size() != files.size()) { return false; }
        for (var i = 0; i < refs.size(); i += 1) {
            if (Media.getCachedContentObj(new Media.ContentRef(refs[i], Media.CONTENT_TYPE_AUDIO)) == null) { return false; }
        }
        return true;
    }
    function getContentDelegate(args) {
        var voice = false;
        if (args instanceof Dictionary) { voice = args.hasKey("voice") && args["voice"] == true; }
        return new ProbeContent(voice);
    }
    function content(index) {
        if (index < 0 || index >= refs.size()) { return null; }
        return Media.getCachedContentObj(new Media.ContentRef(refs[index], Media.CONTENT_TYPE_AUDIO));
    }
    function start() {
        if (loading) { return; }
        if (pairingCode != "" && deviceToken != null) { Communications.startSync2(null); }
        else if (ready()) { Media.startPlayback({}); }
        else if (deviceToken != null) { Communications.startSync2(null); }
        else { beginPair(); }
    }
    function beginPair() {
        if (loading) { return; }
        loading = true; notice = "Conectando con la web"; WatchUi.requestUpdate();
        Communications.makeWebRequest(SERVICE + "/api/device/pair", {}, {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {"Content-Type" => "application/json"},
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:paired));
    }
    function paired(code as Number, data as Null or Lang.ByteArray or Dictionary or String or Toybox.PersistedContent.Iterator) as Void {
        loading = false;
        if (code == 200 && data instanceof Dictionary && data.hasKey("token") && data.hasKey("code")) {
            deviceToken = data["token"]; pairingCode = data["code"];
            Application.Storage.setValue("deviceTokenV1", deviceToken);
            Application.Storage.setValue("pairCodeV1", pairingCode);
            notice = "Introduce el codigo en la web";
        } else { notice = "Error de conexion: " + code; }
        WatchUi.requestUpdate();
    }
    function newSession() { queue = new DistanceQueue(); if (files.size() > 1 && raceId != "probe") { var ids = []; var meters = []; for (var i = 1; i < files.size(); i += 1) { ids.add(files[i]["id"]); meters.add(files[i]["meters"]); } queue.configure(ids, meters); } saveProgress(); notice = "Progreso reiniciado"; }
    function log(message) { System.println("ATULADO;" + System.getTimer() + ";" + message); }
}
class RaceSync extends Communications.SyncDelegate {
    var index = 0; var ids = []; var cancelled = false; var pack = null;
    function initialize() { SyncDelegate.initialize(); }
    function isSyncNeeded() { return true; }
    function onStartSync() as Void {
        index = 0; ids = []; cancelled = false;
        var app = Application.getApp();
        if (app.deviceToken == null) { Communications.notifySyncComplete("Vincula primero el reloj en la web"); return; }
        Communications.makeWebRequest(SERVICE + "/api/device/package", null, {
            :headers => {"Authorization" => "Bearer " + app.deviceToken},
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:manifest));
    }
    function onStopSync() as Void { cancelled = true; Communications.cancelAllRequests(); Communications.notifySyncComplete("Descarga cancelada"); }
    function manifest(code as Number, data as Null or Lang.ByteArray or Dictionary or String or Toybox.PersistedContent.Iterator) as Void {
        if (cancelled) { return; }
        if (code != 200 || !(data instanceof Dictionary) || !data.hasKey("status")) { Communications.notifySyncComplete("Error obteniendo carrera: " + code); return; }
        if (data["status"] != "ready") { Communications.notifySyncComplete(data["status"] == "pending" ? "Introduce el codigo del reloj en la web" : "La carrera no tiene mensajes preparados"); return; }
        pack = data; downloadNext();
    }
    function downloadNext() {
        if (cancelled) { return; }
        var app = Application.getApp();
        var entries = pack["files"];
        if (index == entries.size()) {
            // Guardar solo la informacion necesaria durante la carrera.
            // Las URL y los hashes del servidor no necesitan ocupar memoria offline.
            var compactFiles = [];
            for (var i = 0; i < entries.size(); i += 1) { compactFiles.add({"id" => entries[i]["id"], "meters" => entries[i]["meters"]}); }
            var compact = {"refs" => ids, "files" => compactFiles, "raceId" => pack["raceId"], "name" => pack["name"], "version" => pack["version"]};
            // Solo se cambia el paquete activo cuando todas las descargas han terminado.
            if (!app.applyPackage(compact)) { Communications.notifySyncComplete("Paquete de carrera no valido"); return; }
            Application.Storage.setValue("racePackageV1", compact);
            app.pairingCode = ""; Application.Storage.setValue("pairCodeV1", "");
            Communications.notifySyncComplete(null); return;
        }
        var file = entries[index];
        // No enviar credenciales a hosts distintos del servicio vinculado.
        if (!(file["url"] instanceof String) || file["url"].find(SERVICE + "/") != 0) { Communications.notifySyncComplete("Origen de audio no autorizado"); return; }
        Communications.makeWebRequest(file["url"], null, {
            :headers => {"Authorization" => "Bearer " + app.deviceToken},
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
            :mediaEncoding => file["encoding"] == "mp3" ? Media.ENCODING_MP3 : Media.ENCODING_WAV
        }, method(:downloaded));
    }
    function downloaded(code as Number, data as Null or Lang.ByteArray or Dictionary or String or Toybox.PersistedContent.Iterator) as Void { handleAudioResponse(code, data); }
    // El contrato de tipos del SDK omite ContentRef en la respuesta AUDIO.
    function handleAudioResponse(code, data) {
        if (cancelled) { return; }
        if (code != 200 || !(data instanceof Media.ContentRef)) { Communications.notifySyncComplete("Error descargando audio: " + code); return; }
        ids.add(data.getId());
        var cached = Media.getCachedContentObj(data); var metadata = new Media.ContentMetadata();
        if (cached == null) { Communications.notifySyncComplete("No se ha guardado el audio descargado"); return; }
        var file = pack["files"][index];
        metadata.title = index == 0 ? "Esperando tus mensajes" : file["title"];
        metadata.artist = "A tu lado"; cached.setMetadata(metadata);
        index += 1; Communications.notifySyncProgress((index * 100) / pack["files"].size()); downloadNext();
    }
}
class ProbeContent extends Media.ContentDelegate {
    var iterator; var preview = false;
    function initialize(voice) { ContentDelegate.initialize(); preview = voice; iterator = new ProbeIterator(voice); }
    function getContentIterator() { return iterator; }
    function resetContentIterator() { return iterator; }
    function onSong(id, event, position) {
        var app = Application.getApp();
        if (preview || app.queue.active < 0 || app.refs.size() < 2) { return; }
        var expected = app.refs[app.queue.active + 1];
        if (!id.equals(expected)) { return; }
        if (event == Media.SONG_EVENT_COMPLETE) { app.queue.finish(); app.saveProgress(); app.log("completado;pendientes=" + app.queue.pending()); }
        else if (event == Media.SONG_EVENT_STOP || event == Media.SONG_EVENT_SKIP_NEXT || event == Media.SONG_EVENT_SKIP_PREVIOUS) { app.queue.fail(); app.saveProgress(); iterator.invalidate(); app.log("interrumpido;pendientes=" + app.queue.pending()); }
    }
}
class ProbeIterator extends Media.ContentIterator {
    var current; var upcoming = -1; var preview = false;
    function initialize(voice) { ContentIterator.initialize(); preview = voice; current = Application.getApp().content(voice ? 1 : 0); }
    function invalidate() { upcoming = -1; }
    function get() { return current; }
    function planned() {
        if (upcoming < 0) { var app = Application.getApp(); var info = Activity.getActivityInfo(); upcoming = 1 + (preview ? -1 : app.queue.due(info.elapsedDistance, info.timerState == Activity.TIMER_STATE_ON)); }
        return upcoming;
    }
    function next() {
        var app = Application.getApp(); var selected = planned();
        if (selected > 0) { app.queue.begin(selected - 1); app.log("seleccion=" + selected + ";m=" + Activity.getActivityInfo().elapsedDistance); }
        current = app.content(selected); upcoming = -1; return current;
    }
    function previous() { return current; }
    function peekNext() { return Application.getApp().content(planned()); }
    function peekPrevious() { return current; }
    function canSkip() { return false; }
    function shuffling() { return false; }
    function repeatMode() { return Media.REPEAT_MODE_OFF; }
    function getPlaybackProfile() { var profile = new Media.PlaybackProfile(); profile.playbackControls = [Media.PLAYBACK_CONTROL_PLAYBACK]; return profile; }
}
class ProbeView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc) {
        var app = Application.getApp(); var cx = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        dc.drawText(cx, 55, Graphics.FONT_SMALL, "A TU LADO / V4", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 100, Graphics.FONT_XTINY, app.raceName.substring(0, app.raceName.length() > 28 ? 28 : app.raceName.length()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 145, Graphics.FONT_MEDIUM, app.pairingCode != "" ? app.pairingCode : "Pendientes: " + app.queue.pending(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 195, Graphics.FONT_XTINY, app.pairingCode != "" ? "Codigo para la web (10 min)" : (app.ready() ? "START: continuar carrera" : "START: vincular / descargar"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 235, Graphics.FONT_XTINY, "DOWN: voz / MENU: opciones", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 280, Graphics.FONT_XTINY, app.queue.blocked() > 0 ? "Sin reproducir: " + app.queue.blocked() + " (3 interrupciones)" : app.notice, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
class ProbeInput extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onSelect() { Application.getApp().start(); return true; }
    function onMenu() { var menu = new WatchUi.Menu2({:title => "A tu lado"}); menu.addItem(new WatchUi.MenuItem("Sincronizar carrera", null, :sync, {})); menu.addItem(new WatchUi.MenuItem("Vincular con la web", "Obtener nuevo codigo", :pair, {})); menu.addItem(new WatchUi.MenuItem("Reiniciar progreso", "Nueva salida", :reset, {})); WatchUi.pushView(menu, new ProbeOptions(), WatchUi.SLIDE_UP); return true; }
    function onNextPage() { if (Application.getApp().ready()) { Media.startPlayback({"voice" => true}); } return true; }
}
class ProbeOptions extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) as Void {
        if (item.getId() == :sync) { Communications.startSync2(null); return; }
        if (item.getId() == :pair) { WatchUi.popView(WatchUi.SLIDE_DOWN); Application.getApp().beginPair(); return; }
        var confirm = new WatchUi.Menu2({:title => "Reiniciar progreso?"}); confirm.addItem(new WatchUi.MenuItem("Cancelar", null, :cancel, {})); confirm.addItem(new WatchUi.MenuItem("Si, nueva salida", null, :confirm, {})); WatchUi.pushView(confirm, new ProbeReset(), WatchUi.SLIDE_UP);
    }
}
class ProbeReset extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) as Void { if (item.getId() == :confirm) { Application.getApp().newSession(); } WatchUi.popView(WatchUi.SLIDE_DOWN); WatchUi.popView(WatchUi.SLIDE_DOWN); }
}
