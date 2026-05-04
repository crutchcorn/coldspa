<cfsilent>
<!---
    Vue renderer module for Coldspa.
--->
<cfscript>
Vue = {
    "name": "Vue",
    "clientEntry": "./coldspa/vite/clients/vue-client.js",

    /**
     * Server-renders the component to HTML by calling the SSR sidecar.
     * Returns { html: string, error: string } so Island.cfm can surface
     * diagnostic info in dev mode.
     */
    "ssrRender": function(componentGlobKey, props, slotHtml) {
        var ssrUrl = (application.coldspaConfig.ssrUrl ?: "http://127.0.0.1:5174")
                     & "/render/vue";
        var payload = serializeJSON({
            "componentPath": arguments.componentGlobKey,
            "props":         arguments.props,
            "slotHtml":      arguments.slotHtml ?: ""
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
        return {
            "imports": "
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
