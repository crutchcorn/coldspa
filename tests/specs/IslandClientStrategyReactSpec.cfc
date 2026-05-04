/**
 * Spec: <cf_Island framework={React} strategy="client">
 *
 * React parity of IslandClientStrategySpec. Island.cfm is framework-agnostic
 * (it dispatches via the framework struct's .name / .clientEntry / .render /
 * .ssrRender), so this spec proves the same client-strategy contract holds
 * when a React-shaped struct is plugged in: no SSR call, no SSR HTML/CSS,
 * empty mount div, boot script with the React client entry.
 */
component extends="testbox.system.BaseSpec" {

	function beforeAll(){
		application.coldspaConfig = {
			"isDev":    true,
			"debug":    false,
			"vitePort": "5173",
			"viteUrl":  "http://localhost:5173",
			"ssrUrl":   "http://127.0.0.1:5174"
		};
	}

	function run(){

		describe( "cf_Island strategy=client (React)", function(){

			beforeEach( function( currentSpec ){
				variables.ssrCallCount = 0;

				variables.mockReact = {
					"name":        "React",
					"clientEntry": "./coldspa/vite/clients/react-client.js",
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
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = { "msg": "hi" }, strategy = "client" );
				expect( ssrCallCount ).toBe( 0, "ssrRender must not run when strategy=client" );
				expect( html ).notToInclude( "SHOULD NOT APPEAR" );
			} );

			it( "emits an empty mount div tagged for React (no SSR HTML inside)", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {}, strategy = "client" );
				expect( html ).toMatch( '<div id="island-[a-f0-9]+" data-coldspa-island="React"></div>' );
			} );

			it( "does not emit any SSR style or link tags", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {}, strategy = "client" );
				expect( html ).notToInclude( "data-coldspa-ssr" );
			} );

			it( "does not emit a slot template when there are no slots", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {}, strategy = "client" );
				expect( html ).notToInclude( "<template" );
				expect( html ).notToInclude( "data-coldspa-slot" );
			} );

			it( "emits a script module tag with the mount call importing the React client entry", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = { "msg": "hi" }, strategy = "client" );
				expect( html ).toInclude( '<script type="module">' );
				expect( html ).toInclude( "import { mount } from 'http://localhost:5173/coldspa/vite/clients/react-client.js';" );
				expect( html ).toInclude( "mount('/Hello.jsx', document.getElementById(" );
			} );

			it( "serializes mount options with strategy:'client' and hasSlot:false", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {}, strategy = "client" );
				expect( html ).toMatch( '"strategy"\s*:\s*"client"' );
				expect( html ).toMatch( '"hasSlot"\s*:\s*false' );
			} );

			it( "serializes the props the caller passed", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = { "msg": "hello world" }, strategy = "client" );
				expect( html ).toInclude( '"msg":"hello world"' );
			} );

			it( "does NOT wrap the boot in requestIdleCallback or IntersectionObserver", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {}, strategy = "client" );
				expect( html ).notToInclude( "requestIdleCallback" );
				expect( html ).notToInclude( "IntersectionObserver" );
			} );

		} );

	}

	private string function renderIsland(
		required struct framework,
		required string path,
		struct props      = {},
		string strategy   = "client"
	){
		var out = "";
		savecontent variable="out" {
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
