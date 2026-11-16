import{_ as t,C as n,ap as l,o as h,c as p,ao as i,E as o,w as k,a2 as r,j as d}from"./chunks/framework.DzN8FtW5.js";const c="/PlantGeom.jl/previews/PR182/assets/jjxgmra.Dm_CDT8T.png",g="/PlantGeom.jl/previews/PR182/assets/rjilohe.BJxCSmbv.png",E="/PlantGeom.jl/previews/PR182/assets/cdpqhhb.CPdf9JCk.png",y="/PlantGeom.jl/previews/PR182/assets/uqgnmbj.D53fzE4c.png",u="/PlantGeom.jl/previews/PR182/assets/vgvwtsu.C4lC3dwD.png",m="/PlantGeom.jl/previews/PR182/assets/rxniqye.DyljxDlc.png",b="/PlantGeom.jl/previews/PR182/assets/wxhosjy.ChknX7Ie.png",v="/PlantGeom.jl/previews/PR182/assets/jatxcbf.CKfasTbq.png",F="/PlantGeom.jl/previews/PR182/assets/jatxcbf.CKfasTbq.png",C="/PlantGeom.jl/previews/PR182/assets/coffee_steps.HcgRHPIE.mp4",P=JSON.parse('{"title":"3D Plotting with Makie.jl","description":"","frontmatter":{},"headers":[],"relativePath":"getting_started/makie_3d.md","filePath":"getting_started/makie_3d.md","lastUpdated":null}'),f={name:"getting_started/makie_3d.md"},w={class:"vp-raw-html",innerHTML:`<div><div data-jscall-id="root" id="f85b2aec-95b6-4af6-803d-a375f3553604" class="bonito-fragment" style="display:contents"><div style="display:contents"><script src="bonito/js/Bonito.bundled18292985539897097442.js" type="module"><\/script><style></style><style>@media (prefers-color-scheme: light) {
  :root {
    color-scheme: light;
    accent-color: #3182bb;
    --bonito-widget-bg: #ffffff;
    --bonito-widget-fg: #1a1a1a;
    --bonito-widget-border: #9ca3af;
    --bonito-widget-hover-bg: #f3f4f6;
    --bonito-widget-muted-bg: #f3f4f6;
    --bonito-widget-accent: #3182bb;
  }
}
@media (prefers-color-scheme: dark) {
  :root {
    color-scheme: dark;
    accent-color: #6ea8e0;
    --bonito-widget-bg: #2a2a2e;
    --bonito-widget-fg: #e8e8ea;
    --bonito-widget-border: #52525b;
    --bonito-widget-hover-bg: #3a3a40;
    --bonito-widget-muted-bg: #36363c;
    --bonito-widget-accent: #6ea8e0;
  }
}
html .noUi-target {
  background: var(--bonito-widget-muted-bg, #fafafa);
  border-color: var(--bonito-widget-border, #d3d3d3);
  box-shadow: none;
}
html .noUi-connects {
  background: var(--bonito-widget-muted-bg, #fafafa);
}
html .noUi-connect {
  background: var(--bonito-widget-accent, #3182bb);
}
html .noUi-handle {
  background: var(--bonito-widget-bg, #fff);
  border-color: var(--bonito-widget-border, #d3d3d3);
  box-shadow: none;
}
html .noUi-handle::before {
  background: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-handle::after {
  background: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-tooltip {
  background: var(--bonito-widget-bg, #fff);
  color: var(--bonito-widget-fg, #000);
  border-color: var(--bonito-widget-border, #d3d3d3);
}
html .noUi-marker {
  background: var(--bonito-widget-border, #ccc);
}
html .noUi-value {
  color: var(--bonito-widget-fg, inherit);
}
</style></div><div style="display:contents"><script type="module">Bonito.init_session("f85b2aec-95b6-4af6-803d-a375f3553604", Bonito.fetch_binary('bonito/bin/ada725f758ade7ee9170ae2264981ad30c44d291-16178127514618317332.bin'), "root", false);
<\/script><div></div></div></div><div data-jscall-id="subsession-application-dom" id="418a6b36-3d00-4847-af84-b823978d5567" class="bonito-fragment" style="display:contents"><div style="display:contents"><style></style><style>.wglmakie-spinner {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 40px;
  height: 40px;
  border: 4px solid rgba(0, 0, 0, 0.1);
  border-top: 4px solid currentColor;
  border-radius: 50%;
  animation: wglmakie-spin 1.0s linear infinite;
  z-index: 1000;
  pointer-events: none;
}
@keyframes wglmakie-spin {
  0% {
    transform: translate(-50%, -50%) rotate(0deg);
  }
  100% {
    transform: translate(-50%, -50%) rotate(360deg);
  }
}
</style><script src="bonito/js/WGLMakie.bundled1870091951256107923.js" type="module"><\/script></div><div style="display:contents"><script type="module">Bonito.init_session("418a6b36-3d00-4847-af84-b823978d5567", Bonito.fetch_binary('bonito/bin/7817f89baea294b13e127dad72b67925a387f354-963070406969799974.bin'), "sub", false);
<\/script><div data-jscall-id="1" style="width: 100%; height: 100%; position: relative;"><canvas data-jscall-id="2" height="450px" data-lm-suppress-shortcuts="true" width="600px" data-jp-suppress-context-menu tabindex="0" style="display: block"></canvas><div data-jscall-id="3" class="wglmakie-spinner"></div></div></div></div></div>`};function _(B,s,x,D,A,j){const a=n("ClientOnly"),e=l("exec-scripts");return h(),p("div",null,[s[0]||(s[0]=i("",11)),o(a,null,{default:k(()=>[r(d("div",w,null,512),[[e]])]),_:1}),s[1]||(s[1]=i("",67))])}const q=t(f,[["render",_]]);export{P as __pageData,q as default};
