"use strict";
// Preserve bookmarks to the retired dashboard using Cockpit's native overview.
function showOverview() {
    if (!cockpit.hidden) cockpit.jump("/system");
}
cockpit.addEventListener("visibilitychange", showOverview);
cockpit.transport.wait(showOverview);
