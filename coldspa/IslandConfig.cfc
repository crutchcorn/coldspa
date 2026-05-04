<cfcomponent output="false" hint="Singleton config for Coldspa islands. Resolves dev/prod mode and Vite port.">

    <cffunction name="init" access="public" returntype="IslandConfig" output="false">
        <cfset variables.config = resolve()>
        <cfreturn this>
    </cffunction>

    <cffunction name="get" access="public" returntype="struct" output="false"
                hint="Returns the resolved config struct: { isDev, vitePort }">
        <cfreturn variables.config>
    </cffunction>

    <cffunction name="reload" access="public" returntype="struct" output="false"
                hint="Re-resolves config from disk/env. Used by the Admin UI toggle to bust cache.">
        <cfset variables.config = resolve()>
        <cfreturn variables.config>
    </cffunction>

    <cffunction name="save" access="public" returntype="void" output="false"
                hint="Persists config to /coldspa.config.json and busts the cache.">
        <cfargument name="newConfig" type="struct" required="true">
        <cfset var path = expandPath("/coldspa.config.json")>
        <cffile action="write" file="#path#" output="#serializeJSON(arguments.newConfig)#" addnewline="false">
        <cfset reload()>
    </cffunction>

    <!--- ===== private ===== --->

    <cffunction name="resolve" access="private" returntype="struct" output="false">
        <cfset var defaults = { "isDev": false, "debug": false, "vitePort": "5173", "ssrUrl": "http://127.0.0.1:5174" }>
        <cfset var resolved = duplicate(defaults)>

        <!--- 2nd priority: /coldspa.config.json --->
        <cfset var jsonPath = expandPath("/coldspa.config.json")>
        <cfif fileExists(jsonPath)>
            <cftry>
                <cfset var raw = fileRead(jsonPath)>
                <cfset var parsed = deserializeJSON(raw)>
                <cfif isStruct(parsed)>
                    <cfset structAppend(resolved, parsed, true)>
                </cfif>
                <cfcatch type="any">
                    <!--- malformed json: fall through to defaults --->
                </cfcatch>
            </cftry>
        </cfif>

        <!--- 1st priority: environment variables (CI/CD, Docker) --->
        <cfset var envSys = "">
        <cftry>
            <cfset envSys = createObject("java", "java.lang.System")>
            <cfcatch type="any"></cfcatch>
        </cftry>

        <cfif isObject(envSys)>
            <cfset var envName = envSys.getenv("CF_ENV") ?: "">
            <cfif len(envName)>
                <cfset resolved.isDev = (lcase(envName) eq "development" or lcase(envName) eq "dev")>
            </cfif>

            <!--- COLDSPA_SSR_URL: where CF reaches the SSR sidecar.
                  Common values:
                    http://127.0.0.1:5174        -- CF and Node on same host
                    http://host.docker.internal:5174  -- CF in Docker, Node on Docker host
                    http://coldspa-ssr:5174      -- CF and Node both in compose, sidecar service name
                    https://ssr.internal.example -- separate prod box / pod --->
            <cfset var envSsrUrl = envSys.getenv("COLDSPA_SSR_URL") ?: "">
            <cfif len(envSsrUrl)>
                <cfset resolved.ssrUrl = envSsrUrl>
            </cfif>

            <!--- COLDSPA_VITE_URL: where the BROWSER reaches Vite in dev.
                  This is what gets prefixed onto component URLs. Same Docker
                  caveats apply but from the browser's perspective. --->
            <cfset var envViteUrl = envSys.getenv("COLDSPA_VITE_URL") ?: "">
            <cfif len(envViteUrl)>
                <cfset resolved.viteUrl = envViteUrl>
            </cfif>

            <!--- COLDSPA_DEBUG: when truthy ("1", "true", "yes"), Island.cfm
                  emits diagnostic HTML comments about SSR status / byte counts. --->
            <cfset var envDebug = envSys.getenv("COLDSPA_DEBUG") ?: "">
            <cfif len(envDebug)>
                <cfset resolved.debug = listFindNoCase("1,true,yes,on", envDebug) gt 0>
            </cfif>
        </cfif>

        <cfreturn resolved>
    </cffunction>

</cfcomponent>
