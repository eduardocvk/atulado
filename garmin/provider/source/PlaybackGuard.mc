import Toybox.Activity;
// No persistir: cada inicio de reproducción abre una espera nueva.
class PlaybackGuard {
    var started; var lastRunning; var seenActivity = false;
    function initialize(now) { started = now; lastRunning = now; }
    function stopReason(now, state, remaining) {
        if (remaining <= 0) { return "No quedan mensajes reproducibles"; }
        if (state == Activity.TIMER_STATE_ON) { seenActivity = true; lastRunning = now; return null; }
        if (seenActivity && state == Activity.TIMER_STATE_OFF) { return "Actividad terminada"; }
        if (!seenActivity && now - started >= 300000) { return "Sin actividad durante 5 min"; }
        if (seenActivity && now - lastRunning >= 900000) { return "Pausa de 15 min: vuelve a continuar"; }
        return null;
    }
}
