// NAME: Move to top
// DESCRIPTION: Right-click selected songs in a playlist → "Move to top" / "Move to bottom". Keeps their order.
// Part of the glyph rice (~/.config/spicetify/Themes/glyph).

(function glyphMove() {
    // extensions can run before Spicetify is set up: wait for it, or the first read throws and nothing registers
    if (!window.Spicetify?.ContextMenu || !Spicetify.ReactJSX || !Spicetify.Platform?.PlaylistAPI || !Spicetify.Platform?.History) {
        setTimeout(glyphMove, 300);
        return;
    }
    const { ContextMenu, Platform, showNotification } = Spicetify;

    // the menu doesn't say which playlist the rows belong to: take the playlist page that's open
    const openPlaylist = () => {
        const m = /^\/playlist\/([A-Za-z0-9]+)/.exec(Platform.History.location?.pathname ?? "");
        return m ? `spotify:playlist:${m[1]}` : null;
    };
    // only rows inside a playlist have uids; the menu stays away from albums, search results, the queue
    const fits = (uris, uids) => !!openPlaylist() && uids?.length > 0 && uids.length === uris.length;

    async function move(uids, location, label) {
        const playlist = openPlaylist();
        try {
            await Platform.PlaylistAPI.move(playlist, uids.map(uid => ({ uid })), location);
            showNotification(`${uids.length === 1 ? "Song" : `${uids.length} songs`} moved to the ${label}`);
        } catch (e) {
            console.error("glyph-move", e);
            showNotification("Can't reorder this playlist (only your own, or collaborative ones)", true);
        }
    }

    new ContextMenu.Item("Move to top", (uris, uids) => move(uids, { before: "start" }, "top"), fits, "chart-up").register();
    new ContextMenu.Item("Move to bottom", (uris, uids) => move(uids, { after: "end" }, "bottom"), fits, "chart-down").register();
})();
