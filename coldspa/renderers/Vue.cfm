<cfsilent>
<!---
    Vue renderer module for Coldspa.
    Usage:
        <cfinclude template="/coldspa/renderers/Vue.cfm">
        <cf_Island framework="#Vue#" path="./App.vue" props="#props#">

    Sets a `Vue` struct in the including scope with:
        - name:    "Vue"
        - render:  function(mountId, resolvedPath, propsJson) -> { imports, body }
          imports: ES module imports to hoist to module top level
          body:    statements to run inside the (possibly deferred) boot function
--->
<cfscript>
Vue = {
    "name": "Vue",
    "render": function(mountId, resolvedPath, propsJson) {
        return {
            "imports": "
                import { createApp as __coldspa_createApp_#arguments.mountId.replace('-', '_', 'all')# } from 'vue';
                import __coldspa_Component_#arguments.mountId.replace('-', '_', 'all')# from '#arguments.resolvedPath#';
            ",
            "body": "
                const el = document.getElementById('#arguments.mountId#');
                if (el) {
                    const props = #arguments.propsJson#;
                    __coldspa_createApp_#arguments.mountId.replace('-', '_', 'all')#(
                        __coldspa_Component_#arguments.mountId.replace('-', '_', 'all')#,
                        props
                    ).mount(el);
                }
            "
        };
    }
};
</cfscript>
</cfsilent>
