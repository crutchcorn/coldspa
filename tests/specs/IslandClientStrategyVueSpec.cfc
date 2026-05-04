/**
 * Spec: <cf_Island framework={Vue} strategy="client">
 *
 * The "client" strategy is the no-SSR contract: Island.cfm must NOT call the
 * framework's ssrRender(), must NOT emit SSR HTML / CSS / link tags, and must
 * still emit a boot script that the client uses to mount the component.
 *
 * We use a mock framework struct shaped like the one Vue.cfm produces, so
 * the spec is hermetic — no Vite, no SSR sidecar, no network. React parity
 * for this contract lives in IslandClientStrategyReactSpec.cfc.
 */
component extends="testbox.system.BaseSpec" {

	function beforeAll(){
		// Pretend we're in dev so resolveAsset() doesn't try to read
		// /dist/.vite/manifest.json — it'll hand back a vite URL instead.
		application.coldspaConfig = {
			"isDev":    true,
			"debug":    false,
			"vitePort": "5173",
			"viteUrl":  "http://localhost:5173",
			"ssrUrl":   "http://127.0.0.1:5174"
		};
	}

	function run(){

		describe( "cf_Island strategy=client (Vue)", function(){

			beforeEach( function( currentSpec ){
				// Tracks whether the framework's ssrRender() was invoked.
				// strategy=client must skip it entirely.
				variables.ssrCallCount = 0;

				variables.mockVue = {
					"name":        "Vue",
					"clientEntry": "./coldspa/vite/clients/vue-client.js",
					"ssrRender":   function( componentGlobKey, props, slotHtml, namedSlots ){
						variables.ssrCallCount++;
						return { "html": "<p>SHOULD NOT APPEAR</p>", "css": "", "error": "" };
					},
					"render":      function( mountId, componentGlobKey, propsJson, resolvedClientEntry, optionsJson ){
						return {
							"imports": "import { mount } from '" & arguments.resolvedClientEntry & "';",
							"body":    "mount('" & arguments.componentGlobKey & "', document.getElementById('" & arguments.mountId & "'), " & arguments.propsJson & ", " & arguments.optionsJson & ");"
						};
					}
				};
			} );

			it( "skips SSR entirely (does not call framework.ssrRender)", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = { "msg": "hi" }, strategy = "client" );
				expect( ssrCallCount ).toBe( 0, "ssrRender must not run when strategy=client" );
				expect( html ).notToInclude( "SHOULD NOT APPEAR" );
			} );

			it( "emits an empty mount div (no SSR HTML inside)", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {}, strategy = "client" );
				// Match the empty mount div: <div id="island-..." data-coldspa-island="Vue"></div>
				expect( html ).toMatch( '<div id="island-[a-f0-9]+" data-coldspa-island="Vue"></div>' );
			} );

			it( "does not emit any SSR style or link tags", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {}, strategy = "client" );
				expect( html ).notToInclude( "data-coldspa-ssr" );
			} );

			it( "does not emit a slot template when there are no slots", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {}, strategy = "client" );
				expect( html ).notToInclude( "<template" );
				expect( html ).notToInclude( "data-coldspa-slot" );
			} );

			it( "emits a script module tag with the mount call", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = { "msg": "hi" }, strategy = "client" );
				expect( html ).toInclude( '<script type="module">' );
				expect( html ).toInclude( "import { mount } from 'http://localhost:5173/coldspa/vite/clients/vue-client.js';" );
				expect( html ).toInclude( "mount('/Hello.vue', document.getElementById(" );
			} );

			it( "serializes mount options with strategy:'client' and hasSlot:false", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {}, strategy = "client" );
				// JSON key casing comes from serializeJSON; ACF preserves the literal keys we passed.
				expect( html ).toMatch( '"strategy"\s*:\s*"client"' );
				expect( html ).toMatch( '"hasSlot"\s*:\s*false' );
			} );

			it( "serializes the props the caller passed", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = { "msg": "hello world" }, strategy = "client" );
				expect( html ).toInclude( '"msg":"hello world"' );
			} );

			it( "does NOT wrap the boot in requestIdleCallback or IntersectionObserver", function(){
				// "client" shares the immediate-boot case with "load".
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {}, strategy = "client" );
				expect( html ).notToInclude( "requestIdleCallback" );
				expect( html ).notToInclude( "IntersectionObserver" );
			} );

		} );

	}

	/**
	 * Helper: invoke <cf_Island> and return the produced HTML.
	 *
	 * Wrapped in cfsavecontent because the custom tag writes into
	 * thisTag.generatedContent in its end pass, which is what gets
	 * emitted at the </cf_Island> close.
	 */
	private string function renderIsland(
		required struct framework,
		required string path,
		struct props      = {},
		string strategy   = "client"
	){
		var out = "";
		savecontent variable="out" {
			// Script-form custom tag call. Resolves via this.customTagPaths
			// configured in tests/Application.cfc.
			cf_Island(
				framework = arguments.framework,
				path      = arguments.path,
				props     = arguments.props,
				strategy  = arguments.strategy
			);
		}
		return out;
	}

}
