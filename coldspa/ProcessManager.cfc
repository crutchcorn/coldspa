<cfcomponent output="false" hint="Spawns and supervises the Vite dev server and Node SSR sidecar in dev; validates the prod build manifest at boot.">

    <cffunction name="init" access="public" returntype="ProcessManager" output="false">
        <cfargument name="config" type="struct" required="true">
        <cfset variables.config = arguments.config>
        <cfset variables.processes = {}>
        <cfset variables.projectRoot = expandPath("/")>
        <cfset variables.logDir = expandPath("/WEB-INF/coldspa-logs")>
        <cfset variables.isWindows = findNoCase("windows", createObject("java", "java.lang.System").getProperty("os.name")) gt 0>
        <cfif !directoryExists(variables.logDir)>
            <cfset directoryCreate(variables.logDir)>
        </cfif>
        <cfreturn this>
    </cffunction>

    <!---
        Public entry from Application.cfc.onApplicationStart().

        - Dev: spawns `npm run dev` (Vite) and `npm run ssr` (sidecar) as
               background processes. Stdout/stderr are redirected to log files
               under WEB-INF/coldspa-logs/. Subsequent calls are no-ops.
        - Prod: validates dist/.vite/manifest.json. If missing, logs a warning
               to "island-build" and runs `npm run build` synchronously as a
               recovery step. If the build fails, throws so the broken state is
               loud rather than serving a half-built app.
    --->
    <cffunction name="bootstrap" access="public" returntype="void" output="false">
        <cfset logTrace("bootstrap: enter (isDev=#variables.config.isDev ?: false#, os=#createObject('java', 'java.lang.System').getProperty('os.name')#)")>

        <!--- If npm isn't on PATH (e.g. CF in a Linux container without
              Node installed), don't try to spawn anything. The user will
              run Vite/Node externally and CF just makes HTTP calls to them.
              This is the recommended Docker pattern -- see docs/docker.md. --->
        <cfif !npmAvailable()>
            <cfset logTrace("bootstrap: npm not on PATH; skipping spawn. Run Vite + sidecar externally and ensure ssrUrl/viteUrl point at them. Set COLDSPA_NO_BOOTSTRAP=1 to silence this check.")>
            <cflog file="island-build" type="information"
                   text="Coldspa: npm not on PATH; skipping in-process spawn. Run `npm run dev` and `npm run ssr` externally, or install Node into this environment.">
            <cfreturn>
        </cfif>

        <cfif variables.config.isDev ?: false>
            <!--- Spawn in a background thread so onApplicationStart never
                  holds the application-scope lock waiting on Java IO. --->
            <cfthread name="coldspa-spawn-#createUUID()#" action="run">
                <cftry>
                    <cfset startProcess("vite", ["npm", "run", "dev"])>
                    <cfset startProcess("ssr",  ["npm", "run", "ssr"])>
                    <cfcatch type="any">
                        <cfset logTrace("bootstrap thread error: " & cfcatch.message & " " & cfcatch.detail)>
                    </cfcatch>
                </cftry>
            </cfthread>
        <cfelse>
            <cfset ensureProdBuild()>
        </cfif>
        <cfset logTrace("bootstrap: exit")>
    </cffunction>

    <!--- Probe whether `npm` resolves on the JVM's PATH. Cheap one-shot
          ProcessBuilder with `npm --version` (or `where npm`/`which npm`).
          Memoized so we don't pay the cost on every reload. --->
    <cffunction name="npmAvailable" access="private" returntype="boolean" output="false">
        <cfif structKeyExists(variables, "_npmAvailable")>
            <cfreturn variables._npmAvailable>
        </cfif>

        <cfset var probe = []>
        <cfif variables.isWindows>
            <cfset probe = ["cmd", "/c", "npm", "--version"]>
        <cfelse>
            <cfset probe = ["npm", "--version"]>
        </cfif>

        <cftry>
            <cfset var pb = createObject("java", "java.lang.ProcessBuilder").init(probe)>
            <cfset pb.redirectErrorStream(true)>
            <cfset var p = pb.start()>
            <cfset var unit = createObject("java", "java.util.concurrent.TimeUnit").SECONDS>
            <cfset var ok = p.waitFor(javaCast("long", 5), unit)>
            <cfif !ok>
                <cfset p.destroyForcibly()>
                <cfset variables._npmAvailable = false>
            <cfelse>
                <cfset variables._npmAvailable = (p.exitValue() eq 0)>
            </cfif>
            <cfcatch type="any">
                <cfset variables._npmAvailable = false>
            </cfcatch>
        </cftry>

        <cfset logTrace("npmAvailable: " & variables._npmAvailable)>
        <cfreturn variables._npmAvailable>
    </cffunction>

    <cffunction name="shutdown" access="public" returntype="void" output="false">
        <cfset logTrace("shutdown: enter (#structCount(variables.processes)# processes)")>
        <cfloop collection="#variables.processes#" item="local.name">
            <cftry>
                <cfset variables.processes[local.name].destroyForcibly()>
                <cfcatch type="any">
                    <cfset logTrace("shutdown: destroy '#local.name#' failed: " & cfcatch.message)>
                </cfcatch>
            </cftry>
        </cfloop>
        <cfset variables.processes = {}>
        <cfset logTrace("shutdown: exit")>
    </cffunction>

    <!--- ===== private ===== --->

    <cffunction name="startProcess" access="private" returntype="void" output="false">
        <cfargument name="label"   type="string" required="true">
        <cfargument name="command" type="array"  required="true">

        <!--- Skip if a previous boot already started this one and it's alive. --->
        <cfif structKeyExists(variables.processes, arguments.label)>
            <cftry>
                <cfif variables.processes[arguments.label].isAlive()>
                    <cfreturn>
                </cfif>
                <cfcatch type="any"></cfcatch>
            </cftry>
        </cfif>

        <!--- npm/node aren't directly executable on Windows -- they're .cmd
              shims. Run via cmd.exe. On *nix, Java's ProcessBuilder finds
              them on PATH directly. --->
        <cfset var argList = []>
        <cfif variables.isWindows>
            <cfset arrayAppend(argList, "cmd")>
            <cfset arrayAppend(argList, "/c")>
        </cfif>
        <cfloop array="#arguments.command#" index="local.token">
            <cfset arrayAppend(argList, local.token)>
        </cfloop>

        <cftry>
            <cfset logTrace("startProcess: '#arguments.label#' building -> #arrayToList(argList, ' ')#")>
            <cfset var pb = createObject("java", "java.lang.ProcessBuilder").init(argList)>
            <cfset pb.directory(createObject("java", "java.io.File").init(variables.projectRoot))>
            <cfset pb.redirectErrorStream(true)>
            <cfset var logFile = createObject("java", "java.io.File").init(variables.logDir & "/" & arguments.label & ".log")>
            <cfset pb.redirectOutput(logFile)>
            <!--- Redirect stdin from the platform's null device. Without
                  this, the child inherits CF's stdin handle on Windows,
                  which can wedge the JVM thread that called start(). --->
            <cfset pb.redirectInput(createObject("java", "java.io.File").init(variables.isWindows ? "NUL" : "/dev/null"))>
            <cfset logTrace("startProcess: '#arguments.label#' calling pb.start()")>
            <cfset variables.processes[arguments.label] = pb.start()>
            <cfset logTrace("startProcess: '#arguments.label#' started ok; logs at #logFile.getAbsolutePath()#")>
            <cflog file="island-build" type="information"
                   text="Coldspa: started '#arguments.label#' (#arrayToList(argList, ' ')#); logs at #logFile.getAbsolutePath()#">
            <cfcatch type="any">
                <cfset logTrace("startProcess: '#arguments.label#' FAILED: " & cfcatch.message & " " & cfcatch.detail)>
                <cflog file="island-build" type="error"
                       text="Coldspa: failed to start '#arguments.label#': #cfcatch.message# #cfcatch.detail#">
            </cfcatch>
        </cftry>
    </cffunction>

    <!--- Plain-text trace into WEB-INF/coldspa-logs/manager.log so we can
          see exactly what the manager did, even if cflog routing is off. --->
    <cffunction name="logTrace" access="private" returntype="void" output="false">
        <cfargument name="msg" type="string" required="true">
        <cftry>
            <cffile action="append"
                    file="#variables.logDir#/manager.log"
                    output="[#dateTimeFormat(now(), 'yyyy-mm-dd HH:nn:ss')#] #arguments.msg##chr(10)#"
                    addnewline="false">
            <cfcatch type="any"></cfcatch>
        </cftry>
    </cffunction>

    <cffunction name="ensureProdBuild" access="private" returntype="void" output="false">
        <cfset var manifestPath = variables.projectRoot & "dist/.vite/manifest.json">
        <cfif fileExists(manifestPath)>
            <cfreturn>
        </cfif>

        <cflog file="island-build" type="warning"
               text="Coldspa: production manifest missing at #manifestPath#. Falling back to `npm run build` -- this signals a broken deploy pipeline.">

        <cfset var argList = []>
        <cfif variables.isWindows>
            <cfset arrayAppend(argList, "cmd")>
            <cfset arrayAppend(argList, "/c")>
        </cfif>
        <cfset arrayAppend(argList, "npm")>
        <cfset arrayAppend(argList, "run")>
        <cfset arrayAppend(argList, "build")>

        <cfset var pb = createObject("java", "java.lang.ProcessBuilder").init(argList)>
        <cfset pb.directory(createObject("java", "java.io.File").init(variables.projectRoot))>
        <cfset pb.redirectErrorStream(true)>
        <cfset var logFile = createObject("java", "java.io.File").init(variables.logDir & "/build.log")>
        <cfset pb.redirectOutput(logFile)>

        <cfset var proc = pb.start()>
        <!--- Block until the build finishes or 5 minutes elapse. --->
        <cfset var unit = createObject("java", "java.util.concurrent.TimeUnit").MINUTES>
        <cfset var finished = proc.waitFor(javaCast("long", 5), unit)>

        <cfif !finished>
            <cfset proc.destroy()>
            <cfthrow type="Coldspa.BuildTimeout"
                     message="Coldspa fallback `npm run build` did not finish within 5 minutes. See #logFile.getAbsolutePath()#.">
        </cfif>

        <cfif proc.exitValue() neq 0>
            <cfthrow type="Coldspa.BuildFailed"
                     message="Coldspa fallback `npm run build` exited with code #proc.exitValue()#. See #logFile.getAbsolutePath()#.">
        </cfif>

        <cfif !fileExists(manifestPath)>
            <cfthrow type="Coldspa.BuildFailed"
                     message="Coldspa fallback `npm run build` succeeded but manifest still missing at #manifestPath#.">
        </cfif>

        <cflog file="island-build" type="information"
               text="Coldspa: fallback build completed; manifest at #manifestPath#.">
    </cffunction>

</cfcomponent>
