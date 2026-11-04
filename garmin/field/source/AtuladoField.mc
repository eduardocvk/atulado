import Toybox.Application;
import Toybox.WatchUi;
class AtuladoFieldApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [new AtuladoField()]; }
}
class AtuladoField extends WatchUi.SimpleDataField {
    function initialize() { SimpleDataField.initialize(); label = "A TU LADO / METROS"; }
    function compute(info) {
        // Sin conexión con el proveedor: no afirmar mensajes reproducidos.
        if (info.elapsedDistance == null) { return "Sin distancia"; }
        return info.elapsedDistance.format("%.0f");
    }
}
