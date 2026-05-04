<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Coldspa Demo &mdash; React</title>
</head>
<body>
    <h1>Coldspa Island Demo &mdash; React</h1>
    <p>This page is rendered by ColdFusion. The widget below is a React island.</p>

    <cfinclude template="/coldspa/renderers/React.cfm">

    <cfscript>
        props = {
            "hello":      "React World",
            "serverTime": dateTimeFormat(now(), "yyyy-mm-dd HH:nn:ss")
        };
    </cfscript>

    <cf_Island
        framework="#React#"
        path="./demos/react/App.jsx"
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
