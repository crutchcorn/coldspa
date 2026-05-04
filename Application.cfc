<cfcomponent output="false">

    <cfset this.name = "ColdspaDemo">
    <cfset this.applicationTimeout = createTimeSpan(0, 2, 0, 0)>
    <cfset this.sessionManagement = false>

    <cffunction name="onApplicationStart" returntype="boolean" output="false">
        <cfset application.islandConfig = new coldspa.IslandConfig().get()>
        <!---
            TODO (per design doc):
              - In dev: spin up Vite dev server via cfexecute
              - In prod: validate /dist/.vite/manifest.json exists; if missing,
                log a warning to "island-build" and run `vite build` as fallback.
            Skipped in this initial cut. Run `npm run dev` manually for now.
        --->
        <cfreturn true>
    </cffunction>

    <cffunction name="onRequestStart" returntype="boolean" output="false">
        <cfargument name="targetPage" type="string" required="true">
        <!--- Quick reload hook for dev iteration --->
        <cfif structKeyExists(url, "reloadConfig")>
            <cfset application.islandConfig = new coldspa.IslandConfig().get()>
        </cfif>
        <cfif structKeyExists(url, "reloadApp")>
            <cfset onApplicationStart()>
        </cfif>
        <cfreturn true>
    </cffunction>

</cfcomponent>
