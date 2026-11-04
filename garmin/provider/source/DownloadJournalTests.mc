(:test)
function partialDownloadSurvivesRestart(logger) {
    var file = {"id" => "a", "encoding" => "wav", "sha" => "hash-a"};
    var journal = new DownloadJournal("race-a", null);
    journal.remember(file, "ref-a");
    var recovered = new DownloadJournal("race-a", journal.snapshot());
    return "ref-a".equals(recovered.lookup(file)) && recovered.lookup({"id" => "b", "encoding" => "wav", "sha" => "hash-b"}) == null;
}
(:test)
function changedAudioAndOtherRacesAreNotReused(logger) {
    var journal = new DownloadJournal("race-a", null);
    journal.remember({"id" => "a", "encoding" => "wav", "sha" => "old"}, "ref-a");
    var other = new DownloadJournal("race-b", journal.snapshot());
    return other.lookup({"id" => "a", "encoding" => "wav", "sha" => "old"}) == null && journal.lookup({"id" => "a", "encoding" => "wav", "sha" => "new"}) == null && journal.lookup({"id" => "a", "encoding" => "wav"}) == null;
}
(:test)
function downloadJournalRejectsInvalidState(logger) {
    var journal = new DownloadJournal("a", {"raceId" => "a", "entries" => {"bad" => "invalid"}});
    if (journal.lookup({"id" => "bad", "encoding" => "wav", "sha" => "hash"}) != null) { return false; }
    var silence = {"id" => "wait", "encoding" => "mp3"};
    journal.remember(silence, "silence-ref");
    return "silence-ref".equals(journal.lookup(silence));
}
(:test)
function configurationMenuExposesSync(logger) {
    var menu = new RaceMenu();
    return menu.findItemById(:sync) == 0 && menu.findItemById(:play) == 1 && menu.findItemById(:pair) == 2 && menu.findItemById(:preview) == 3 && menu.findItemById(:progress) == 4 && menu.findItemById(:reset) == 5;
}
(:test)
function serverTextUsesValueEquality(logger) {
    var sync = new RaceSync();
    // Construir textos nuevos, como los que entrega el parser JSON del SDK.
    var ready = "xready".substring(1, 6);
    var pending = "xpending".substring(1, 8);
    var mp3 = "xmp3".substring(1, 4);
    return sync.packageStatus({"status" => ready}) == :ready && sync.packageStatus({"status" => pending}) == :pending && sync.packageStatus(null) == :invalid && sync.encoding({"encoding" => mp3}) == Toybox.Media.ENCODING_MP3 && sync.encoding({"encoding" => "wav"}) == Toybox.Media.ENCODING_WAV;
}
