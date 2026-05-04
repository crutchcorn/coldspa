/**
 * Spec: coldspa/renderers/React.cfm
 *
 * Validates the React renderer struct in isolation: that it produces the
 * { imports, body } shape Island.cfm expects, that it threads the mount
 * id / component path / props / options into the boot script, and that
 * it injects the React Fast Refresh preamble in dev mode (and only in
 * dev mode -- prod must stay clean so the manifest-driven bundle works).
 *
 * The SSR sidecar is not tested here; it's covered by integration.
 */
component extends="testbox.system.BaseSpec" {

	function run(){

		describe( "coldspa/renderers/React.cfm", function(){

			describe( "in dev mode", function(){

				beforeEach( function( currentSpec ){
					application.coldspaConfig = {
						"isDev":    true,
						"debug":    false,
						"vitePort": "5173",
						"viteUrl":  "http://localhost:5173",
						"ssrUrl":   "http://127.0.0.1:5174"
					};
					variables.React = loadReactRenderer();
				} );

				it( "exposes the expected renderer struct shape", function(){
					expect( React ).toBeStruct();
					expect( React.name ).toBe( "React" );
					expect( React.clientEntry ).toBe( "./coldspa/vite/clients/react-client.js" );
					expect( isCustomFunction( React.render ) ).toBeTrue();
					expect( isCustomFunction( React.ssrRender ) ).toBeTrue();
				} );

				it( "render() returns { imports, body } strings", function(){
					var rendered = React.render(
						mountId             = "island-abc123",
						componentGlobKey    = "/Hello.jsx",
						propsJson           = '{"msg":"hi"}',
						resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/react-client.js",
						optionsJson         = '{"strategy":"load","hasSlot":false}'
					);
					expect( rendered ).toHaveKey( "imports" );
					expect( rendered ).toHaveKey( "body" );
					expect( rendered.imports ).toBeString();
					expect( rendered.body ).toBeString();
				} );

				it( "render() imports the resolved client entry under a mount-id-scoped alias", function(){
					var rendered = React.render(
						mountId             = "island-abc123",
						componentGlobKey    = "/Hello.jsx",
						propsJson           = "{}",
						resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/react-client.js",
						optionsJson         = "{}"
					);
					// The alias replaces hyphens with underscores so it's a valid JS identifier.
					expect( rendered.imports ).toInclude( "import { mount as __coldspa_mount_island_abc123 } from 'http://localhost:5173/coldspa/vite/clients/react-client.js';" );
				} );

				it( "render() body invokes the aliased mount with component path, mount element, props, and options", function(){
					var rendered = React.render(
						mountId             = "island-abc123",
						componentGlobKey    = "/Hello.jsx",
						propsJson           = '{"msg":"hi"}',
						resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/react-client.js",
						optionsJson         = '{"strategy":"load","hasSlot":false}'
					);
					expect( rendered.body ).toInclude( "__coldspa_mount_island_abc123(" );
					expect( rendered.body ).toInclude( "'/Hello.jsx'" );
					expect( rendered.body ).toInclude( "document.getElementById('island-abc123')" );
					expect( rendered.body ).toInclude( '{"msg":"hi"}' );
					expect( rendered.body ).toInclude( '{"strategy":"load","hasSlot":false}' );
				} );

				it( "injects the React Fast Refresh preamble in dev mode", function(){
					var rendered = React.render(
						mountId             = "island-abc123",
						componentGlobKey    = "/Hello.jsx",
						propsJson           = "{}",
						resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/react-client.js",
						optionsJson         = "{}"
					);
					// Pulled from the configured viteUrl.
					expect( rendered.imports ).toInclude( "import RefreshRuntime from 'http://localhost:5173/@react-refresh';" );
					expect( rendered.imports ).toInclude( "RefreshRuntime.injectIntoGlobalHook(window)" );
					// Idempotency guard so multiple islands on one page don't double-install.
					expect( rendered.imports ).toInclude( "__vite_plugin_react_preamble_installed__" );
				} );

				it( "falls back to vitePort when viteUrl is not configured", function(){
					structDelete( application.coldspaConfig, "viteUrl" );
					application.coldspaConfig.vitePort = "5999";
					variables.React = loadReactRenderer();
					var rendered = React.render(
						mountId             = "island-x",
						componentGlobKey    = "/Hello.jsx",
						propsJson           = "{}",
						resolvedClientEntry = "http://localhost:5999/coldspa/vite/clients/react-client.js",
						optionsJson         = "{}"
					);
					expect( rendered.imports ).toInclude( "http://localhost:5999/@react-refresh" );
				} );

			} );

			describe( "in prod mode", function(){

				beforeEach( function( currentSpec ){
					application.coldspaConfig = {
						"isDev":    false,
						"debug":    false,
						"vitePort": "5173",
						"viteUrl":  "http://localhost:5173",
						"ssrUrl":   "http://127.0.0.1:5174"
					};
					variables.React = loadReactRenderer();
				} );

				it( "does NOT inject the Fast Refresh preamble in prod mode", function(){
					var rendered = React.render(
						mountId             = "island-abc123",
						componentGlobKey    = "/Hello.jsx",
						propsJson           = "{}",
						resolvedClientEntry = "/dist/assets/react-client.abc123.js",
						optionsJson         = "{}"
					);
					expect( rendered.imports ).notToInclude( "@react-refresh" );
					expect( rendered.imports ).notToInclude( "RefreshRuntime" );
					expect( rendered.imports ).notToInclude( "__vite_plugin_react_preamble_installed__" );
					// The actual client mount import still ships in prod.
					expect( rendered.imports ).toInclude( "import { mount as __coldspa_mount_island_abc123 } from '/dist/assets/react-client.abc123.js';" );
				} );

			} );

		} );

	}

	/**
	 * The renderer is a .cfm that defines a `React` variable. Wrap an
	 * include in a function so each call gives us a fresh struct that
	 * picked up the current application.coldspaConfig.
	 */
	private struct function loadReactRenderer(){
		var React = "";
		include "/coldspa/renderers/React.cfm";
		return React;
	}

}
