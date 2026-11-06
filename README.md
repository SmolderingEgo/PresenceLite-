# Presence Lite

Cinematic pop-ups, and only these:
- Zone and subzone changes, plus a green "Discovered" line for new areas
- Quest accepted, objective progress (7/15 ...), all objectives complete, quest turned in
- World quest accepted / complete (purple)
- Level up

## Install
Unzip so the folder is `World of Warcraft\_retail_\Interface\AddOns\PresenceLite\`.
Turn off Horizon Suite's Presence module (or Horizon Suite entirely) so you don't get double pop-ups.

## Styles
Pick a style at the top of the settings, or type `/pl forever` / `/pl midnight`:
- **Midnight**: the clean Horizon look
- **Forever**: gold Morpheus titles, parchment subtitles, teal "Discovered", ornate double gold divider with filigree, dark banner behind the text, slow classic fade

A style just fills in the settings below; change anything afterwards.

Works on Retail/Midnight and WoW: Forever.

## Customize
Esc > Options > AddOns > Presence Lite, or type `/pl`.
- Turn each pop-up type on or off
- Font, outline, shadow, title/subtitle/"Discovered" sizes, divider
- Scale, position (drag with `/pl unlock`), fade-in/out and on-screen time
- Colour for every element
- Hide Blizzard's own zone text, yellow quest text and level-up banner
- Stay quiet in combat or in dungeons/raids

## Commands
`/pl` settings, `/pl test` preview, `/pl unlock` / `/pl lock`, `/pl forever` / `/pl midnight`, `/pl on|off|toggle`, `/pl reset`

## Install with WowUp
In WowUp: **Get Addons > Install from URL**, paste `https://github.com/SmolderingEgo/PresenceLite-`, and install. WowUp picks up new versions from this repo's Releases.

## Releasing a new version
Change the number in `VERSION` (e.g. `1.2.0`), commit and push to `main`. The GitHub Action tags it, builds the zip plus the `release.json` WowUp reads, and publishes the release. You can also re-run it from the Actions tab.
