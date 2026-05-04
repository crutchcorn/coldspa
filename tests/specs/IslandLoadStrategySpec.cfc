/**
 * Spec: <cf_Island> with strategy="load" (SSR + immediate hydration)
 *
 * The "load" strategy is the default. Island.cfm must:
 *   - call framework.ssrRender(componentPath, props, slotHtml, namedSlots)
 *   - inject the returned HTML into the mount div (so users see content
 *     before JS hydrates)
 *   - emit any returned CSS as a <style data-coldspa-ssr="..."> tag
 *   - emit a <template id="slot-..."> for the default slot when slot HTML
 *     is present
 *   - emit one named-slot <template> per entry in namedSlots
 *   - emit an immediate boot <script type="module"> (no requestIdleCallback,
 *     no IntersectionObserver wrapper)
 *   - serialize mount options with strategy="load"
 *
 * Like the client spec, this is hermetic: a mock framework struct stands
 * in for Vue/React so we don't depend on the SSR sidecar.
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

		describe( "cf_Island strategy=load", function(){

			beforeEach( function( currentSpec ){
				// Tracks each call into the mock framework so we can assert
				// what Island.cfm passed (component path, props, slots).
				variables.ssrCalls = [];

				variables.mockVue = {
					"name":        "Vue",
					"clientEntry": "./coldspa/vite/clients/vue-client.js",
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
				renderIsland( framework = mockVue, path = "./Hello.vue", props = { "msg": "hi" } );
				expect( arrayLen( ssrCalls ) ).toBe( 1 );
				expect( ssrCalls[1].componentGlobKey ).toBe( "/Hello.vue" );
				expect( ssrCalls[1].props.msg ).toBe( "hi" );
				expect( ssrCalls[1].slotHtml ).toBe( "" );
				expect( structIsEmpty( ssrCalls[1].namedSlots ) ).toBeTrue();
			} );

			it( "injects the SSR HTML inside the mount div", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = { "msg": "world" } );
				// The <div id="island-..."> wraps whatever ssrRender returned.
				expect( html ).toMatch( '<div id="island-[a-f0-9]+" data-coldspa-island="Vue"><p data-from-ssr="yes">SSR rendered: world</p></div>' );
			} );

			it( "emits the SSR CSS in a tagged style element", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {} );
				expect( html ).toMatch( '<style data-coldspa-ssr="island-[a-f0-9]+">\.coldspa-test\{color:red\}</style>' );
			} );

			it( "emits an immediate boot script (no idle / observer wrappers)", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {} );
				expect( html ).toInclude( '<script type="module">' );
				expect( html ).toInclude( "import { mount } from 'http://localhost:5173/coldspa/vite/clients/vue-client.js';" );
				expect( html ).toInclude( "mount('/Hello.vue', document.getElementById(" );
				expect( html ).notToInclude( "requestIdleCallback" );
				expect( html ).notToInclude( "IntersectionObserver" );
			} );

			it( "serializes mount options with strategy=load and hasSlot=false (no slot content)", function(){
				var html = renderIsland( framework = mockVue, path = "./Hello.vue", props = {} );
				expect( html ).toMatch( '"strategy"\s*:\s*"load"' );
				expect( html ).toMatch( '"hasSlot"\s*:\s*false' );
			} );

			it( "passes default-slot HTML through to ssrRender and stashes it in a slot template", function(){
				var html = "";
				savecontent variable="html" {
					cf_Island(
						framework = mockVue,
						path      = "./Hello.vue",
						props     = {},
						strategy  = "load"
					) {
						writeOutput( "<span class=""hello"">slotted!</span>" );
					}
				}
				expect( arrayLen( ssrCalls ) ).toBe( 1 );
				expect( ssrCalls[1].slotHtml ).toInclude( "slotted!" );
				// Slot HTML stashed in a template for the client to mount.
				expect( html ).toMatch( '<template id="slot-[a-f0-9]+" data-coldspa-slot="island-[a-f0-9]+">' );
				expect( html ).toInclude( "slotted!" );
				// hasSlot now flips to true in mount options.
				expect( html ).toMatch( '"hasSlot"\s*:\s*true' );
			} );

			it( "passes named slots through to ssrRender and emits one template per name", function(){
				var html = "";
				savecontent variable="html" {
					cf_Island(
						framework = mockVue,
						path      = "./Hello.vue",
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
				// Each named slot gets its own <template> tagged with the slot name.
				expect( html ).toMatch( '<template id="slot-[a-f0-9]+-header" data-coldspa-slot="island-[a-f0-9]+" data-coldspa-slot-name="header">HEADER-CONTENT</template>' );
				expect( html ).toMatch( '<template id="slot-[a-f0-9]+-footer" data-coldspa-slot="island-[a-f0-9]+" data-coldspa-slot-name="footer">FOOTER-CONTENT</template>' );
			} );

			it( "uses the framework name in the data-coldspa-island attribute", function(){
				// Swap the renderer name to prove it isn't hardcoded.
				mockVue.name = "React";
				var html = renderIsland( framework = mockVue, path = "./Hello.jsx", props = {} );
				expect( html ).toInclude( 'data-coldspa-island="React"' );
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
