import Toybox.Application;
import Toybox.Activity;
import Toybox.Audio;
import Toybox.Graphics;
import Toybox.Media;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class AtuladoApp extends Application.AudioContentProviderApp {
    var queue;
    var timer;
    var armed = false;
    var status = "START: prueba playback";
    var distance = null;
    var failed = false;
    var seenPlaying = false;
    var ticks = 0;
    function initialize() { AudioContentProviderApp.initialize(); queue = new DistanceQueue(); }
    function onStart(state) { log("inicio"); }
    function onStop(state) {
        if (timer != null) { timer.stop(); }
        Audio.Output.stop();
        log("detenida; pendientes=" + queue.pending());
    }
    function getPlaybackConfigurationView() { return [new ProbeView(), new ProbeInput()]; }
    function getContentDelegate(args) {
        log("contexto playback");
        arm();
        return new ProbeContent();
    }
    function arm() {
        if (armed) { return; }
        armed = true;
        status = "Esperando Carrera";
        Audio.Output.registerStateChangeHandler(method(:onAudioState));
        timer = new Timer.Timer();
        timer.start(method(:tick), 1000, true);
        log("activada");
    }
    function tick() as Void {
        ticks += 1;
        var info = Activity.getActivityInfo();
        distance = info.elapsedDistance;
        var running = info.timerState == Activity.TIMER_STATE_ON;
        if (ticks % 10 == 0) {
            log("tick=" + ticks + ";m=" + distance + ";running=" + running);
        }
        if (!failed) {
            var index = queue.due(distance, running);
            if (index >= 0) { play(index); }
        }
        WatchUi.requestUpdate();
    }
    function play(index) {
        queue.begin(index);
        seenPlaying = false;
        status = "Iniciando audio " + (index + 1);
        log("solicitud audio=" + index + ";m=" + distance);
        try {
            var id = index == 0 ? Rez.Audios.Message200 : Rez.Audios.Message400;
            Audio.Output.play(Application.loadResource(id), null);
        } catch (error) {
            fail("excepcion " + error.toString());
        }
    }
    function onAudioState(state as Audio.Output.PlaybackState) as Void {
        log("estado audio=" + state);
        if (state == Audio.Output.PLAYBACK_PLAYING) {
            seenPlaying = true;
            status = "Reproduciendo";
        } else if (state == Audio.Output.PLAYBACK_ERROR) {
            fail("error audio=" + Audio.Output.getError());
        } else if (state == Audio.Output.PLAYBACK_STOPPED && queue.active >= 0) {
            // Es evidencia de fin de reproducción, no prueba de que el usuario lo oyó.
            if (seenPlaying) {
                queue.finish();
                status = "Fin de audio; quedan " + queue.pending();
                log(status);
            } else { fail("detenido sin PLAYING"); }
        }
        WatchUi.requestUpdate();
    }
    function fail(message) {
        failed = true;
        queue.fail();
        status = "ERROR: revisar registro";
        log(message);
    }
    function log(message) { System.println("ATULADO;" + System.getTimer() + ";" + message); }
}
class ProbeContent extends Media.ContentDelegate {
    function initialize() { ContentDelegate.initialize(); }
    // Experimento sin pista silenciosa. Comprobar si Garmin conserva el contexto.
    function getContentIterator() { return new ProbeIterator(); }
}
class ProbeIterator extends Media.ContentIterator {
    function initialize() { ContentIterator.initialize(); }
    function get() { return null; }
    function next() { return null; }
    function previous() { return null; }
    function peekNext() { return null; }
    function peekPrevious() { return null; }
    function canSkip() { return false; }
    function shuffling() { return false; }
    function repeatMode() { return Media.REPEAT_MODE_OFF; }
    function getPlaybackProfile() { return new Media.PlaybackProfile(); }
}
class ProbeView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc) {
        var app = Application.getApp();
        var cx = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(cx, 65, Graphics.FONT_SMALL, "A TU LADO / PRUEBA", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 115, Graphics.FONT_SMALL, app.status, Graphics.TEXT_JUSTIFY_CENTER);
        var meters = app.distance == null ? "Sin distancia" : app.distance.format("%.0f") + " m";
        dc.drawText(cx, 165, Graphics.FONT_LARGE, meters, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 225, Graphics.FONT_SMALL, "Pendientes: " + app.queue.pending(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 265, Graphics.FONT_XTINY, "Objetivos: 200 y 400 m", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
class ProbeInput extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onSelect() { Media.startPlayback({}); return true; }
    function onMenu() { Application.getApp().arm(); WatchUi.requestUpdate(); return true; }
}
