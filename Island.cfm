<!---
    cf_Island custom tag.

    Renders a hydration mount point + an ES module <script> that boots
    the framework component with serialized props.

    Attributes:
        framework  (struct, required)  - renderer struct from /coldspa/renderers/*
        path       (string, required)  - component path (e.g. "./App.vue")
        props      (struct, optional)  - props passed to the component (default {})
        strategy   (string, optional)  - "load" | "idle" | "visible" | "client" (default "load")
                                         "client" skips SSR entirely (no server HTML, no CSS pre-render)
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
validStrategies = ["load", "idle", "visible", "client"];
if (!arrayFindNoCase(validStrategies, attributes.strategy)) {
    throw(
        type    = "Coldspa.InvalidStrategy",
        message = "Invalid hydration strategy '#attributes.strategy#'. Must be one of: load, idle, visible, client."
    );
}

// "client" strategy is client-only: skip SSR entirely.
clientOnly = (attributes.strategy == "client");

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
        // viteUrl override (from COLDSPA_VITE_URL env) lets the browser reach
        // a Vite dev server that isn't on localhost (e.g. host.docker.internal).
        var viteBase = cfg.viteUrl ?: ("http://localhost:" & cfg.vitePort);
        return viteBase & "/" & clean;
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

// Component is loaded dynamically by the framework's client entry via
// import.meta.glob, so we don't resolve it through Vite ourselves -- we just
// normalize the path to a glob key (e.g. "./src/App.vue" -> "/src/App.vue").
componentGlobKey = reReplace(attributes.path, "^\./", "/");

propsJson = serializeJSON(attributes.props);

// The client entry (the JS shim with the bare `vue` import) IS resolved through
// Vite, since it's a real JS file Vite serves/bundles.
resolvedClientEntry = "";
if (structKeyExists(attributes.framework, "clientEntry")) {
    resolvedClientEntry = resolveAsset(attributes.framework.clientEntry);
}

// Server-side rendering. If the renderer supports ssrRender(), call the SSR
// sidecar and embed the returned HTML inside the mount div. The client uses
// the hydrate flag (computed from whether SSR actually produced HTML) to pick
// between hydrate-mode and fresh client-mount APIs. If SSR fails or isn't
// available, the page still works -- just no pre-rendered markup.
ssrHtml  = "";
ssrCss   = "";
ssrError = "";
if (!clientOnly && structKeyExists(attributes.framework, "ssrRender")) {
    ssrResult = attributes.framework.ssrRender(componentGlobKey, attributes.props);
    // Tolerate older renderers that returned a plain string.
    if (isStruct(ssrResult)) {
        ssrHtml  = ssrResult.html  ?: "";
        ssrCss   = ssrResult.css   ?: "";
        ssrError = ssrResult.error ?: "";
    } else {
        ssrHtml = ssrResult;
    }
}

// Build the options object passed to the client's mount() function. The
// client uses `strategy` to decide between hydrate-mode and fresh-mount APIs;
// SSR is skipped entirely above when strategy="client", so anything else
// implies SSR markup is present.
mountOptionsJson = serializeJSON({
    "strategy": attributes.strategy
});

rendered = attributes.framework.render(mountId, componentGlobKey, propsJson, resolvedClientEntry, mountOptionsJson);

// Backwards-compat: allow renderers that still return a plain string (treated as body, no imports)
if (isSimpleValue(rendered)) {
    rendered = { "imports": "", "body": rendered };
}
bootImports = rendered.imports;
bootBody    = rendered.body;

// In prod the SSR sidecar can't easily inline component CSS (the SSR build
// doesn't emit CSS), so we surface it as <link> tags from the client manifest.
// Each chunk in the manifest carries a `css` array of hashed asset filenames.
ssrCssLinks = [];
if (!cfg.isDev && len(ssrHtml) && structKeyExists(attributes.framework, "clientEntry")) {
    try {
        manifestPath = expandPath("/dist/.vite/manifest.json");
        if (fileExists(manifestPath)) {
            manifest = deserializeJSON(fileRead(manifestPath));
            entryKey = reReplace(attributes.framework.clientEntry, "^\./", "");
            if (structKeyExists(manifest, entryKey) && structKeyExists(manifest[entryKey], "css")) {
                for (cssFile in manifest[entryKey].css) {
                    arrayAppend(ssrCssLinks, "/dist/" & cssFile);
                }
            }
        }
    } catch (any e) {
        // non-fatal: we'll just have a brief FOUC
    }
}
</cfscript>

<!--- Surface SSR failures so they aren't silently swallowed. --->
<cfif clientOnly>
    <cfoutput><!-- coldspa SSR: skipped (strategy="client") --></cfoutput>
<cfelseif len(ssrError)>
    <cfoutput><!-- coldspa SSR error: #encodeForHTML(ssrError)# --></cfoutput>
<cfelseif not len(ssrHtml)>
    <cfoutput><!-- coldspa SSR: empty html, no error reported (renderer may not implement ssrRender) --></cfoutput>
<cfelse>
    <cfoutput><!-- coldspa SSR: ok (#len(ssrHtml)# bytes, #len(ssrCss)# css bytes) --></cfoutput>
</cfif>

<!--- Inline scoped/component CSS (dev) so styles are present pre-hydration. --->
<cfif len(ssrCss)>
    <cfoutput><style data-coldspa-ssr="#mountId#">#ssrCss#</style></cfoutput>
</cfif>
<!--- In prod, link the bundled CSS for the client entry. --->
<cfloop array="#ssrCssLinks#" index="cssHref">
    <cfoutput><link rel="stylesheet" href="#cssHref#" data-coldspa-ssr="#mountId#"></cfoutput>
</cfloop>

<!--- Mount point (contains SSR HTML if available, for hydration) --->
<div id="<cfoutput>#mountId#</cfoutput>" data-coldspa-island="<cfoutput>#attributes.framework.name#</cfoutput>"><cfoutput>#ssrHtml#</cfoutput></div>

<cfoutput>
<cfswitch expression="#attributes.strategy#">
    <cfcase value="load,client" delimiters=",">
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
