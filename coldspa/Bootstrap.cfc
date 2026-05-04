component output="false" hint="Lifecycle helper for Coldspa. Delegate to its methods from your Application.cfc." {

    /**
     * Call from Application.cfc.onApplicationStart().
     *
     * - Resolves and caches config into application.coldspaConfig.
     * - Spawns the Vite dev server + Node SSR sidecar (dev) or validates the
     *   prod build manifest (prod) via ProcessManager. Skipped if the
     *   COLDSPA_NO_BOOTSTRAP env var is truthy or if `npm` isn't on PATH
     *   (typical for CF-in-Docker setups -- run Vite/Node externally there).
     */
    function onApplicationStart() {
        application.coldspaConfig = new coldspa.ColdspaConfig().get();

        var skip = createObject("java", "java.lang.System").getenv("COLDSPA_NO_BOOTSTRAP") ?: "";
        if (listFindNoCase("1,true,yes,on", skip)) {
            return;
        }

        application.coldspaProcesses = new coldspa.ProcessManager(application.coldspaConfig);
        application.coldspaProcesses.bootstrap();
    }

    /**
     * Call from Application.cfc.onApplicationStop(). Tears down the spawned
     * Vite + sidecar processes so they don't outlive the CF app.
     */
    function onApplicationStop() {
        if (structKeyExists(application, "coldspaProcesses")) {
            application.coldspaProcesses.shutdown();
        }
    }

    /**
     * Call from Application.cfc.onRequestStart(). Provides the dev-iteration
     * hooks:
     *   ?reloadConfig=1  -> re-read coldspa.config.json + env vars
     *   ?reloadApp=1     -> tear down + re-spawn Node processes and reload config
     *
     * No-op outside dev mode unless the URL flags are present.
     */
    function onRequestStart() {
        if (structKeyExists(url, "reloadConfig")) {
            application.coldspaConfig = new coldspa.ColdspaConfig().get();
        }
        if (structKeyExists(url, "reloadApp")) {
            if (structKeyExists(application, "coldspaProcesses")) {
                application.coldspaProcesses.shutdown();
            }
            onApplicationStart();
        }
    }
}
