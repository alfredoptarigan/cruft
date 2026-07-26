# Cruft build & release tasks. Run `just` to list.

version := `git describe --tags --always`

default:
    @just --list

# Build debug binaries
build:
    swift build

# Run the full test suite
test:
    swift test

# Build the optimized release binary
release:
    swift build -c release

# Dry-run developer scan against this machine
scan: build
    swift run cruft scan --category developer --dry-run

# Validate the bundled rules file
rules:
    swift run cruft rules validate

# Diagnose Full Disk Access and disk-space discrepancies
doctor: build
    swift run cruft doctor

# Install the release binary (plus its rules bundle) to ~/.local/bin
install: release
    mkdir -p ~/.local/bin
    cp .build/release/cruft ~/.local/bin/
    cp -R .build/release/CleanKit_CleanKit.bundle ~/.local/bin/
    @echo "Installed ~/.local/bin/cruft"

# Assemble Cruft.app from the release build (ad-hoc signed).
# TCC binds FDA to bundle ID + signature, so the grant must be re-given
# after each rebuild — known tradeoff until real signing lands in M6.
app: release
    rm -rf dist/Cruft.app
    mkdir -p dist/Cruft.app/Contents/MacOS dist/Cruft.app/Contents/Resources
    cp .build/release/CruftApp dist/Cruft.app/Contents/MacOS/
    cp -R .build/release/CleanKit_CleanKit.bundle dist/Cruft.app/Contents/Resources/
    cp Sources/CruftApp/Info.plist dist/Cruft.app/Contents/
    codesign --force -s - dist/Cruft.app
    @echo "Run: open dist/Cruft.app"

# Package the release binary into an unsigned DMG under dist/.
# The CleanKit_CleanKit.bundle must ship next to the binary — it carries
# rules.yaml, and `cruft` refuses to run without it.
# Unsigned + un-notarized: downloaded copies hit Gatekeeper; distribution
# via Homebrew tap (builds from source) is the preferred route. See PLAN.md.
dmg: test app
    rm -rf dist/staging
    mkdir -p dist/staging
    cp -R dist/Cruft.app dist/staging/
    cp .build/release/cruft dist/staging/
    cp -R .build/release/CleanKit_CleanKit.bundle dist/staging/
    cp README.md dist/staging/
    hdiutil create -volname "Cruft {{version}}" -srcfolder dist/staging -ov -format UDZO "dist/cruft-{{version}}.dmg"
    rm -rf dist/staging
    @ls -lh dist/*.dmg

# Remove build artifacts and packaged output
clean:
    rm -rf .build dist
