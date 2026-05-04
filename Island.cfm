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

    Body / slots:
        Anything between <cf_Island> and </cf_Island> is captured (after CFML
        evaluation) and passed to the component as its default slot. Use a
        <slot /> in your Vue component (or {children} in React) to render it.
--->
<cfparam name="attributes.framework" type="struct">
<cfparam name="attributes.path" type="string">
<cfparam name="attributes.props" type="struct" default="#{}#">
<cfparam name="attributes.strategy" type="string" default="load">

<cfscript>
// Initialize named-slot bag in START mode so child <cf_Slot> tags can attach
// to it via getBaseTagData("CF_ISLAND") during body execution. The struct
// persists into END mode (custom tag variables scope is shared across both).
if (thisTag.executionMode eq "start") {
    namedSlots = {};
    exit "exitTemplate";
}

// END pass: thisTag.generatedContent holds the default-slot HTML; namedSlots
// (populated by any <cf_Slot> children) holds the named ones.
if (!structKeyExists(variables, "namedSlots")) {
    namedSlots = {};
}

slotHtml = trim(thisTag.generatedContent);
// Reset; we'll write the full island markup back at the end.
thisTag.generatedContent = "";

// --- validate strategy
validStrategies = ["load", "idle", "visible", "client"];
if (!arrayFindNoCase(validStrategies, attributes.strategy)) {
    throw(
        type    = "Coldspa.InvalidStrategy",
        message = "Invalid hydration strategy '#attributes.strategy#'. Must be one of: load, idle, visible, client."
    );
}

clientOnly = (attributes.strategy == "client");

if (!structKeyExists(attributes.framework, "render") || !isCustomFunction(attributes.framework.render)) {
    throw(
        type    = "Coldspa.InvalidRenderer",
        message = "framework attribute must be a renderer struct with a render() function."
    );
}

if (!structKeyExists(application, "coldspaConfig")) {
    application.coldspaConfig = new coldspa.ColdspaConfig().get();
}
cfg = application.coldspaConfig;

function resolveAsset(required string path) {
    if (cfg.isDev) {
        var clean = reReplace(arguments.path, "^\./", "");
        var viteBase = cfg.viteUrl ?: ("http://localhost:" & cfg.vitePort);
        return viteBase & "/" & clean;
    }
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
slotId       = "slot-"   & uid;        // <template> id for client slot retrieval

componentGlobKey = reReplace(attributes.path, "^\./", "/");
propsJson = serializeJSON(attributes.props);

resolvedClientEntry = "";
if (structKeyExists(attributes.framework, "clientEntry")) {
    resolvedClientEntry = resolveAsset(attributes.framework.clientEntry);
}

// Server-side rendering. Slots are passed through so the SSR output and the
// client hydration agree byte-for-byte.
ssrHtml  = "";
ssrCss   = "";
ssrError = "";
if (!clientOnly && structKeyExists(attributes.framework, "ssrRender")) {
    ssrResult = attributes.framework.ssrRender(componentGlobKey, attributes.props, slotHtml, namedSlots);
    if (isStruct(ssrResult)) {
        ssrHtml  = ssrResult.html  ?: "";
        ssrCss   = ssrResult.css   ?: "";
        ssrError = ssrResult.error ?: "";
    } else {
        ssrHtml = ssrResult;
    }
}

// Build a map of slot-name -> <template> id so the client can pluck each one
// out of the DOM when mounting. Default slot uses the bare slotId.
namedSlotIds = {};
for (slotName in namedSlots) {
    namedSlotIds[slotName] = "slot-" & uid & "-" & slotName;
}

// Options the client mount() sees. slotId tells the client where to find the
// <template> stash containing the slot HTML. hasSlot is a quick check so the
// client can skip DOM lookup when there's nothing to slot.
mountOptionsJson = serializeJSON({
    "strategy":     attributes.strategy,
    "slotId":       slotId,
    "hasSlot":      len(slotHtml) gt 0,
    "namedSlotIds": namedSlotIds
});

rendered = attributes.framework.render(mountId, componentGlobKey, propsJson, resolvedClientEntry, mountOptionsJson);

if (isSimpleValue(rendered)) {
    rendered = { "imports": "", "body": rendered };
}
bootImports = rendered.imports;
bootBody    = rendered.body;

// In prod the SSR build doesn't emit CSS; surface client-bundle CSS as <link>.
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
        // non-fatal: brief FOUC is acceptable
    }
}
</cfscript>

<!--- Build markup. We're in the END pass so we must write into a buffer
     and assign it back to thisTag.generatedContent rather than emitting
     directly (which would land inside the surrounding <cfoutput>'s output
     position, but `<cf_Island>...</cf_Island>` itself is the output). --->
<cfsavecontent variable="islandOutput"><cfoutput><cfif (cfg.debug ?: false)><cfif clientOnly><!-- coldspa SSR: skipped (strategy="client") --><cfelseif len(ssrError)><!-- coldspa SSR error: #encodeForHTML(ssrError)# --><cfelseif not len(ssrHtml)><!-- coldspa SSR: empty html, no error reported --><cfelse><!-- coldspa SSR: ok (#len(ssrHtml)# bytes, #len(ssrCss)# css bytes, #len(slotHtml)# slot bytes) --></cfif></cfif><cfif len(ssrCss)><style data-coldspa-ssr="#mountId#">#ssrCss#</style></cfif><cfloop array="#ssrCssLinks#" index="cssHref"><link rel="stylesheet" href="#cssHref#" data-coldspa-ssr="#mountId#"></cfloop><cfif len(slotHtml)><template id="#slotId#" data-coldspa-slot="#mountId#">#slotHtml#</template></cfif><cfloop collection="#namedSlots#" item="slotName"><template id="#namedSlotIds[slotName]#" data-coldspa-slot="#mountId#" data-coldspa-slot-name="#slotName#">#namedSlots[slotName]#</template></cfloop><div id="#mountId#" data-coldspa-island="#attributes.framework.name#">#ssrHtml#</div><cfswitch expression="#attributes.strategy#"><cfcase value="load,client" delimiters=",">
<script type="module">
#bootImports#
#bootBody#
</script>
</cfcase><cfcase value="idle">
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
</cfcase><cfcase value="visible">
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
</cfcase></cfswitch></cfoutput></cfsavecontent>

<cfset thisTag.generatedContent = islandOutput>
