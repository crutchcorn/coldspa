/**
 * ColdBox auto-wire for Coldspa.
 *
 * In a ColdBox app this runs at startup and appends the module's directory to
 * the app's customTagPaths so <cf_Island> and <cf_Slot> resolve without any
 * manual Application.cfc edits.
 *
 * Plain (non-ColdBox) CFML apps don't load this file -- they need to add the
 * path manually:
 *
 *     this.customTagPaths = expandPath("/modules/coldspa");
 */
component {

    this.title       = "Coldspa";
    this.author      = "crutchcorn";
    this.webURL      = "https://github.com/crutchcorn/coldspa";
    this.description = "Give your CFML a spa day. The Islands Architecture for ColdFusion.";
    this.version     = "0.1.0";
    this.autoMapping = true;
    this.entryPoint  = "coldspa";
    this.modelNamespace = "coldspa";
    this.cfmapping   = "coldspa";

    function configure() {
        var settings = controller.getApplicationSettings();
        var current  = settings.customTagPaths ?: "";
        var sep      = (len(current) gt 0) ? ";" : "";
        settings.customTagPaths = current & sep & moduleMapping;
        controller.setApplicationSettings(settings);
    }

    /**
     * ColdBox interceptor: bootstrap Coldspa (config + Node processes) once
     * the application has finished loading. Mirrors what consumers of plain
     * CFML wire up by calling Bootstrap.onApplicationStart() themselves.
     */
    function afterAspectsLoad() {
        new coldspa.Bootstrap().onApplicationStart();
    }

    /**
     * ColdBox interceptor: tear down spawned processes when the application
     * is unloaded.
     */
    function preReinit() {
        new coldspa.Bootstrap().onApplicationStop();
    }

    /**
     * ColdBox interceptor: per-request reload hooks (?reloadApp / ?reloadConfig).
     */
    function preProcess() {
        new coldspa.Bootstrap().onRequestStart();
    }
}
