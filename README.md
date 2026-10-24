# ScrollSplit

Natural scrolling on the trackpad, regular scrolling on the mouse, at the same time and without toggling. Free, open source, menu bar only, and it never touches the network.

**한국어 설명서: [docs/manual-ko.md](docs/manual-ko.md)**

## The problem

macOS has one "Natural scrolling" switch for every pointing device. The Trackpad and Mouse settings panes both show it, but changing one changes the other. If you use a trackpad and a wheel mouse, one of them always scrolls the wrong way, and you end up flipping the setting every time you plug the mouse in.

## Install

Requires macOS 13 or later. Built and tested on Apple Silicon (macOS 27); the universal build also runs on Intel Macs but is untested there.

1. Download `ScrollSplit.zip` from [Releases](../../releases) and double-click it to unzip.
2. Drag `ScrollSplit.app` into your **Applications** folder.
3. Double-click it. macOS blocks the first launch because the app is not notarized (that needs a paid Apple Developer account). Click **Done**.
4. Open **System Settings › Privacy & Security**, scroll down to *"ScrollSplit" was blocked*, click **Open Anyway** and confirm.
5. macOS asks for **Accessibility** access. Turn ScrollSplit on in **System Settings › Privacy & Security › Accessibility**. The app starts working within two seconds; no restart needed.

Steps 3–4 can be replaced by one Terminal command:

```
xattr -dr com.apple.quarantine /Applications/ScrollSplit.app
```

## Use

Click the arrows icon in the menu bar.

- **Natural Scrolling › Trackpad / Mouse**: check the devices that should scroll naturally (content follows your fingers). Default: trackpad on, mouse off.
- **Last scroll** and **System setting** lines show what the app recognized, to check that a device is detected correctly.
- **Pause**: switches the app off entirely; every device follows the system setting.
- **Launch at Login**.

The System Settings switch doesn't matter: whatever it is set to, each device scrolls the way you checked in the menu.

## How it works

- A session event tap that receives **scroll-wheel events only**. Keys, clicks and cursor moves never reach the app.
- Trackpad scrolls carry a scroll phase (fingers down) or momentum phase (after lifting); wheel mice carry neither. ScrollSplit uses that to tell them apart and negates the vertical and horizontal deltas (line, fixed-point and pixel values) when your choice for that device differs from the system setting.
- No timers and no polling while it runs: the app wakes only when something scrolls.

## Privacy and security

- **No network.** There is no networking code. `scripts/check-no-network.sh` checks the built binary for networking frameworks and socket/HTTP symbols, and `lsof -i` shows no sockets while it runs. "About ScrollSplit…" opens this page in your browser; the app itself sends nothing.
- **Only Accessibility.** macOS requires Accessibility access for any app that changes other apps' scroll events. ScrollSplit asks for nothing else (no Input Monitoring, no Full Disk Access).
- **Stores three settings** in `UserDefaults` (trackpad, mouse, paused). No logs on disk, no analytics. Diagnostic lines go to the macOS unified log only when you turn on `debug` (see Troubleshooting), and they contain the device type and phase numbers, never what you scroll.
- **Hardened Runtime** is on, which blocks injecting code into the app (for example with `DYLD_INSERT_LIBRARIES`) to borrow its Accessibility access.
- Releases are ad-hoc signed, not notarized. If you'd rather not trust a downloaded binary, build it yourself (below); the source is about 300 lines.

## Safety and recovery

ScrollSplit only edits numbers in scroll events that pass through it. It changes no system setting and writes nothing outside its own preferences, so quitting it always restores normal scrolling.

- **If scrolling ever stops or feels wrong:** quit from the menu, or run `killall ScrollSplit` in Terminal. macOS removes the event tap the moment the process ends.
- **Start without it:** hold **Shift** while launching. The app starts paused; uncheck **Pause** in the menu when ready.
- **If the app hangs**, macOS switches the tap off after about a second and scrolling continues unchanged; the app turns the tap back on when it recovers, and after the Mac wakes from sleep.
- **If you remove Accessibility access** while it runs, the app drops the tap right away and waits for access again, instead of leaving an active tap without permission (an active tap left behind without permission has been reported to lock up input). It reacts to the system's change notification and, as a backup, re-checks every 5 seconds while scrolling and after wake.
- **After a macOS update**, the app relies only on public Quartz Event Services APIs plus the `com.apple.swipescrolldirection` preference (read through CFPreferences, re-read every 5 seconds while scrolling in case the change notification is renamed). If a future macOS changes how trackpad scroll phases are reported, the worst case is the wrong device getting flipped; **Pause** or quitting fixes that immediately.
- **After replacing the app with a new build**, macOS may treat it as a different app (ad-hoc signatures change per build). Remove ScrollSplit from the Accessibility list with **−** and turn it on again.

## CPU, GPU and memory

Measured on a MacBook Pro M1 Max, macOS 27, with `top`/`ps` (5-second samples) and `ioreg` for GPU:

| | CPU | GPU | Memory |
|---|---|---|---|
| Idle (not scrolling) | 0.0% | none (no GPU work submitted) | about 22 MB |
| One minute of alternating trackpad and mouse scrolling | 1% on average, up to about 5% of one core while scrolling fast | none | unchanged |

Leaving it running costs nothing you would notice on battery.

## Limitations

- **Magic Mouse** reports scroll phases like a trackpad, so it follows the **Trackpad** setting.
- **Mice with smooth scrolling added by software** (Logi Options+ "Smooth scrolling", Mac Mouse Fix, Mos, LinearMouse) send trackpad-like phased events, so they count as a trackpad. Turn that smoothing off, or use **Pause**.
- **Device detection uses only public event fields** (scroll and momentum phase). Scroll Reverser 2.0 identifies the physical device through private APIs; ScrollSplit deliberately doesn't, trading some accuracy in the cases above for fewer things a macOS update can break.
- **Several scroll tools at once** (Scroll Reverser, Mos, LinearMouse, UnnaturalScrollWheels, Logi Options+ scroll features, Karabiner-Elements) can flip the same events twice. Use one.
- **Remote desktop / Screen Sharing / Sidecar / Universal Control**: events coming from another device can lose their phase information, so a remote trackpad may count as a mouse. If one direction looks wrong there, check what *Last scroll* shows.
- **iPhone Mirroring** and some games may read scroll input in ways the event tap doesn't affect.
- Ad-hoc signed and not notarized (see Install).

## Troubleshooting

Turn on per-event diagnostics, then watch them while you scroll:

```
defaults write io.github.subbak2.ScrollSplit debug -bool true   # then quit and reopen the app
/usr/bin/log stream --level debug --predicate 'subsystem == "io.github.subbak2.ScrollSplit"'
defaults delete io.github.subbak2.ScrollSplit debug             # turn off again
```

Reset all settings: `defaults delete io.github.subbak2.ScrollSplit`. Reset the Accessibility entry: `tccutil reset Accessibility io.github.subbak2.ScrollSplit`.

## Build from source

Requires Xcode command line tools.

```
scripts/build-app.sh          # build/ScrollSplit.app and build/ScrollSplit.zip
scripts/check-no-network.sh   # verify no networking
swift test                    # device classification and reversal tests
```

`SIGN_IDENTITY=<certificate> scripts/build-app.sh` signs with your own certificate so the Accessibility permission survives rebuilds.

## Alternatives

- [Scroll Reverser](https://pilotmoon.com/scrollreverser/): the long-standing app for this, more options.
- [LinearMouse](https://linearmouse.app/) and [Mos](https://mos.caldis.me/): per-device scrolling plus smoothing, acceleration and button mapping.

ScrollSplit does one thing with a small codebase you can read in a few minutes.

## License

MIT
