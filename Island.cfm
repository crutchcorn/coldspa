<!---
    cf_Island custom tag.

    Renders a hydration mount point + an ES module <script> that boots
    the framework component with serialized props.

    Attributes:
        framework  (struct, required)  - renderer struct from /coldspa/renderers/*
        path       (string, required)  - component path (e.g. "./App.vue")
        props      (struct, optional)  - props passed to the component (default {})
        strategy   (string, optional)  - "load" | "idle" | "visible" (default "load")
--->
<cfparam name="attributes.framework" type="struct">
<cfparam name="attributes.path" type="string">
<cfparam name="attributes.props" type="struct" default="#{}#">
<cfparam name="attributes.strategy" type="string" default="load">

<cfscript>
// Custom tags execute twice (start + end). Only emit on start.
if (thisTag.executionMode neq "start") {
    exit "exitTag";
}

// --- validate strategy
validStrategies = ["load", "idle", "visible"];
if (!arrayFindNoCase(validStrategies, attributes.strategy)) {
    throw(
        type    = "Coldspa.InvalidStrategy",
        message = "Invalid hydration strategy '#attributes.strategy#'. Must be one of: load, idle, visible."
    );
}

// --- validate renderer shape
if (!structKeyExists(attributes.framework, "render") || !isCustomFunction(attributes.framework.render)) {
    throw(
        type    = "Coldspa.InvalidRenderer",
        message = "framework attribute must be a renderer struct with a render() function."
    );
}

// --- resolve config (lazy fallback if Application.cfc didn't wire it)
if (!structKeyExists(application, "islandConfig")) {
    application.islandConfig = new coldspa.IslandConfig().get();
}
cfg = application.islandConfig;

// --- resolve asset path (dev: vite server URL; prod: manifest lookup)
function resolveAsset(required string path) {
    if (cfg.isDev) {
        // Strip leading "./" so we get a clean URL join
        var clean = reReplace(arguments.path, "^\./", "");
        return "http://localhost:#cfg.vitePort#/#clean#";
    }

    // Production: look up content-hashed file in vite manifest
    var manifestPath = expandPath("/dist/.vite/manifest.json");
    if (!fileExists(manifestPath)) {
        throw(
            type    = "Coldspa.MissingManifest",
            message = "Production manifest not found at /dist/.vite/manifest.json. Run `vite build` before deploy."
        );
    }
    var manifest = deserializeJSON(fileRead(manifestPath));
    var key = reReplace(arguments.path, "^\./", "");
    if (!structKeyExists(manifest, key)) {
        throw(
            type    = "Coldspa.AssetNotFound",
            message = "Asset '#key#' not found in vite manifest. Did you include it as a build input?"
        );
    }
    return "/dist/" & manifest[key].file;
}

uid          = lcase(replace(createUUID(), "-", "", "all"));
mountId      = "island-" & uid;        // DOM id (hyphens fine)
jsId         = "island_" & uid;        // JS-identifier-safe (no hyphens)
resolvedPath = resolveAsset(attributes.path);
propsJson    = serializeJSON(attributes.props);
rendered     = attributes.framework.render(mountId, resolvedPath, propsJson);

// Backwards-compat: allow renderers that still return a plain string (treated as body, no imports)
if (isSimpleValue(rendered)) {
    rendered = { "imports": "", "body": rendered };
}
bootImports = rendered.imports;
bootBody    = rendered.body;
</cfscript>

<!--- Mount point --->
<div id="<cfoutput>#mountId#</cfoutput>" data-coldspa-island="<cfoutput>#attributes.framework.name#</cfoutput>"></div>

<cfoutput>
<cfswitch expression="#attributes.strategy#">
    <cfcase value="load">
<script type="module">
#bootImports#
#bootBody#
</script>
    </cfcase>

    <cfcase value="idle">
<script type="module">
#bootImports#
const __boot_#jsId# = async () => {
#bootBody#
};
if ('requestIdleCallback' in window) {
    requestIdleCallback(() => __boot_#jsId#());
} else {
    setTimeout(__boot_#jsId#, 200);
}
</script>
    </cfcase>

    <cfcase value="visible">
<script type="module">
#bootImports#
const __boot_#jsId# = async () => {
#bootBody#
};
const __el_#jsId# = document.getElementById('#mountId#');
if (__el_#jsId# && 'IntersectionObserver' in window) {
    const __obs_#jsId# = new IntersectionObserver((entries, obs) => {
        for (const entry of entries) {
            if (entry.isIntersecting) {
                obs.disconnect();
                __boot_#jsId#();
                break;
            }
        }
    });
    __obs_#jsId#.observe(__el_#jsId#);
} else {
    __boot_#jsId#();
}
</script>
    </cfcase>
</cfswitch>
</cfoutput>
