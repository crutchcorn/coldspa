/**
 * Spec: <cf_Island framework={React} strategy="load">
 *
 * React parity of IslandLoadStrategySpec. Same SSR + immediate-hydration
 * contract, exercised through a React-shaped mock framework struct so we
 * confirm Island.cfm doesn't favor Vue anywhere (mount div tagged "React",
 * React client entry imported in the boot script, JSX-style component path
 * threaded through to ssrRender).
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

		describe( "cf_Island strategy=load (React)", function(){

			beforeEach( function( currentSpec ){
				variables.ssrCalls = [];

				variables.mockReact = {
					"name":        "React",
					"clientEntry": "./coldspa/vite/clients/react-client.js",
					"ssrRender":   function( componentGlobKey, props, slotHtml, namedSlots ){
						arrayAppend( variables.ssrCalls, {
							"componentGlobKey": arguments.componentGlobKey,
							"props":            duplicate( arguments.props ),
							"slotHtml":         arguments.slotHtml,
							"namedSlots":       duplicate( arguments.namedSlots )
						} );
						return {
							"html":  "<p data-from-ssr=""yes"">SSR rendered: " & ( arguments.props.msg ?: "" ) & "</p>",
							"css":   ".coldspa-test{color:red}",
							"error": ""
						};
					},
					"render":      function( mountId, componentGlobKey, propsJson, resolvedClientEntry, optionsJson ){
						return {
							"imports": "import { mount } from '" & arguments.resolvedClientEntry & "';",
							"body":    "mount('" & arguments.componentGlobKey & "', document.getElementById('" & arguments.mountId & "'), " & arguments.propsJson & ", " & arguments.optionsJson & ");"
						};
					}
				};
			} );

			it( "calls framework.ssrRender exactly once with the component path, props, and empty slots", function(){
				renderIsland( framework = mockReact, path = "./Hello.jsx", props = { "msg": "hi" } );
				expect( arrayLen( ssrCalls ) ).toBe( 1 );
				expect( ssrCalls[1].componentGlobKey ).toBe( "/Hello.jsx" );
				expect( ssrCalls[1].props.msg ).toBe( "hi" );
				expect( ssrCalls[1].slotHtml ).toBe( "" );
				expect( structIsEmpty( ssrCalls[1].namedSlots ) ).toBeTrue();
			} );

			it( "injects the SSR HTML inside the React-tagged mount div", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = { "msg": "world" } );
				expect( html ).toMatch( '<div id="island-[a-f0-9]+" data-coldspa-island="React"><p data-from-ssr="yes">SSR rendered: world</p></div>' );
			} );

			it( "emits the SSR CSS in a tagged style element", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {} );
				expect( html ).toMatch( '<style data-coldspa-ssr="island-[a-f0-9]+">\.coldspa-test\{color:red\}</style>' );
			} );

			it( "emits an immediate boot script importing the React client entry (no idle / observer wrappers)", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {} );
				expect( html ).toInclude( '<script type="module">' );
				expect( html ).toInclude( "import { mount } from 'http://localhost:5173/coldspa/vite/clients/react-client.js';" );
				expect( html ).toInclude( "mount('/Hello.jsx', document.getElementById(" );
				expect( html ).notToInclude( "requestIdleCallback" );
				expect( html ).notToInclude( "IntersectionObserver" );
			} );

			it( "serializes mount options with strategy=load and hasSlot=false (no slot content)", function(){
				var html = renderIsland( framework = mockReact, path = "./Hello.jsx", props = {} );
				expect( html ).toMatch( '"strategy"\s*:\s*"load"' );
				expect( html ).toMatch( '"hasSlot"\s*:\s*false' );
			} );

			it( "passes default-slot HTML through to ssrRender and stashes it in a slot template", function(){
				var html = "";
				savecontent variable="html" {
					cf_Island(
						framework = mockReact,
						path      = "./Hello.jsx",
						props     = {},
						strategy  = "load"
					) {
						writeOutput( "<span class=""hello"">slotted!</span>" );
					}
				}
				expect( arrayLen( ssrCalls ) ).toBe( 1 );
				expect( ssrCalls[1].slotHtml ).toInclude( "slotted!" );
				expect( html ).toMatch( '<template id="slot-[a-f0-9]+" data-coldspa-slot="island-[a-f0-9]+">' );
				expect( html ).toInclude( "slotted!" );
				expect( html ).toMatch( '"hasSlot"\s*:\s*true' );
			} );

			it( "passes named slots through to ssrRender and emits one template per name", function(){
				var html = "";
				savecontent variable="html" {
					cf_Island(
						framework = mockReact,
						path      = "./Hello.jsx",
						props     = {},
						strategy  = "load"
					) {
						cf_Slot( name = "header" ) {
							writeOutput( "HEADER-CONTENT" );
						}
						cf_Slot( name = "footer" ) {
							writeOutput( "FOOTER-CONTENT" );
						}
					}
				}
				expect( arrayLen( ssrCalls ) ).toBe( 1 );
				expect( ssrCalls[1].namedSlots ).toHaveKey( "header" );
				expect( ssrCalls[1].namedSlots ).toHaveKey( "footer" );
				expect( ssrCalls[1].namedSlots.header ).toInclude( "HEADER-CONTENT" );
				expect( ssrCalls[1].namedSlots.footer ).toInclude( "FOOTER-CONTENT" );
				expect( html ).toMatch( '<template id="slot-[a-f0-9]+-header" data-coldspa-slot="island-[a-f0-9]+" data-coldspa-slot-name="header">HEADER-CONTENT</template>' );
				expect( html ).toMatch( '<template id="slot-[a-f0-9]+-footer" data-coldspa-slot="island-[a-f0-9]+" data-coldspa-slot-name="footer">FOOTER-CONTENT</template>' );
			} );

			it( "uses the framework name in the data-coldspa-island attribute", function(){
				// Swap the renderer name to prove it isn't hardcoded.
				mockReact.name = "Vue";
				var html = renderIsland( framework = mockReact, path = "./Hello.vue", props = {} );
				expect( html ).toInclude( 'data-coldspa-island="Vue"' );
			} );

		} );

	}

	private string function renderIsland(
		required struct framework,
		required string path,
		struct props      = {},
		string strategy   = "load"
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
