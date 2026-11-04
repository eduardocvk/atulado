// Solo reutiliza audios de la misma carrera y con el mismo contenido.
// Las URL y credenciales nunca se guardan en este registro.
class DownloadJournal {
    var raceId;
    var entries = {};
    function initialize(id, saved) {
        raceId = id;
        if (saved instanceof Dictionary && saved.hasKey("raceId") && id.equals(saved["raceId"]) && saved.hasKey("entries") && saved["entries"] instanceof Dictionary) { entries = saved["entries"]; }
    }
    function fingerprint(file) {
        if (!(file instanceof Dictionary) || !file.hasKey("id") || !file.hasKey("encoding")) { return null; }
        // El silencio incorporado tiene una identidad de formato explícita.
        if ("wait".equals(file["id"]) && "mp3".equals(file["encoding"])) { return "wait-mp3-v1"; }
        return file.hasKey("sha") && file["sha"] instanceof String ? file["encoding"] + ":" + file["sha"] : null;
    }
    function lookup(file) {
        var key = fingerprint(file);
        if (key == null || !entries.hasKey(file["id"])) { return null; }
        var item = entries[file["id"]];
        if (!(item instanceof Dictionary) || !item.hasKey("fingerprint") || !item.hasKey("ref") || !key.equals(item["fingerprint"]) || item["ref"] == null) { return null; }
        return item["ref"];
    }
    function remember(file, ref) {
        var key = fingerprint(file);
        if (key != null) { entries[file["id"]] = {"fingerprint" => key, "ref" => ref}; }
    }
    function snapshot() { return {"raceId" => raceId, "entries" => entries}; }
}
