<cfcomponent output="false">

    <cfset this.name = "ColdspaDemo">
    <cfset this.applicationTimeout = createTimeSpan(0, 2, 0, 0)>
    <cfset this.sessionManagement = false>

    <!---
        Custom tag lookup path. Without this, <cf_Island> / <cf_Slot> would
        only resolve when the calling template lives next to them. Pointing
        at the webroot lets every demo (or any page at any depth) use the
        coldspa custom tags.
    --->
    <cfset this.customTagPaths = expandPath("/")>

    <cffunction name="onApplicationStart" returntype="boolean" output="false">
        <cfset new coldspa.Bootstrap().onApplicationStart()>
        <cfreturn true>
    </cffunction>

    <cffunction name="onApplicationStop" returntype="void" output="false">
        <cfset new coldspa.Bootstrap().onApplicationStop()>
    </cffunction>

    <cffunction name="onRequestStart" returntype="boolean" output="false">
        <cfargument name="targetPage" type="string" required="true">
        <cfset new coldspa.Bootstrap().onRequestStart()>
        <cfreturn true>
    </cffunction>

</cfcomponent>

