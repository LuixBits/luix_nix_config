"use strict";
const terminal = new Terminal({ cursorBlink: false, fontSize: 14, fontFamily: "monospace", theme: { background: "#0c1014", foreground: "#edf2f6" } });
const fit = new FitAddon.FitAddon();
terminal.loadAddon(fit);
terminal.open(document.getElementById("terminal"));
let settings, channel;
const status = message => { document.getElementById("terminal-status").textContent = message; };
function resize() {
    if (cockpit.hidden || document.hidden) return;
    fit.fit();
    if (channel?.valid) channel.control({ window: { rows: terminal.rows, cols: terminal.cols } });
}
function stop() {
    if (channel) { const old = channel; channel = null; old.close(); }
}
function start() {
    if (!settings || cockpit.hidden || document.hidden || channel?.valid) return;
    terminal.reset(); resize();
    const current = cockpit.channel({ payload: "stream", spawn: [settings.btopCommand],
        pty: true, binary: true, environ: ["TERM=xterm-256color", "LANG=en_US.UTF-8"],
        window: { rows: terminal.rows, cols: terminal.cols } });
    channel = current;
    current.addEventListener("message", (_, data) => terminal.write(new Uint8Array(data)));
    current.addEventListener("ready", () => { status("Live · click inside to use the keyboard or mouse"); resize(); });
    current.addEventListener("close", (_, options) => {
        if (channel !== current) return;
        channel = null;
        status(options.problem ? `Monitor unavailable: ${options.problem}` : "Monitor closed. Use Restart view to open it again.");
    });
}
function visibility() {
    if (cockpit.hidden || document.hidden) { stop(); status("Paused while this view is hidden"); }
    else start();
}
terminal.onData(data => { if (channel?.valid) channel.send(new TextEncoder().encode(data)); });
terminal.onBinary(data => { if (channel?.valid) channel.send(Uint8Array.from(data, char => char.charCodeAt(0))); });
new ResizeObserver(resize).observe(document.getElementById("terminal"));
document.getElementById("focus-monitor").onclick = () => terminal.focus();
document.getElementById("restart-monitor").onclick = () => { stop(); start(); terminal.focus(); };
cockpit.addEventListener("visibilitychange", visibility);
document.addEventListener("visibilitychange", visibility);
window.addEventListener("pagehide", stop);
fetch("settings.json").then(response => response.json()).then(value => { settings = value; start(); }).catch(error => status(error.message));
