# better-sessions

A [Tern](https://stencil.so) plugin that makes sessions the way you organise work:

- **Left sidebar**: sessions listed vertically down the left side.
- **Top tab bar**: the current session's tabs in Tern's top bar, beside the New tab (+) button. Click a tab to switch to it.
- **Session roots**: give a session a folder, and every new tab, agent block and shell block you open in it starts there. Splits (⌘D) still start in the focused block's folder.

## Install

```sh
tern plugin install github.com/aurbano/better-sessions
```

Or, to work on it from a checkout:

```sh
tern plugin link ~/dev/better-sessions
```

The first time it loads, the plugin switches tabs to vertical and puts its tab widgets first in the widget bar. It keeps your other widgets, and leaves Tern's sidebar auto-hide setting as you have it.

## Commands

All of these are in the command palette, under "Better sessions":

| Command | What it does |
|---|---|
| Set session root… | Asks for the current session's root folder, pre-filled with the focused block's folder. |
| Clear session root | New tabs in the current session go back to Tern's default folder. |
| New session at folder… | Creates a session named after a folder, with that folder as its root. |
| Apply sidebar layout (vertical sessions, tabs on top) | Applies the sidebar and tab bar settings again. |

## How session roots work

Tern's `spawn` hook can change a new pane's working directory, but it can't see which session the pane belongs to. So the window half of the plugin overrides `new_tab`, `new_agent_block` and `new_shell_block`. Each override stores the current session's root under the `pending` key in the plugin's key/value store, and then lets Tern's own command run. The host half (`host.luau`) gives that folder to the next pane that spawns, then clears it. A stored folder that no pane picks up within 3 seconds is ignored, so restored panes and `tern new tab` keep their own folders.

Roots are stored under the `roots` key, one per session id, and are removed when the session closes.

Limitations:

- Works for local sessions only. On a remote host, the host half runs in that host's daemon, which has its own key/value store.
- Commands that don't go through Tern's built-in new-tab commands (`tern new tab`, plugin APIs) use Tern's default folder.
- The top bar CSS is pinned to Tern's vertical tab layout (`html.tn-widgets.tabs-v`). Tern updates that change its top bar may need the offsets in `better-sessions.css` adjusted.

## Development

`tern plugin types .` writes `tern.d.luau` (gitignored) for luau-lsp. With the plugin linked, Tern reloads it whenever a file in this directory changes.
