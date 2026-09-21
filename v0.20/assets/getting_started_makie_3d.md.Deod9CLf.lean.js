import{_ as t,C as n,ap as l,o as h,c as p,ao as i,E as o,w as k,a2 as r,j as d}from"./chunks/framework.DzdY91AP.js";const c="/PlantGeom.jl/v0.20/assets/mubzfda.Dm_CDT8T.png",g="/PlantGeom.jl/v0.20/assets/izolarv.BJxCSmbv.png",E="/PlantGeom.jl/v0.20/assets/jyhgzsl.CPdf9JCk.png",y="/PlantGeom.jl/v0.20/assets/gntlsuy.D53fzE4c.png",u="/PlantGeom.jl/v0.20/assets/ctcksyo.C4lC3dwD.png",m="/PlantGeom.jl/v0.20/assets/pxpablz.DyljxDlc.png",b="/PlantGeom.jl/v0.20/assets/ddxruxq.ChknX7Ie.png",v="/PlantGeom.jl/v0.20/assets/jkjpbdl.CKfasTbq.png",F="/PlantGeom.jl/v0.20/assets/jkjpbdl.CKfasTbq.png",C="/PlantGeom.jl/v0.20/assets/coffee_steps.B62IGE-s.mp4",q=JSON.parse('{"title":"3D Plotting with Makie.jl","description":"","frontmatter":{},"headers":[],"relativePath":"getting_started/makie_3d.md","filePath":"getting_started/makie_3d.md","lastUpdated":null}'),f={name:"getting_started/makie_3d.md"},w={class:"vp-raw-html",innerHTML:`<div><div data-jscall-id="root" id="62ceace0-4380-4098-a85a-a5a50a2759cd" class="bonito-fragment" style="display:contents"><div style="display:contents"><script src="bonito/js/Bonito.bundled5040008371911548254.js" type="module"><\/script><style></style><style>@media (prefers-color-scheme: light) {
  :root {
    --bonito-widget-hover-bg: #f3f4f6;
    color-scheme: light;
    --bonito-widget-muted-bg: #f3f4f6;
    accent-color: #3182bb;
    --bonito-widget-accent: #3182bb;
    --bonito-widget-fg: #1a1a1a;
    --bonito-widget-bg: #ffffff;
    --bonito-widget-border: #9ca3af;
  }
}
@media (prefers-color-scheme: dark) {
  :root {
    --bonito-widget-hover-bg: #3a3a40;
    color-scheme: dark;
    --bonito-widget-muted-bg: #36363c;
    accent-color: #6ea8e0;
    --bonito-widget-accent: #6ea8e0;
    --bonito-widget-fg: #e8e8ea;
    --bonito-widget-bg: #2a2a2e;
    --bonito-widget-border: #52525b;
  }
}
html .noUi-target {
  box-shadow: none;
  background: var(--bonito-widget-muted-bg, #fafafa);
  border-color: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-connects {
  background: var(--bonito-widget-muted-bg, #fafafa);
}
html .noUi-connect {
  background: var(--bonito-widget-accent, #3182bb);
}
html .noUi-handle {
  box-shadow: none;
  background: var(--bonito-widget-bg, #fff);
  border-color: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-handle::before {
  background: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-handle::after {
  background: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-tooltip {
  background: var(--bonito-widget-bg, #fff);
  border-color: var(--bonito-widget-border, #d3d3d3);
  color: var(--bonito-widget-fg, #000);
}
html .noUi-marker {
  background: var(--bonito-widget-border, #ccc);
}
html .noUi-value {
  color: var(--bonito-widget-fg, inherit);
}
</style></div><div style="display:contents"><script type="module">Bonito.init_session("62ceace0-4380-4098-a85a-a5a50a2759cd", Bonito.fetch_binary('bonito/bin/2c0f90bf9ed43162eb67139ce7b5fadcdc4ee97d-9142726317698534343.bin'), "root", false);
<\/script><div></div></div></div><div data-jscall-id="subsession-application-dom" id="adf33445-0d10-4a06-b4d5-52fcfa6fa842" class="bonito-fragment" style="display:contents"><div style="display:contents"><style></style><style>.wglmakie-spinner {
  animation: wglmakie-spin 1.0s linear infinite;
  position: absolute;
  left: 50%;
  z-index: 1000;
  border-radius: 50%;
  width: 40px;
  border: 4px solid rgba(0, 0, 0, 0.1);
  transform: translate(-50%, -50%);
  border-top: 4px solid currentColor;
  height: 40px;
  pointer-events: none;
  top: 50%;
}
@keyframes wglmakie-spin {
  100% {
    transform: translate(-50%, -50%) rotate(360deg);
  }
  0% {
    transform: translate(-50%, -50%) rotate(0deg);
  }
}
</style><script src="bonito/js/WGLMakie.bundled1870091951256107923.js" type="module"><\/script></div><div style="display:contents"><script type="module">Bonito.init_session("adf33445-0d10-4a06-b4d5-52fcfa6fa842", Bonito.fetch_binary('bonito/bin/d18177aa405425ac62209e84e64a1760e15fe7d3-7461624824075920602.bin'), "sub", false);
<\/script><div data-jscall-id="1" style="width: 100%; height: 100%; position: relative;"><canvas data-jscall-id="2" height="450px" data-lm-suppress-shortcuts="true" width="600px" data-jp-suppress-context-menu tabindex="0" style="display: block"></canvas><div data-jscall-id="3" class="wglmakie-spinner"></div></div></div></div></div>`};function _(B,s,x,D,A,j){const a=n("ClientOnly"),e=l("exec-scripts");return h(),p("div",null,[s[0]||(s[0]=i("",11)),o(a,null,{default:k(()=>[r(d("div",w,null,512),[[e]])]),_:1}),s[1]||(s[1]=i("",67))])}const P=t(f,[["render",_]]);export{q as __pageData,P as default};
