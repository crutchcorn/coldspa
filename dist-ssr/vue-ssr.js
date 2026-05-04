import { createSSRApp } from "vue";
import { renderToString } from "vue/server-renderer";
const components = /* @__PURE__ */ Object.assign({ "/src/App.vue": () => import("./App.js") });
async function render(componentPath, props) {
  const loader = components[componentPath];
  if (!loader) {
    throw new Error(`[Coldspa SSR] No Vue component registered for path "${componentPath}".`);
  }
  const mod = await loader();
  const app = createSSRApp(mod.default, props);
  return await renderToString(app);
}
export {
  render
};
