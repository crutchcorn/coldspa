<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Coldspa Demo</title>
</head>
<body>
    <h1>Coldspa Island Demo</h1>
    <p>This page is rendered by ColdFusion. The widget below is a Vue island.</p>

    <cfinclude template="/coldspa/renderers/Vue.cfm">

    <cfscript>
        props = {
            "hello": "World",
            "serverTime": dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")
        };
    </cfscript>

    <cf_Island
        framework="#Vue#"
        path="./src/App.vue"
        props="#props#"
        strategy="visible">
    </cf_Island>

    <hr>
    <p><small>
        Mode: <cfoutput>#(application.coldspaConfig.isDev ? "development" : "production")#</cfoutput>
        | Vite port: <cfoutput>#application.coldspaConfig.vitePort#</cfoutput>
    </small></p>
</body>
</html>