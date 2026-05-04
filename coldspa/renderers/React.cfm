<cfsilent>
<!---
    React renderer module for Coldspa.
    Usage:
        <cfinclude template="/coldspa/renderers/React.cfm">
        <cf_Island framework="#React#" path="./App.jsx" props="#props#">
--->
<cfscript>
React = {
    "name": "React",
    "clientEntry": "./coldspa/renderers/react-client.js",
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
