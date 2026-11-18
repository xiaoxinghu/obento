# frost

Frosted-glass Emacs frames on macOS: the frame is see-through, with what is behind it blurred,
and its text keeps its colours. It follows the theme, dark or light.

![A light and a dark theme over a colour test pattern](screenshot.png)

## What it needs

- macOS, and GNU Emacs built with the NS (Cocoa) port and with modules
  (`module-file-suffix` is non-nil);
- the Command Line Tools (`xcode-select --install`), for `clang`.

The first time `frost-mode` is turned on, it builds its native module, `frost.m`, into
`frost-module.dylib` in the package's own folder, and builds it again when `frost.m` is newer.
A rebuilt module takes effect at the next start of Emacs. If the build or the load fails, it
says so in a message and Emacs carries on as usual. Elsewhere (another OS, another port, a
terminal frame) the mode does nothing.

Run on GNU Emacs 31.1 (the NS port, as the `emacs-plus` cask builds it) on macOS 27.2. The code
reads the view layout of Emacs 30 and 31; older versions were not run.

## Installing

```elisp
(use-package frost
  :vc (:url "https://github.com/xiaoxinghu/frost" :rev :newest)
  :hook (after-init . frost-mode))
```

Or from a copy of this folder:

```elisp
(add-to-list 'load-path "/path/to/frost")
(require 'frost)
(frost-mode 1)
```

The mode can be turned on before any graphical frame exists (a daemon): frames made later,
with `emacsclient -c` or `C-x 5 2`, are frosted as they are made.

## Options

- `frost-tint-opacity`, 65: how much of the theme's background lies over the glass, 0 to 100.
  Lower lets more of the backdrop through; too low and a bright window behind washes a dark
  theme out.
- `frost-tint-color`, nil: the tint's colour; nil is the default face's background.
- `frost-material`, `hud-window`: the system material behind the frame, by its
  `NSVisualEffectView` name. Most of the others are close to opaque.

## How it works

<figure>
<svg viewBox="0 0 800 470" width="100%" role="img" aria-label="frost.el calls the native module, which for every top-level frame's window adds a blurring NSVisualEffectView and a tint below the Emacs view and sets a blend mode on the Emacs view's layer. Back to front: what is behind the window is blurred, tinted, then blended with what Emacs draws." font-family="-apple-system, system-ui, sans-serif" font-size="12">
  <defs>
    <marker id="frost-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z" fill="currentColor"/></marker>
  </defs>
  <g fill="none" stroke="currentColor" stroke-width="1.2">
    <rect x="40" y="16" width="230" height="64" rx="6"/>
    <rect x="356" y="16" width="434" height="64" rx="6"/>
    <path d="M270 48H352" marker-end="url(#frost-arrow)"/>
    <path d="M372 80V348"/>
    <path d="M372 192H326" marker-end="url(#frost-arrow)"/>
    <path d="M372 270H326" marker-end="url(#frost-arrow)"/>
    <path d="M372 348H326" marker-end="url(#frost-arrow)"/>
    <path d="M96 404H346L290 448H40Z" stroke-dasharray="5 4"/>
    <path d="M96 326H346L290 370H40Z" fill="#4a9eda" fill-opacity="0.35"/>
    <path d="M96 248H346L290 292H40Z" fill="currentColor" fill-opacity="0.2"/>
    <path d="M96 170H346L290 214H40Z" fill="currentColor" fill-opacity="0.05"/>
    <path d="M193 400V376" marker-end="url(#frost-arrow)"/>
    <path d="M193 322V298" marker-end="url(#frost-arrow)"/>
    <path d="M193 244V220" marker-end="url(#frost-arrow)"/>
    <path d="M193 166V134" marker-end="url(#frost-arrow)"/>
  </g>
  <g fill="none" stroke-width="3" stroke-linecap="round">
    <path d="M94 183H168" stroke="#c2569b"/>
    <path d="M81 193H186" stroke="#3f9b6b"/>
    <path d="M68 203H138" stroke="#d08a2e"/>
  </g>
  <g fill="currentColor">
    <text x="54" y="38" font-size="13" font-weight="600">frost.el</text>
    <text x="54" y="55" fill-opacity="0.75">when: mode toggled, new frame,</text>
    <text x="54" y="71" fill-opacity="0.75">theme changed, option set</text>
    <text x="311" y="41" text-anchor="middle">calls</text>
    <text x="370" y="38" font-size="13" font-weight="600">frost-module.dylib</text>
    <text x="370" y="55" fill-opacity="0.75">frost.m, built with clang the first time the mode is on</text>
    <text x="370" y="71" fill-opacity="0.75" font-family="ui-monospace, Menlo, monospace" font-size="11.5">(frost--apply MODE MATERIAL RED GREEN BLUE ALPHA)</text>
    <text x="384" y="118" fill-opacity="0.75">for every top-level frame's window:</text>
    <text x="205" y="155">what you see</text>
    <text x="205" y="237">blended</text>
    <text x="205" y="315">tinted</text>
    <text x="205" y="393">blurred</text>
    <text x="384" y="184" font-size="13" font-weight="600">Emacs view (already there)</text>
    <text x="384" y="201" fill-opacity="0.75">frost sets a blend mode on its layer:</text>
    <text x="384" y="217" fill-opacity="0.75">screen for a dark theme, multiply for a light one</text>
    <text x="384" y="266" font-size="13" font-weight="600">tint (added)</text>
    <text x="384" y="283" fill-opacity="0.75">the theme's background colour at frost-tint-opacity</text>
    <text x="384" y="344" font-size="13" font-weight="600">NSVisualEffectView (added)</text>
    <text x="384" y="361" fill-opacity="0.75">frost-material, blurring what is behind the window</text>
    <text x="384" y="422" font-size="13" font-weight="600">behind the window</text>
    <text x="384" y="439" fill-opacity="0.75">the desktop and other apps' windows</text>
  </g>
</svg>
<figcaption>Back to front: frost adds two views below Emacs's own and sets a blend mode on it, so the theme's background drops out to the glass and the text keeps its colours.</figcaption>
</figure>

For each top-level frame the module puts an `NSVisualEffectView` behind the frame's view, the
size of the whole window (so the title bar, with `ns-transparent-titlebar`, is frosted too),
then a flat tint in the theme's background colour, and sets a blend mode on the Emacs view's
layer: screen for a dark theme, multiply for a light one. The dark (or light) background then
lets the glass through and text keeps its colours. The window itself is left opaque, as Emacs
keeps it, so nothing Emacs does to the window undoes it. The views follow the window by
themselves: moving, resizing and changing displays need nothing from Emacs.

It uses no private API. It does name the blend modes by strings (`screenBlendMode`,
`multiplyBlendMode`), which Core Animation accepts and Apple does not document.

## What it cannot do

- Everything the Emacs view draws is blended: a dark image or PDF in a buffer goes
  see-through, and faces with a background of their own (region, hl-line, the mode line)
  become washes over the glass.
- Child frames (posframe, corfu) stay opaque, and so do native views other packages put in a
  frame (web views, terminals): they draw their own backgrounds.
- In native fullscreen there is nothing behind the window to blur; the frame shows the
  material's own plain colour under the tint. Non-native fullscreen moves the frame to a
  window of its own, which is not frosted until it leaves fullscreen.
- Undecorated top-level frames are not frosted.
- "Reduce transparency" is left to the system: Apple says materials follow it. Not tried here.

## Licence

GPL-3.0-or-later; see `LICENSE`. `emacs-module.h` is Emacs's own, from Emacs 29.1.
