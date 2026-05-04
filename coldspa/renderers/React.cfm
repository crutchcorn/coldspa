<cfsilent>
<!---
    React renderer module for Coldspa.
--->
<cfscript>
React = {
    "name": "React",
    "clientEntry": "./coldspa/vite/clients/react-client.js",

    /**
     * Server-renders the component to HTML by calling the SSR sidecar.
     * Returns { html, css, error } -- same shape as Vue.ssrRender so
     * Island.cfm can treat all renderers uniformly.
     */
    "ssrRender": function(componentGlobKey, props, slotHtml, namedSlots) {
        var ssrUrl = (application.coldspaConfig.ssrUrl ?: "http://127.0.0.1:5174")
                     & "/render/react";
        var payload = serializeJSON({
            "componentPath": arguments.componentGlobKey,
            "props":         arguments.props,
            "slotHtml":      arguments.slotHtml ?: "",
            "namedSlots":    arguments.namedSlots ?: {}
        });
        try {
            cfhttp(url=ssrUrl, method="POST", timeout=5, result="local.resp") {
                cfhttpparam(type="header", name="content-type", value="application/json");
                cfhttpparam(type="body", value=payload);
            }
            if (find("200", local.resp.statusCode)) {
                var parsed = deserializeJSON(local.resp.fileContent);
                return {
                    "html":  parsed.html ?: "",
                    "css":   parsed.css  ?: "",
                    "error": ""
                };
            }
            return {
                "html":  "",
                "css":   "",
                "error": "SSR sidecar returned " & local.resp.statusCode & ": " & left(local.resp.fileContent, 500)
            };
        } catch (any e) {
            return { "html": "", "css": "", "error": "SSR call failed: " & e.message };
        }
    },

    "render": function(mountId, componentGlobKey, propsJson, resolvedClientEntry, optionsJson) {
        var jsId = arguments.mountId.replace('-', '_', 'all');

        // @vitejs/plugin-react requires its Fast Refresh preamble to run
        // before any React code. Vite normally injects it via index.html,
        // but we render through CFML so we add it here in dev. Idempotent;
        // safe to emit per-island.
        var devPreamble = "";
        if (application.coldspaConfig.isDev ?: false) {
            var viteBase = (application.coldspaConfig.viteUrl ?: ("http://localhost:" & (application.coldspaConfig.vitePort ?: "5173")));
            devPreamble = "
                import RefreshRuntime from '#viteBase#/@react-refresh';
                if (!window.__vite_plugin_react_preamble_installed__) {
                    RefreshRuntime.injectIntoGlobalHook(window);
                    window.$RefreshReg$ = () => {};
                    window.$RefreshSig$ = () => (type) => type;
                    window.__vite_plugin_react_preamble_installed__ = true;
                }
            ";
        }

        return {
            "imports": "
                #devPreamble#
                import { mount as __coldspa_mount_#jsId# } from '#arguments.resolvedClientEntry#';
            ",
            "body": "
                __coldspa_mount_#jsId#(
                    '#arguments.componentGlobKey#',
                    document.getElementById('#arguments.mountId#'),
                    #arguments.propsJson#,
                    #arguments.optionsJson#
                );
            "
        };
    }
};
</cfscript>
</cfsilent>
