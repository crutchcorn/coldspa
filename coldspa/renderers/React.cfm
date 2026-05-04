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
    "render": function(mountId, resolvedPath, propsJson) {
        var jsId = arguments.mountId.replace('-', '_', 'all');
        return {
            "imports": "
                import __coldspa_React_#jsId# from 'react';
                import { createRoot as __coldspa_createRoot_#jsId# } from 'react-dom/client';
                import __coldspa_Component_#jsId# from '#arguments.resolvedPath#';
            ",
            "body": "
                const el = document.getElementById('#arguments.mountId#');
                if (el) {
                    const props = #arguments.propsJson#;
                    __coldspa_createRoot_#jsId#(el).render(
                        __coldspa_React_#jsId#.createElement(__coldspa_Component_#jsId#, props)
                    );
                }
            "
        };
    }
};
</cfscript>
</cfsilent>
