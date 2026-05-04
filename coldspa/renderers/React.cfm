<cfsilent>
<!---
    React renderer module for Coldspa.
--->
<cfscript>
React = {
    "name": "React",
    "clientEntry": "./coldspa/renderers/react-client.js",
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
