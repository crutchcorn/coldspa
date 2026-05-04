/**
 * Copyright Since 2005 Ortus Solutions, Corp
 * www.ortussolutions.com
 * *************************************************************************************
 */
component {

	this.name              = "A TestBox Runner Suite";
	// any other application.cfc stuff goes below:
	this.sessionManagement = true;

	// /tests points at the sibling specs directory (this app lives in /test-runner).
	variables.webroot = getDirectoryFromPath( getCurrentTemplatePath() ) & "../";
	this.mappings[ "/tests" ] = variables.webroot & "tests";
	// TestBox lives under /modules/testbox in this repo; the runner expects /testbox.
	this.mappings[ "/testbox" ] = variables.webroot & "modules/testbox";
	// Map /coldspa to the library directory at the webroot so specs can `new coldspa.X()`.
	this.mappings[ "/coldspa" ] = variables.webroot & "coldspa";
	// Custom tag path for <cf_Island> / <cf_Slot> (live at the webroot).
	this.customTagPaths = variables.webroot;
	// Turn on/off remote cfc content whitespace
	this.suppressRemoteComponentContent = false;

	// any orm definitions go here.

	// request start
	public boolean function onRequestStart( String targetPage ){
		return true;
	}

}
