<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Coldspa Demo &mdash; Vue</title>
</head>
<body>
    <h1>Coldspa Island Demo &mdash; Vue</h1>
    <p>This page is rendered by ColdFusion. The widget below is a Vue island.</p>

    <cfinclude template="/coldspa/renderers/Vue.cfm">

    <cfscript>
        props = {
            "hello":      "Vue World",
            "serverTime": dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")
        };
    </cfscript>

    <cf_Island
        framework="#Vue#"
        path="./demos/vue/App.vue"
        props="#props#"
        strategy="visible">

        <p><em>This sentence comes from the default slot in CFML.</em></p>

        <cf_Slot name="header">
            <h2>Header from CFML</h2>
        </cf_Slot>

        <cf_Slot name="footer">
            <small>Footer rendered by ColdFusion at <cfoutput>#timeFormat(now(), "HH:nn:ss")#</cfoutput></small>
        </cf_Slot>
    </cf_Island>

    <hr>
    <p><small>
        Mode: <cfoutput>#(application.coldspaConfig.isDev ? "development" : "production")#</cfoutput>
        | Vite port: <cfoutput>#application.coldspaConfig.vitePort#</cfoutput>
    </small></p>
</body>
</html>
