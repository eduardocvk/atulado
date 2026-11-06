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
    var mainMenu = null;
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
        log("inicio v6;archivos=" + refs.size());
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
    function getPlaybackConfigurationView() { mainMenu = new RaceMenu(); return [mainMenu, new ProbeOptions()]; }
    function refresh() { if (mainMenu != null) { mainMenu.refresh(); } WatchUi.requestUpdate(); }
    function getSyncDelegate() { return new RaceSync(); }
    function ready() {
        if (refs.size() < 2 || refs.size() != files.size()) { return false; }
        for (var i = 0; i < refs.size(); i += 1) {
            if (cached(refs[i]) == null) { return false; }
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
        return cached(refs[index]);
    }
    function cached(id) {
        try { return Media.getCachedContentObj(new Media.ContentRef(id, Media.CONTENT_TYPE_AUDIO)); }
        catch (error) { return null; }
    }
    function beginPair() {
        if (loading) { return; }
        loading = true; notice = "Conectando con la web"; refresh();
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
        refresh();
    }
    function newSession() { queue = new DistanceQueue(); if (files.size() > 1 && !"probe".equals(raceId)) { var ids = []; var meters = []; for (var i = 1; i < files.size(); i += 1) { ids.add(files[i]["id"]); meters.add(files[i]["meters"]); } queue.configure(ids, meters); } saveProgress(); notice = "Progreso reiniciado"; }
    function log(message) { System.println("ATULADO;" + System.getTimer() + ";" + message); }
}
class RaceSync extends Communications.SyncDelegate {
    var index = 0; var ids = []; var cancelled = false; var pack = null; var journal = null; var previousRefs = [];
    function initialize() { SyncDelegate.initialize(); }
    function isSyncNeeded() { return true; }
    function packageStatus(data) {
        if (!(data instanceof Dictionary) || !data.hasKey("status")) { return :invalid; }
        if ("ready".equals(data["status"])) { return :ready; }
        return "pending".equals(data["status"]) ? :pending : :empty;
    }
    function encoding(file) { return "mp3".equals(file["encoding"]) ? Media.ENCODING_MP3 : Media.ENCODING_WAV; }
    function onStartSync() as Void {
        index = 0; ids = []; cancelled = false;
        var app = Application.getApp();
        app.loading = true; app.notice = "Buscando mensajes"; app.refresh();
        if (app.deviceToken == null) { complete("Vincula primero el reloj en la web"); return; }
        Communications.makeWebRequest(SERVICE + "/api/device/package", null, {
            :headers => {"Authorization" => "Bearer " + app.deviceToken},
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, method(:manifest));
    }
    function complete(error) {
        var app = Application.getApp(); app.loading = false;
        app.notice = error == null ? "Carrera lista sin conexion" : error;
        app.refresh(); Communications.notifySyncComplete(error);
    }
    function onStopSync() as Void { cancelled = true; Communications.cancelAllRequests(); complete("Cancelado. Puedes reintentar"); }
    function manifest(code as Number, data as Null or Lang.ByteArray or Dictionary or String or Toybox.PersistedContent.Iterator) as Void {
        if (cancelled) { return; }
        var status = packageStatus(data);
        if (code != 200 || !(data instanceof Dictionary) || status == :invalid) { complete(code == 401 ? "Vuelve a vincular el reloj" : "Error obteniendo carrera: " + code); return; }
        if (status != :ready) { complete(status == :pending ? "Introduce el codigo del reloj en la web" : "La carrera no tiene mensajes preparados"); return; }
        if (!data.hasKey("files") || !(data["files"] instanceof Array) || data["files"].size() < 2 || data["files"].size() > 31 || !data.hasKey("raceId") || !data.hasKey("name") || !data.hasKey("version")) { complete("Paquete de carrera no valido"); return; }
        pack = data;
        previousRefs = [];
        var app = Application.getApp();
        for (var i = 0; i < app.refs.size(); i += 1) { previousRefs.add(app.refs[i]); }
        var saved = Application.Storage.getValue("downloadJournalV1");
        if (saved instanceof Dictionary && saved.hasKey("entries") && saved["entries"] instanceof Dictionary) {
            var values = saved["entries"].values();
            for (var i = 0; i < values.size(); i += 1) {
                var entry = values[i];
                if (entry instanceof Dictionary && entry.hasKey("ref") && entry["ref"] != null) { previousRefs.add(entry["ref"]); }
            }
        }
        journal = new DownloadJournal(pack["raceId"], saved);
        downloadNext();
    }
    function downloadNext() {
        if (cancelled) { return; }
        var app = Application.getApp();
        var entries = pack["files"];
        // Reutilizar en bucle evita llamadas recursivas para cada audio ya guardado.
        while (index < entries.size()) {
            var savedRef = journal.lookup(entries[index]);
            if (savedRef == null || app.cached(savedRef) == null) { break; }
            setMetadata(app.cached(savedRef), entries[index]);
            ids.add(savedRef); index += 1;
        }
        app.notice = "Audios: " + index + "/" + entries.size(); app.refresh();
        Communications.notifySyncProgress((index * 100) / entries.size());
        if (index == entries.size()) {
            // Guardar solo la informacion necesaria durante la carrera.
            // Las URL y los hashes del servidor no necesitan ocupar memoria offline.
            var compactFiles = [];
            for (var i = 0; i < entries.size(); i += 1) { compactFiles.add({"id" => entries[i]["id"], "meters" => entries[i]["meters"]}); }
            var compact = {"refs" => ids, "files" => compactFiles, "raceId" => pack["raceId"], "name" => pack["name"], "version" => pack["version"]};
            // Solo se cambia el paquete activo cuando todas las descargas han terminado.
            if (!app.applyPackage(compact)) { complete("Paquete de carrera no valido"); return; }
            Application.Storage.setValue("racePackageV1", compact);
            // Compactar el registro y retirar audios antiguos solo tras confirmar el paquete nuevo.
            var cleanJournal = new DownloadJournal(pack["raceId"], null);
            for (var i = 0; i < entries.size(); i += 1) { cleanJournal.remember(entries[i], ids[i]); }
            Application.Storage.setValue("downloadJournalV1", cleanJournal.snapshot());
            for (var i = 0; i < previousRefs.size(); i += 1) {
                var keep = false;
                for (var j = 0; j < ids.size(); j += 1) { if (previousRefs[i].equals(ids[j])) { keep = true; break; } }
                if (!keep) {
                    try { Media.deleteCachedItem(new Media.ContentRef(previousRefs[i], Media.CONTENT_TYPE_AUDIO)); }
                    catch (error) { app.log("no se pudo retirar audio antiguo"); }
                }
            }
            app.pairingCode = ""; Application.Storage.setValue("pairCodeV1", "");
            complete(null); return;
        }
        var file = entries[index];
        // No enviar credenciales a hosts distintos del servicio vinculado.
        if (!(file["url"] instanceof String) || file["url"].find(SERVICE + "/") != 0) { complete("Origen de audio no autorizado"); return; }
        Communications.makeWebRequest(file["url"], null, {
            :headers => {"Authorization" => "Bearer " + app.deviceToken},
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
            :mediaEncoding => encoding(file)
        }, method(:downloaded));
    }
    function downloaded(code as Number, data as Null or Lang.ByteArray or Dictionary or String or Toybox.PersistedContent.Iterator) as Void { handleAudioResponse(code, data); }
    // El contrato de tipos del SDK omite ContentRef en la respuesta AUDIO.
    function handleAudioResponse(code, data) {
        if (cancelled) { return; }
        if (code != 200 || !(data instanceof Media.ContentRef)) { complete("Error descargando audio: " + code + ". Reintenta sincronizar"); return; }
        var cached = Application.getApp().cached(data.getId());
        if (cached == null) { complete("No se ha guardado el audio descargado"); return; }
        var file = pack["files"][index];
        setMetadata(cached, file);
        journal.remember(file, data.getId());
        Application.Storage.setValue("downloadJournalV1", journal.snapshot());
        ids.add(data.getId()); index += 1; downloadNext();
    }
    function setMetadata(cached, file) {
        var metadata = new Media.ContentMetadata();
        metadata.title = index == 0 ? "Esperando tus mensajes" : file["title"];
        metadata.artist = "A tu lado"; cached.setMetadata(metadata);
    }
}
class ProbeContent extends Media.ContentDelegate {
    var iterator; var preview = false;
    function initialize(voice) { ContentDelegate.initialize(); preview = voice; iterator = new ProbeIterator(voice); }
    function getContentIterator() { return iterator; }
    function resetContentIterator() { return iterator; }
    function onSong(id, event, position) {
        var app = Application.getApp();
        if (preview) {
            if (event == Media.SONG_EVENT_COMPLETE) { iterator.endPlayback("Prueba de auriculares terminada"); }
            return;
        }
        if (app.queue.active < 0 || app.refs.size() < 2) { iterator.checkStop(); return; }
        var expected = app.refs[app.queue.active + 1];
        if (!id.equals(expected)) { return; }
        if (event == Media.SONG_EVENT_COMPLETE) { app.queue.finish(); app.saveProgress(); app.log("completado;pendientes=" + app.queue.pending()); iterator.checkStop(); }
        else if (event == Media.SONG_EVENT_STOP || event == Media.SONG_EVENT_SKIP_NEXT || event == Media.SONG_EVENT_SKIP_PREVIOUS) { app.queue.fail(); app.saveProgress(); iterator.invalidate(); app.log("interrumpido;pendientes=" + app.queue.pending()); }
    }
}
class ProbeIterator extends Media.ContentIterator {
    var current; var upcoming = -1; var preview = false; var guard; var ended = false;
    function initialize(voice) { ContentIterator.initialize(); preview = voice; guard = new PlaybackGuard(System.getTimer()); current = Application.getApp().content(voice ? 1 : 0); }
    function endPlayback(reason) {
        if (ended) { return; }
        ended = true; current = null; upcoming = -1;
        var app = Application.getApp(); app.notice = reason; app.saveProgress(); app.log(reason);
        Media.stopPlayback();
    }
    function checkStop() {
        if (ended) { return true; }
        if (preview) { return false; }
        var app = Application.getApp();
        var reason = guard.stopReason(System.getTimer(), Activity.getActivityInfo().timerState, app.queue.pending() - app.queue.blocked());
        if (reason != null) { endPlayback(reason); }
        return ended;
    }
    function invalidate() { upcoming = -1; }
    function get() { return current; }
    function planned() {
        if (upcoming < 0) { var app = Application.getApp(); var info = Activity.getActivityInfo(); upcoming = 1 + (preview ? -1 : app.queue.due(info.elapsedDistance, info.timerState == Activity.TIMER_STATE_ON)); }
        return upcoming;
    }
    function next() {
        if (preview || checkStop()) { current = null; return null; }
        var app = Application.getApp(); var selected = planned();
        if (selected > 0) { app.queue.begin(selected - 1); app.log("seleccion=" + selected + ";m=" + Activity.getActivityInfo().elapsedDistance); }
        current = app.content(selected); upcoming = -1; return current;
    }
    function previous() { return current; }
    function peekNext() { if (preview || checkStop()) { return null; } return Application.getApp().content(planned()); }
    function peekPrevious() { return current; }
    function canSkip() { return false; }
    function shuffling() { return false; }
    function repeatMode() { return Media.REPEAT_MODE_OFF; }
    function getPlaybackProfile() { var profile = new Media.PlaybackProfile(); profile.playbackControls = [Media.PLAYBACK_CONTROL_PLAYBACK]; return profile; }
}
// Menu nativo: acciones visibles con UP/DOWN y START.
class RaceMenu extends WatchUi.Menu2 {
    var syncItem; var playItem; var pairItem; var progressItem;
    function initialize() {
        Menu2.initialize({:title => "A tu lado / V6"});
        syncItem = new WatchUi.MenuItem("Sincronizar carrera", null, :sync, {});
        playItem = new WatchUi.MenuItem("Continuar carrera", null, :play, {});
        pairItem = new WatchUi.MenuItem("Vincular con la web", null, :pair, {});
        progressItem = new WatchUi.MenuItem("Ver progreso", null, :progress, {});
        addItem(syncItem); addItem(playItem); addItem(pairItem);
        addItem(new WatchUi.MenuItem("Probar auriculares", "Escuchar el primer mensaje", :preview, {}));
        addItem(progressItem);
        addItem(new WatchUi.MenuItem("Reiniciar progreso", "Nueva salida, con confirmacion", :reset, {}));
        refresh();
    }
    function onShow() { refresh(); }
    function refresh() {
        var app = Application.getApp();
        syncItem.setSubLabel(app.loading ? "Descarga en curso" : "Descargar nuevos mensajes");
        playItem.setSubLabel(app.refs.size() > 1 ? app.raceName : "Primero vincula y sincroniza");
        pairItem.setSubLabel(app.pairingCode.length() > 0 ? "Codigo: " + app.pairingCode : "Obtener codigo para la web");
        progressItem.setSubLabel(app.refs.size() > 1 ? "Pendientes: " + app.queue.pending() : "Sin carrera descargada");
    }
}
class RaceStatusView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc) {
        var app = Application.getApp(); var cx = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        dc.drawText(cx, 50, Graphics.FONT_SMALL, "A TU LADO / V6", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 95, Graphics.FONT_XTINY, app.raceName.substring(0, app.raceName.length() > 28 ? 28 : app.raceName.length()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 135, Graphics.FONT_MEDIUM, app.pairingCode.length() > 0 ? app.pairingCode : (app.refs.size() > 1 ? "Pendientes: " + app.queue.pending() : "Sin audios"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 185, Graphics.FONT_XTINY, app.pairingCode.length() > 0 ? "Codigo para la web (10 min)" : "Interrumpidos: " + app.queue.blocked(), Graphics.TEXT_JUSTIFY_CENTER);
        var text = app.notice; var cut = text.length() > 28 ? 28 : text.length();
        dc.drawText(cx, 225, Graphics.FONT_XTINY, text.substring(0, cut), Graphics.TEXT_JUSTIFY_CENTER);
        if (text.length() > cut) { dc.drawText(cx, 252, Graphics.FONT_XTINY, text.substring(cut, text.length() > 56 ? 56 : text.length()), Graphics.TEXT_JUSTIFY_CENTER); }
        dc.drawText(cx, 290, Graphics.FONT_XTINY, "START: sincronizar / BACK: menu", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
class RaceStatusInput extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onSelect() { if (!Application.getApp().loading) { Communications.startSync2(null); } return true; }
}
class ProbeOptions extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function showStatus() { WatchUi.pushView(new RaceStatusView(), new RaceStatusInput(), WatchUi.SLIDE_UP); }
    function onSelect(item) as Void {
        var app = Application.getApp(); var id = item.getId();
        if (id == :progress) { showStatus(); return; }
        if (app.loading) { showStatus(); return; }
        if (id == :sync) {
            if (app.deviceToken == null) { showStatus(); app.beginPair(); }
            else { Communications.startSync2(null); }
            return;
        }
        if (id == :pair) { showStatus(); app.beginPair(); return; }
        if (id == :play || id == :preview) {
            if (!app.ready()) { app.notice = "Primero sincroniza los audios"; showStatus(); return; }
            Media.startPlayback(id == :preview ? {"voice" => true} : {}); return;
        }
        var confirm = new WatchUi.Menu2({:title => "Reiniciar progreso?"});
        confirm.addItem(new WatchUi.MenuItem("Cancelar", null, :cancel, {}));
        confirm.addItem(new WatchUi.MenuItem("Si, nueva salida", null, :confirm, {}));
        WatchUi.pushView(confirm, new ProbeReset(), WatchUi.SLIDE_UP);
    }
}
class ProbeReset extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) as Void {
        if (item.getId() == :confirm) { Application.getApp().newSession(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN); Application.getApp().refresh();
    }
}
