<cfsilent>
<!---
    Vue renderer module for Coldspa.
    Usage:
        <cfinclude template="/coldspa/renderers/Vue.cfm">
        <cf_Island framework="#Vue#" path="./App.vue" props="#props#">

    Sets a `Vue` struct in the including scope:
        - name:        "Vue"
        - clientEntry: path to the client entry shim (resolved by Island.cfm via Vite)
        - render:      function(mountId, resolvedComponentPath, propsJson, resolvedClientEntry)
                       -> { imports, body }
--->
<cfscript>
Vue = {
    "name": "Vue",
    "clientEntry": "./coldspa/renderers/vue-client.js",
    "render": function(mountId, resolvedPath, propsJson, resolvedClientEntry) {
        var jsId = arguments.mountId.replace('-', '_', 'all');
        return {
            "imports": "
                import { mount as __coldspa_mount_#jsId# } from '#arguments.resolvedClientEntry#';
                import __coldspa_Component_#jsId# from '#arguments.resolvedPath#';
            ",
            "body": "
                __coldspa_mount_#jsId#(
                    __coldspa_Component_#jsId#,
                    document.getElementById('#arguments.mountId#'),
                    #arguments.propsJson#
                );
            "
        };
    }
};
</cfscript>
</cfsilent>
