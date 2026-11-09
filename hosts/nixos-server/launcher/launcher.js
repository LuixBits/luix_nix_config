"use strict";
const $ = id => document.getElementById(id);
const tiles = [];
const icons = new Set(["terminal", "activity", "bars", "game", "folder", "photo", "play", "film", "chat", "arrow"]);
function icon(name, className) {
    const node = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    node.setAttribute("class", className);
    node.setAttribute("aria-hidden", "true");
    const use = document.createElementNS("http://www.w3.org/2000/svg", "use");
    use.setAttribute("href", `#icon-${icons.has(name) ? name : "server"}`);
    node.append(use);
    return node;
}
function span(text, className) {
    const node = document.createElement("span");
    node.textContent = text;
    node.className = className;
    return node;
}
function destination(item) {
    let url;
    if (item.cockpitPath) {
        url = new URL(window.location.href);
        url.protocol = "https:"; url.port = "9090";
        url.pathname = item.cockpitPath; url.search = ""; url.hash = "";
    } else if (item.url) url = new URL(item.url);
    if (url && !["https:", "http:"].includes(url.protocol)) throw new Error("Unsupported shortcut URL");
    return url?.href;
}
function tile(item) {
    const href = destination(item);
    const node = document.createElement(href ? "a" : "button");
    node.className = `tile${href ? "" : " unlinked"}`;
    node.dataset.id = item.id;
    if (href) {
        node.href = href; node.target = "_blank"; node.rel = "noopener noreferrer";
    } else {
        node.type = "button";
        node.setAttribute("aria-haspopup", "dialog");
        node.addEventListener("click", () => {
            $("unlinked-title").textContent = item.name;
            $("unlinked").showModal();
        });
    }
    const top = span("", "tile-top");
    top.append(icon(item.icon, "tile-icon"), href ? icon("arrow", "tile-arrow") : span("Not linked", "tag"));
    const copy = span("", "tile-copy");
    copy.append(span(item.name, "tile-title"), span(item.description, "tile-description"));
    node.append(top, copy);
    tiles.push({ node, search: `${item.name} ${item.description}`.toLocaleLowerCase() });
    return node;
}
function filter() {
    const query = $("search").value.trim().toLocaleLowerCase();
    for (const item of tiles) item.node.hidden = !item.search.includes(query);
    for (const [section, list] of [["server-section", "server-links"], ["apps-section", "app-links"]]) {
        $(section).hidden = !Array.from($(list).children).some(node => !node.hidden);
    }
    $("empty").hidden = tiles.some(item => !item.node.hidden);
}
$("host").textContent = window.location.hostname;
$("search").addEventListener("input", filter);
$("close-dialog").addEventListener("click", () => $("unlinked").close());
document.addEventListener("keydown", event => {
    if ($("unlinked").open) return;
    if (event.key === "/" && !event.ctrlKey && !event.metaKey && !event.altKey && document.activeElement?.tagName !== "INPUT") {
        event.preventDefault(); $("search").focus();
    } else if (event.key === "Escape" && document.activeElement === $("search")) {
        $("search").value = ""; filter(); $("search").blur();
    }
});
fetch("links.json").then(response => {
    if (!response.ok) throw new Error("Shortcuts could not be loaded.");
    return response.json();
}).then(config => {
    $("server-links").append(...config.server.map(tile));
    $("app-links").append(...config.apps.map(tile));
}).catch(error => { $("error").textContent = error.message; $("error").hidden = false; });
