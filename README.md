# better-sessions

A [Tern](https://stencil.so/tern) plugin that makes sessions the way you organise work:

- **Left sidebar**: sessions listed vertically down the left side. A button in the top bar keeps it visible or hides it until you hover the left edge, and palette commands change its width.
- **Top tab bar**: the current session's tabs in Tern's top bar, beside the New tab (+) button. Click a tab to switch to it.
- **Session roots**: give a session a folder, and every new tab, agent block and shell block you open in it starts there. Splits (⌘D) still start in the focused block's folder.

Tested with Tern 0.9.26 on macOS.

## Install

```sh
tern plugin install github.com/aurbano/better-sessions
```

Or paste `github.com/aurbano/better-sessions` into the install field in Tern's plugin settings.

The first time it loads, the plugin switches tabs to vertical and puts the sidebar button and its tab widgets first in the widget bar. It keeps your other widgets, and leaves Tern's sidebar auto-hide setting as you have it.

To uninstall, run `tern plugin remove better-sessions`. Your tab and widget settings stay as they are; remove the `better-sessions/*` entries from `widgets` in `settings.json` if you want them gone too.

## Commands

All of these are in the command palette, under "Better sessions":

| Command | What it does |
|---|---|
| Set session root… | Asks for the current session's root folder, pre-filled with the focused block's folder. |
| Clear session root | New tabs in the current session go back to Tern's default folder. |
| New session at folder… | Creates a session named after a folder, with that folder as its root. |
| Show or hide sidebar (toggle auto-hide) | Same as the sidebar button: turns Tern's `tabs_autohide` setting on or off. |
| Widen sidebar / Narrow sidebar | Changes the sidebar width by 24px, between 160px and 480px. |
| Set sidebar width… | Sets an exact width in px; leave it empty to go back to Tern's default (236px). |
| Apply sidebar layout (vertical sessions, tabs on top) | Applies the sidebar and tab bar settings again. |

Commands have no default shortcuts; bind any of them in Tern's keyboard settings (`plugin.better-sessions.<id>`, for example `plugin.better-sessions.toggle_sidebar`).

The sidebar width can't be dragged: Tern lets plugins style its sidebar but not add a drag handle to it. The width is stored per machine and applies to every window.

## How session roots work

Tern's `spawn` hook can change a new pane's working directory, but it can't see which session the pane belongs to. So the window half of the plugin overrides `new_tab`, `new_agent_block` and `new_shell_block`. Each override stores the current session's root under the `pending` key in the plugin's key/value store, and then lets Tern's own command run. The host half (`host.luau`) gives that folder to the next pane that spawns, then clears it. A stored folder that no pane picks up within 3 seconds is ignored, so restored panes and `tern new tab` keep their own folders.

Roots are stored under the `roots` key, one per session id, and are removed when the session closes.

Limitations:

- Works for local sessions only. On a remote host, the host half runs in that host's daemon, which has its own key/value store.
- Commands that don't go through Tern's built-in new-tab commands (`tern new tab`, plugin APIs) use Tern's default folder.
- The top bar CSS is pinned to Tern's vertical tab layout (`html.tn-widgets.tabs-v`). Tern updates that change its top bar may need the offsets in `better-sessions.css` adjusted.

## Development

```sh
git clone https://github.com/aurbano/better-sessions
tern plugin link ./better-sessions
tern plugin types ./better-sessions
```

`tern plugin link` uses the checkout in place, and Tern reloads the plugin whenever a file in it changes. `tern plugin types` writes `tern.d.luau` (gitignored) for luau-lsp.

## License

[MIT](LICENSE)
