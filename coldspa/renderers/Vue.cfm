<cfsilent>
<!---
    Vue renderer module for Coldspa.
--->
<cfscript>
Vue = {
    "name": "Vue",
    "clientEntry": "./coldspa/renderers/vue-client.js",
    "render": function(mountId, componentGlobKey, propsJson, resolvedClientEntry) {
        var jsId = arguments.mountId.replace('-', '_', 'all');
        return {
            "imports": "
                import { mount as __coldspa_mount_#jsId# } from '#arguments.resolvedClientEntry#';
            ",
            "body": "
                __coldspa_mount_#jsId#(
                    '#arguments.componentGlobKey#',
                    document.getElementById('#arguments.mountId#'),
                    #arguments.propsJson#
                );
            "
        };
    }
};
</cfscript>
</cfsilent>
