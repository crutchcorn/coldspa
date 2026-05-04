/**
 * Spec: coldspa/renderers/Vue.cfm
 *
 * Validates the Vue renderer struct in isolation: that it produces the
 * { imports, body } shape Island.cfm expects and threads the mount id /
 * component path / props / options into the boot script.
 *
 * Unlike React, Vue has no dev-only preamble, so render() is mode-agnostic
 * (the dev/prod difference shows up in the resolved client entry URL,
 * which is computed by Island.cfm and passed in here).
 *
 * The SSR sidecar is not tested here; it's covered by integration.
 */
component extends="testbox.system.BaseSpec" {

	function beforeAll(){
		// Vue.render doesn't read application.coldspaConfig, but ssrRender
		// would on first call. Keep a sane default in scope.
		application.coldspaConfig = {
			"isDev":    true,
			"debug":    false,
			"vitePort": "5173",
			"viteUrl":  "http://localhost:5173",
			"ssrUrl":   "http://127.0.0.1:5174"
		};
	}

	function run(){

		describe( "coldspa/renderers/Vue.cfm", function(){

			beforeEach( function( currentSpec ){
				variables.Vue = loadVueRenderer();
			} );

			it( "exposes the expected renderer struct shape", function(){
				expect( Vue ).toBeStruct();
				expect( Vue.name ).toBe( "Vue" );
				expect( Vue.clientEntry ).toBe( "./coldspa/vite/clients/vue-client.js" );
				expect( isCustomFunction( Vue.render ) ).toBeTrue();
				expect( isCustomFunction( Vue.ssrRender ) ).toBeTrue();
			} );

			it( "render() returns { imports, body } strings", function(){
				var rendered = Vue.render(
					mountId             = "island-abc123",
					componentGlobKey    = "/Hello.vue",
					propsJson           = '{"msg":"hi"}',
					resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/vue-client.js",
					optionsJson         = '{"strategy":"load","hasSlot":false}'
				);
				expect( rendered ).toHaveKey( "imports" );
				expect( rendered ).toHaveKey( "body" );
				expect( rendered.imports ).toBeString();
				expect( rendered.body ).toBeString();
			} );

			it( "render() imports the resolved client entry under a mount-id-scoped alias", function(){
				var rendered = Vue.render(
					mountId             = "island-abc123",
					componentGlobKey    = "/Hello.vue",
					propsJson           = "{}",
					resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/vue-client.js",
					optionsJson         = "{}"
				);
				// Hyphens replaced with underscores for a JS-safe identifier.
				expect( rendered.imports ).toInclude( "import { mount as __coldspa_mount_island_abc123 } from 'http://localhost:5173/coldspa/vite/clients/vue-client.js';" );
			} );

			it( "render() body invokes the aliased mount with component path, mount element, props, and options", function(){
				var rendered = Vue.render(
					mountId             = "island-abc123",
					componentGlobKey    = "/Hello.vue",
					propsJson           = '{"msg":"hi"}',
					resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/vue-client.js",
					optionsJson         = '{"strategy":"load","hasSlot":false}'
				);
				expect( rendered.body ).toInclude( "__coldspa_mount_island_abc123(" );
				expect( rendered.body ).toInclude( "'/Hello.vue'" );
				expect( rendered.body ).toInclude( "document.getElementById('island-abc123')" );
				expect( rendered.body ).toInclude( '{"msg":"hi"}' );
				expect( rendered.body ).toInclude( '{"strategy":"load","hasSlot":false}' );
			} );

			it( "does NOT inject any React Fast Refresh preamble", function(){
				var rendered = Vue.render(
					mountId             = "island-abc123",
					componentGlobKey    = "/Hello.vue",
					propsJson           = "{}",
					resolvedClientEntry = "http://localhost:5173/coldspa/vite/clients/vue-client.js",
					optionsJson         = "{}"
				);
				expect( rendered.imports ).notToInclude( "@react-refresh" );
				expect( rendered.imports ).notToInclude( "RefreshRuntime" );
			} );

			it( "render() output is identical regardless of isDev (it doesn't branch on mode)", function(){
				var argsCommon = {
					mountId             : "island-abc123",
					componentGlobKey    : "/Hello.vue",
					propsJson           : "{}",
					resolvedClientEntry : "http://localhost:5173/coldspa/vite/clients/vue-client.js",
					optionsJson         : "{}"
				};
				application.coldspaConfig.isDev = true;
				var dev = loadVueRenderer().render( argumentCollection = argsCommon );
				application.coldspaConfig.isDev = false;
				var prod = loadVueRenderer().render( argumentCollection = argsCommon );
				expect( dev.imports ).toBe( prod.imports );
				expect( dev.body ).toBe( prod.body );
			} );

		} );

	}

	/**
	 * The renderer is a .cfm that defines a `Vue` variable. Wrap an
	 * include in a function so each call gives us a fresh struct under
	 * the current application.coldspaConfig.
	 */
	private struct function loadVueRenderer(){
		var Vue = "";
		include "/coldspa/renderers/Vue.cfm";
		return Vue;
	}

}
