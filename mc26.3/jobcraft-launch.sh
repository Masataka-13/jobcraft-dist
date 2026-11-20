#!/bin/bash
# JobCraft 26.3: Prism launcher pre-launch script for Mac / Linux (same as jobcraft-launch.ps1 for Windows)
# Prism "pre-launch command":
#   bash -c "curl -fsSL https://raw.githubusercontent.com/Masataka-13/jobcraft-dist/main/mc26.3/jobcraft-launch.sh | bash"
#
# 1. Mods you unchecked in Prism (mods/*.jar.disabled) are renamed back to *.jar for a moment,
#    so packwiz sees them as installed and does not download them again.
# 2. Runs packwiz (updates the pack).
# 3. Renames those mods back to *.jar.disabled, so they stay unchecked.
# Also removes leftover *.duplicate files.
# Works with the bash 3.2 that comes with macOS.

PACK='https://raw.githubusercontent.com/Masataka-13/jobcraft-dist/main/mc26.3/pack.toml'
# raw.githubusercontent.com caches files ~5 min; right after an update old/new files can mix.
# Use the newest commit id (that address never changes, so all files match).
SHA=$(curl -fsSL -m 10 -H 'User-Agent: jobcraft-launch' https://api.github.com/repos/Masataka-13/jobcraft-dist/commits/main 2>/dev/null | grep -o '"sha": *"[0-9a-f]\{40\}"' | head -n 1 | grep -o '[0-9a-f]\{40\}')
if [ -n "$SHA" ]; then
	PACK="https://raw.githubusercontent.com/Masataka-13/jobcraft-dist/$SHA/mc26.3/pack.toml"
else
	echo "[JobCraft] could not get the newest commit id (using main)"
fi
BOOT_URL='https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar'

MC="${INST_MC_DIR:-$PWD}"
JAVA="${INST_JAVA:-java}"
MODS="$MC/mods"
BOOT="$MC/packwiz-installer-bootstrap.jar"
mkdir -p "$MODS"

if [ ! -f "$BOOT" ]; then
	echo "[JobCraft] downloading packwiz-installer-bootstrap.jar"
	curl -fsSL "$BOOT_URL" -o "$BOOT"
fi

for f in "$MODS"/*.duplicate; do
	[ -e "$f" ] || continue
	echo "[JobCraft] remove $(basename "$f")"
	rm -f "$f"
done

# 1. unchecked mods -> *.jar for a moment
DISABLED=()
for f in "$MODS"/*.jar.disabled; do
	[ -e "$f" ] || continue
	jar="${f%.disabled}"
	[ -e "$jar" ] && rm -f "$jar"   # both exist: keep the unchecked state, drop the extra jar
	mv "$f" "$jar"
	DISABLED+=("$jar")
done
[ ${#DISABLED[@]} -gt 0 ] && echo "[JobCraft] unchecked mods: ${#DISABLED[@]}"

# 3. always put them back, even if packwiz fails
restore() {
	for jar in "${DISABLED[@]}"; do
		if [ -e "$jar" ]; then
			if [ -e "$jar.disabled" ]; then rm -f "$jar"; else mv "$jar" "$jar.disabled"; fi
		fi
	done
}
trap restore EXIT

# 2. update the pack
( cd "$MC" && "$JAVA" -jar "$BOOT" -g "$PACK" )  # -g = no window || echo "[JobCraft] packwiz failed (starting the game anyway)"
exit 0
