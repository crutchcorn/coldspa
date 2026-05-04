import { ref, mergeProps, useSSRContext } from "vue";
import { ssrRenderAttrs, ssrInterpolate } from "vue/server-renderer";
const _export_sfc = (sfc, props) => {
  const target = sfc.__vccOpts || sfc;
  for (const [key, val] of props) {
    target[key] = val;
  }
  return target;
};
const _sfc_main = {
  __name: "App",
  __ssrInlineRender: true,
  props: {
    hello: { type: String, default: "" },
    serverTime: { type: String, default: "" }
  },
  setup(__props) {
    const count = ref(0);
    return (_ctx, _push, _parent, _attrs) => {
      _push(`<div${ssrRenderAttrs(mergeProps({ class: "island" }, _attrs))} data-v-f4406005><h2 data-v-f4406005>Hello, ${ssrInterpolate(__props.hello)}!</h2><p data-v-f4406005>Rendered server-side at: <code data-v-f4406005>${ssrInterpolate(__props.serverTime)}</code></p><p data-v-f4406005>Hydrated client-side by Vue.</p><button data-v-f4406005>${ssrInterpolate(count.value)}</button></div>`);
    };
  }
};
const _sfc_setup = _sfc_main.setup;
_sfc_main.setup = (props, ctx) => {
  const ssrContext = useSSRContext();
  (ssrContext.modules || (ssrContext.modules = /* @__PURE__ */ new Set())).add("src/App.vue");
  return _sfc_setup ? _sfc_setup(props, ctx) : void 0;
};
const App = /* @__PURE__ */ _export_sfc(_sfc_main, [["__scopeId", "data-v-f4406005"]]);
export {
  App as default
};
