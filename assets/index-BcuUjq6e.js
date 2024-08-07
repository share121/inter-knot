(function(){const g=document.createElement("link").relList;if(g&&g.supports&&g.supports("modulepreload"))return;for(const m of document.querySelectorAll('link[rel="modulepreload"]'))w(m);new MutationObserver(m=>{for(const d of m)if(d.type==="childList")for(const y of d.addedNodes)y.tagName==="LINK"&&y.rel==="modulepreload"&&w(y)}).observe(document,{childList:!0,subtree:!0});function T(m){const d={};return m.integrity&&(d.integrity=m.integrity),m.referrerPolicy&&(d.referrerPolicy=m.referrerPolicy),m.crossOrigin==="use-credentials"?d.credentials="include":m.crossOrigin==="anonymous"?d.credentials="omit":d.credentials="same-origin",d}function w(m){if(m.ep)return;m.ep=!0;const d=T(m);fetch(m.href,d)}})();var Q=typeof globalThis<"u"?globalThis:typeof window<"u"?window:typeof global<"u"?global:typeof self<"u"?self:{};function Y(p){return p&&p.__esModule&&Object.prototype.hasOwnProperty.call(p,"default")?p.default:p}var U={exports:{}};(function(p,g){(function(T,w){p.exports=w()})(Q,function(){function T(e,t){var n=void 0;return function(){n&&clearTimeout(n),n=setTimeout(e,t)}}function w(e,t){for(var n=e.length,r=n,c=[];n--;)c.push(t(e[r-n-1]));return c}function m(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2];if(window.Promise)return q(e,t,n);e.recalculate(!0,!0)}function d(e){for(var t=e.options,n=e.responsiveOptions,r=e.keys,c=e.docWidth,i=void 0,a=0;a<r.length;a++){var l=parseInt(r[a],10);c>=l&&(i=t.breakAt[l],P(i,n))}return n}function y(e){for(var t=e.options,n=e.responsiveOptions,r=e.keys,c=e.docWidth,i=void 0,a=r.length-1;a>=0;a--){var l=parseInt(r[a],10);c<=l&&(i=t.breakAt[l],P(i,n))}return n}function S(e){var t=e.useContainerForBreakpoints?e.container.clientWidth:window.innerWidth,n={columns:e.columns};_(e.margin)?n.margin={x:e.margin.x,y:e.margin.y}:n.margin={x:e.margin,y:e.margin};var r=Object.keys(e.breakAt);return e.mobileFirst?d({options:e,responsiveOptions:n,keys:r,docWidth:t}):y({options:e,responsiveOptions:n,keys:r,docWidth:t})}function L(e){return S(e).columns}function A(e){return S(e).margin}function M(e){var t=!(arguments.length>1&&arguments[1]!==void 0)||arguments[1],n=L(e),r=A(e).x,c=100/n;if(!t)return c;if(n===1)return"100%";var i="px";if(typeof r=="string"){var a=parseFloat(r);i=r.replace(a,""),r=a}return r=(n-1)*r/n,i==="%"?c-r+"%":"calc("+c+"% - "+r+i+")"}function C(e,t){var n=L(e.options),r=0,c=void 0,i=void 0;if(++t===1)return 0;i=A(e.options).x;var a="px";if(typeof i=="string"){var l=parseFloat(i,10);a=i.replace(l,""),i=l}return c=(i-(n-1)*i/n)*(t-1),r+=M(e.options,!1)*(t-1),a==="%"?r+c+"%":"calc("+r+"% + "+c+a+")"}function x(e){var t=0,n=e.container,r=e.rows;u(r,function(c){t=c>t?c:t}),n.style.height=t+"px"}function k(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2],r=!(arguments.length>3&&arguments[3]!==void 0)||arguments[3],c=L(e.options),i=A(e.options).y;$(e,c,n),u(t,function(a){var l=0,O=parseInt(a.offsetHeight,10);isNaN(O)||(e.rows.forEach(function(Z,J){Z<e.rows[l]&&(l=J)}),a.style.position="absolute",a.style.top=e.rows[l]+"px",a.style.left=""+e.cols[l],e.rows[l]+=isNaN(O)?0:O+i,r&&(a.dataset.macyComplete=1))}),r&&(e.tmpRows=null),x(e)}function s(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2],r=!(arguments.length>3&&arguments[3]!==void 0)||arguments[3],c=L(e.options),i=A(e.options).y;$(e,c,n),u(t,function(a){e.lastcol===c&&(e.lastcol=0);var l=H(a,"height");l=parseInt(a.offsetHeight,10),isNaN(l)||(a.style.position="absolute",a.style.top=e.rows[e.lastcol]+"px",a.style.left=""+e.cols[e.lastcol],e.rows[e.lastcol]+=isNaN(l)?0:l+i,e.lastcol+=1,r&&(a.dataset.macyComplete=1))}),r&&(e.tmpRows=null),x(e)}var o=function e(t,n){if(!(this instanceof e))return new e(t,n);if(t&&t.nodeName)return t;if(t=t.replace(/^\s*/,"").replace(/\s*$/,""),n)return this.byCss(t,n);for(var r in this.selectors)if(n=r.split("/"),new RegExp(n[1],n[2]).test(t))return this.selectors[r](t);return this.byCss(t)};o.prototype.byCss=function(e,t){return(t||document).querySelectorAll(e)},o.prototype.selectors={},o.prototype.selectors[/^\.[\w\-]+$/]=function(e){return document.getElementsByClassName(e.substring(1))},o.prototype.selectors[/^\w+$/]=function(e){return document.getElementsByTagName(e)},o.prototype.selectors[/^\#[\w\-]+$/]=function(e){return document.getElementById(e.substring(1))};var u=function(e,t){for(var n=e.length,r=n;n--;)t(e[r-n-1])},f=function(){var e=arguments.length>0&&arguments[0]!==void 0&&arguments[0];this.running=!1,this.events=[],this.add(e)};f.prototype.run=function(){if(!this.running&&this.events.length>0){var e=this.events.shift();this.running=!0,e(),this.running=!1,this.run()}},f.prototype.add=function(){var e=this,t=arguments.length>0&&arguments[0]!==void 0&&arguments[0];return!!t&&(Array.isArray(t)?u(t,function(n){return e.add(n)}):(this.events.push(t),void this.run()))},f.prototype.clear=function(){this.events=[]};var E=function(e){var t=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{};return this.instance=e,this.data=t,this},v=function(){var e=arguments.length>0&&arguments[0]!==void 0&&arguments[0];this.events={},this.instance=e};v.prototype.on=function(){var e=arguments.length>0&&arguments[0]!==void 0&&arguments[0],t=arguments.length>1&&arguments[1]!==void 0&&arguments[1];return!(!e||!t)&&(Array.isArray(this.events[e])||(this.events[e]=[]),this.events[e].push(t))},v.prototype.emit=function(){var e=arguments.length>0&&arguments[0]!==void 0&&arguments[0],t=arguments.length>1&&arguments[1]!==void 0?arguments[1]:{};if(!e||!Array.isArray(this.events[e]))return!1;var n=new E(this.instance,t);u(this.events[e],function(r){return r(n)})};var b=function(e){return!("naturalHeight"in e&&e.naturalHeight+e.naturalWidth===0)||e.width+e.height!==0},I=function(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2];return new Promise(function(r,c){if(t.complete)return b(t)?r(t):c(t);t.addEventListener("load",function(){return b(t)?r(t):c(t)}),t.addEventListener("error",function(){return c(t)})}).then(function(r){n&&e.emit(e.constants.EVENT_IMAGE_LOAD,{img:r})}).catch(function(r){return e.emit(e.constants.EVENT_IMAGE_ERROR,{img:r})})},N=function(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2];return w(t,function(r){return I(e,r,n)})},q=function(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2];return Promise.all(N(e,t,n)).then(function(){e.emit(e.constants.EVENT_IMAGE_COMPLETE)})},V=function(e){return T(function(){e.emit(e.constants.EVENT_RESIZE),e.queue.add(function(){return e.recalculate(!0,!0)})},100)},j=function(e){if(e.container=o(e.options.container),e.container instanceof o||!e.container)return!!e.options.debug&&console.error("Error: Container not found");e.container.length&&(e.container=e.container[0]),e.options.container=e.container,e.container.style.position="relative"},G=function(e){e.queue=new f,e.events=new v(e),e.rows=[],e.resizer=V(e)},D=function(e){var t=o("img",e.container);window.addEventListener("resize",e.resizer),e.on(e.constants.EVENT_IMAGE_LOAD,function(){return e.recalculate(!1,!1)}),e.on(e.constants.EVENT_IMAGE_COMPLETE,function(){return e.recalculate(!0,!0)}),e.options.useOwnImageLoader||m(e,t,!e.options.waitForImages),e.emit(e.constants.EVENT_INITIALIZED)},z=function(e){j(e),G(e),D(e)},_=function(e){return e===Object(e)&&Object.prototype.toString.call(e)!=="[object Array]"},P=function(e,t){_(e)||(t.columns=e),_(e)&&e.columns&&(t.columns=e.columns),_(e)&&e.margin&&!_(e.margin)&&(t.margin={x:e.margin,y:e.margin}),_(e)&&e.margin&&_(e.margin)&&e.margin.x&&(t.margin.x=e.margin.x),_(e)&&e.margin&&_(e.margin)&&e.margin.y&&(t.margin.y=e.margin.y)},H=function(e,t){return window.getComputedStyle(e,null).getPropertyValue(t)},$=function(e,t){var n=arguments.length>2&&arguments[2]!==void 0&&arguments[2];if(e.lastcol||(e.lastcol=0),e.rows.length<1&&(n=!0),n){e.rows=[],e.cols=[],e.lastcol=0;for(var r=t-1;r>=0;r--)e.rows[r]=0,e.cols[r]=C(e,r)}else if(e.tmpRows){e.rows=[];for(var r=t-1;r>=0;r--)e.rows[r]=e.tmpRows[r]}else{e.tmpRows=[];for(var r=t-1;r>=0;r--)e.tmpRows[r]=e.rows[r]}},B=function(e){var t=arguments.length>1&&arguments[1]!==void 0&&arguments[1],n=!(arguments.length>2&&arguments[2]!==void 0)||arguments[2],r=t?e.container.children:o(':scope > *:not([data-macy-complete="1"])',e.container);r=Array.from(r).filter(function(i){return i.offsetParent!==null});var c=M(e.options);return u(r,function(i){t&&(i.dataset.macyComplete=0),i.style.width=c}),e.options.trueOrder?(s(e,r,t,n),e.emit(e.constants.EVENT_RECALCULATED)):(k(e,r,t,n),e.emit(e.constants.EVENT_RECALCULATED))},F=function(){return!!window.Promise},W=Object.assign||function(e){for(var t=1;t<arguments.length;t++){var n=arguments[t];for(var r in n)Object.prototype.hasOwnProperty.call(n,r)&&(e[r]=n[r])}return e};Array.from||(Array.from=function(e){for(var t=0,n=[];t<e.length;)n.push(e[t++]);return n});var R={columns:4,margin:2,trueOrder:!1,waitForImages:!1,useImageLoader:!0,breakAt:{},useOwnImageLoader:!1,onInit:!1,cancelLegacy:!1,useContainerForBreakpoints:!1};(function(){try{document.createElement("a").querySelector(":scope *")}catch{(function(){function t(i){return function(a){if(a&&n.test(a)){var l=this.getAttribute("id");l||(this.id="q"+Math.floor(9e6*Math.random())+1e6),arguments[0]=a.replace(n,"#"+this.id);var O=i.apply(this,arguments);return l===null?this.removeAttribute("id"):l||(this.id=l),O}return i.apply(this,arguments)}}var n=/:scope\b/gi,r=t(Element.prototype.querySelector);Element.prototype.querySelector=function(i){return r.apply(this,arguments)};var c=t(Element.prototype.querySelectorAll);Element.prototype.querySelectorAll=function(i){return c.apply(this,arguments)}})()}})();var h=function e(){var t=arguments.length>0&&arguments[0]!==void 0?arguments[0]:R;if(!(this instanceof e))return new e(t);this.options={},W(this.options,R,t),this.options.cancelLegacy&&!F()||z(this)};return h.init=function(e){return console.warn("Depreciated: Macy.init will be removed in v3.0.0 opt to use Macy directly like so Macy({ /*options here*/ }) "),new h(e)},h.prototype.recalculateOnImageLoad=function(){var e=arguments.length>0&&arguments[0]!==void 0&&arguments[0];return m(this,o("img",this.container),!e)},h.prototype.runOnImageLoad=function(e){var t=arguments.length>1&&arguments[1]!==void 0&&arguments[1],n=o("img",this.container);return this.on(this.constants.EVENT_IMAGE_COMPLETE,e),t&&this.on(this.constants.EVENT_IMAGE_LOAD,e),m(this,n,t)},h.prototype.recalculate=function(){var e=this,t=arguments.length>0&&arguments[0]!==void 0&&arguments[0],n=!(arguments.length>1&&arguments[1]!==void 0)||arguments[1];return n&&this.queue.clear(),this.queue.add(function(){return B(e,t,n)})},h.prototype.remove=function(){window.removeEventListener("resize",this.resizer),u(this.container.children,function(e){e.removeAttribute("data-macy-complete"),e.removeAttribute("style")}),this.container.removeAttribute("style")},h.prototype.reInit=function(){this.recalculate(!0,!0),this.emit(this.constants.EVENT_INITIALIZED),window.addEventListener("resize",this.resizer),this.container.style.position="relative"},h.prototype.on=function(e,t){this.events.on(e,t)},h.prototype.emit=function(e,t){this.events.emit(e,t)},h.constants={EVENT_INITIALIZED:"macy.initialized",EVENT_RECALCULATED:"macy.recalculated",EVENT_IMAGE_LOAD:"macy.image.load",EVENT_IMAGE_ERROR:"macy.image.error",EVENT_IMAGE_COMPLETE:"macy.images.complete",EVENT_RESIZE:"macy.resize"},h.prototype.constants=h.constants,h})})(U);var K=U.exports;const X=Y(K);LA.init({id:"3J6dEY8wQU3ZxACy",ck:"3J6dEY8wQU3ZxACy",autoTrack:!0,prefix:"inter-knot/event"});(async()=>{var k;if(!(((k=localStorage.getItem("access_token"))==null?void 0:k.startsWith("ghu_"))??!1))if(new URL(location.href).searchParams.has("code"))try{await S(new URL(location.href).searchParams.get("code"))}catch{y()}else y();const p=[...document.querySelectorAll(".tab-container .tab")];p.forEach(s=>{s.addEventListener("click",()=>{p.forEach(o=>o.classList.remove("active")),s.classList.add("active")})});const g=document.querySelector(".popup-container");g.addEventListener("click",s=>{s.target===g&&(g.classList.remove("open"),g.classList.add("closed"))});const T=X({container:".card-container",columns:5,margin:{x:0,y:0}});try{const s=await A(localStorage.getItem("access_token"));w({curExp:6982,totalExp:1e4,level:s.public_repos,name:s.name,profilePhoto:s.avatar_url,url:s.html_url})}catch{try{await L(localStorage.getItem("refresh_token"));const s=await A(localStorage.getItem("access_token"));w({curExp:6982,totalExp:1e4,level:s.public_repos,name:s.name,profilePhoto:s.avatar_url,url:s.html_url})}catch{y()}}try{const s=await M(localStorage.getItem("access_token"));m(s.map(o=>({cover:"https://avatars.githubusercontent.com/u/1067290?v=4",authorPhoto:o.author.avatarUrl,title:o.title,author:o.author.login,content:o.bodyHTML,visited:C(0,1001),comments:o.comments.nodes.map(u=>({profilePhoto:u.author.avatarUrl,name:u.author.login,content:u.bodyHTML}))})))}catch{try{await L(localStorage.getItem("refresh_token"));const s=await M(localStorage.getItem("access_token"));m(s.map(o=>({cover:"https://avatars.githubusercontent.com/u/1067290?v=4",authorPhoto:o.author.avatarUrl,title:o.title,author:o.author.login,content:o.bodyHTML,visited:C(0,1001),comments:o.comments.nodes.map(u=>({profilePhoto:u.author.avatarUrl,name:u.author.login,content:u.bodyHTML}))})))}catch{y()}}function w({curExp:s,totalExp:o,level:u,name:f,profilePhoto:E,url:v}){document.querySelector(".user-info").href=v,document.querySelector(".user-info .profile-photo").src=E,document.querySelector(".user-info .curExp").textContent=s+"",document.querySelector(".user-info .totalExp").textContent=o+"",document.querySelector(".user-info .level-num").textContent=u+"",document.querySelector(".user-info .username").textContent=f,document.querySelector(".user-info .bar").style.width=s/o*100+"%"}function m(s){document.querySelector(".card-container").innerHTML=s.map(({cover:o,title:u,author:f,authorPhoto:E,content:v,visited:b})=>`<div class="card-wrapper"><div class="card"><section class="cover-container"><img class="cover" src="${o}" alt="封面" /><div class="visited"><svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" ><path fill="currentColor" d="M1.182 12C2.122 6.88 6.608 3 12 3s9.878 3.88 10.819 9c-.94 5.12-5.427 9-10.819 9s-9.878-3.88-10.818-9M12 17a5 5 0 1 0 0-10a5 5 0 0 0 0 10m0-2a3 3 0 1 1 0-6a3 3 0 0 1 0 6" /></svg>${b}</div></section><section class="info-container"><div class="profile"><img class="profile-photo" src="${E}" alt="头像" /><div class="username">${f}</div></div><div class="title">${u}</div><div class="content">${v}</div></section></div></div>`).join(""),document.querySelectorAll(".card-container img").forEach(o=>o.addEventListener("load",()=>T.recalculate(!0),{once:!0})),document.querySelectorAll(".card-container .card").forEach((o,u)=>{const{cover:f,title:E,author:v,authorPhoto:b,content:I,visited:N,comments:q}=s[u];o.addEventListener("click",()=>{d({cover:f,title:E,author:v,authorPhoto:b,content:I,visited:N,comments:q})})})}function d({authorPhoto:s,author:o,visited:u,cover:f,title:E,content:v,comments:b}){g.innerHTML=`<div class="popup"><header><img class="profile-photo" src="${s}" alt="头像" /><div><div>${o}</div><div class="visited"><svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" ><path fill="currentColor" d="M1.182 12C2.122 6.88 6.608 3 12 3s9.878 3.88 10.819 9c-.94 5.12-5.427 9-10.819 9s-9.878-3.88-10.818-9M12 17a5 5 0 1 0 0-10a5 5 0 0 0 0 10m0-2a3 3 0 1 1 0-6a3 3 0 0 1 0 6" /></svg>${u}</div></div><div class="close-btn"><svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" ><path fill="currentColor" d="m12 10.587l4.95-4.95l1.414 1.414l-4.95 4.95l4.95 4.95l-1.415 1.414l-4.95-4.95l-4.949 4.95l-1.414-1.415l4.95-4.95l-4.95-4.95L7.05 5.638z" /></svg></div></header><main><div class="cover"><img src="${f}" alt="封面" /></div><div class="content"><div class="title">${E}</div><div class="text">${v}</div><div class="comments">${b.map(I=>`<section class="comment"><img class="profile-photo" src="${I.profilePhoto}" alt="头像" /><div><div class="name">${I.name}</div><div class="text">${I.content}</div></div></section>`).join("")}</div></div></main></div>`,document.querySelector(".close-btn").addEventListener("click",()=>{g.classList.remove("open"),g.classList.add("closed")}),g.classList.remove("closed"),g.classList.add("open")}function y(){location.href="https://github.com/login/oauth/authorize?client_id=Iv23li8gf1MxGAgvw5lU"}async function S(s){const o=await fetch(`https://github.com/login/oauth/access_token?client_id=Iv23li8gf1MxGAgvw5lU&client_secret=3ea999c0e2d7283f602ab4994cc684ada2eeec2b&code=${s}`,{method:"POST",headers:{accept:"application/json"}}).then(u=>u.json());return localStorage.setItem("access_token",o.access_token),localStorage.setItem("refresh_token",o.refresh_token),o}async function L(s){const o=await fetch(`https://github.com/login/oauth/access_token?client_id=Iv23li8gf1MxGAgvw5lU&client_secret=3ea999c0e2d7283f602ab4994cc684ada2eeec2b&grant_type=refresh_token&refresh_token=${s}`,{method:"POST",headers:{accept:"application/json"}}).then(u=>u.json());return localStorage.setItem("access_token",o.access_token),localStorage.setItem("refresh_token",o.refresh_token),o}async function A(s){const{data:o}=await x({access_token:s,data:"query { viewer { avatarUrl login repositories { totalCount } } }"});return{name:o.viewer.login,avatar_url:o.viewer.avatarUrl,html_url:`https://github.com/${o.viewer.login}`,public_repos:o.viewer.repositories.totalCount}}async function M(s){const{data:{repository:{discussions:{nodes:o}}}}=await x({access_token:s,data:'query { repository(owner: "share121", name: "inter-knot") { discussions(first: 100) { nodes { author { avatarUrl login url } bodyHTML title comments(first: 100) { nodes { author { avatarUrl login url } bodyHTML } } } } } }'});return o}function C(s,o){return s=Math.ceil(s),o=Math.floor(o),Math.floor(Math.random()*(o-s)+s)}function x({access_token:s,data:o}){return fetch("https://api.github.com/graphql",{method:"POST",headers:{Authorization:"Bearer "+s},body:JSON.stringify({query:o})}).then(u=>u.json())}})();
