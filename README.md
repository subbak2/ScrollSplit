# ScrollSplit

Natural scrolling on the trackpad, regular scrolling on the mouse — at the same time, without toggling. Free, open source, menu bar only, and it never touches the network.

**한국어 기획·설명: [docs/plan-ko.md](docs/plan-ko.md)**

## Why

macOS has a single "Natural scrolling" switch for every pointing device. If you use a trackpad and a wheel mouse, one of them always scrolls the wrong way.

## How it works

- A session event tap that receives **scroll-wheel events only** (no keys, clicks or cursor moves).
- Trackpad scrolls carry a scroll or momentum phase; wheel mice don't. ScrollSplit uses that to tell them apart and flips the deltas for the device whose preference differs from the system setting.
- No timers and no polling: the app wakes only while something scrolls.

## Permissions and privacy

- Needs **Accessibility** access. macOS requires it for any app that changes scroll events of other apps.
- No networking code. `scripts/check-no-network.sh` checks the built binary for networking frameworks and socket/HTTP symbols.
- Stores three settings in `UserDefaults`. No logs, no analytics.

## Build

Requires macOS 13 or later and Xcode command line tools.

    scripts/build-app.sh          # build/ScrollSplit.app and build/ScrollSplit.zip
    scripts/check-no-network.sh   # verify no networking
    swift test                    # device classification and reversal tests

Copy `build/ScrollSplit.app` to `/Applications`, open it, and allow it in **System Settings › Privacy & Security › Accessibility**.

## Known limitations

- Magic Mouse sends phases like a trackpad, so it follows the trackpad setting.
- The app is ad-hoc signed. After replacing it with a new build, remove it from the Accessibility list and add it again.

## License

MIT
