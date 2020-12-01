#!/usr/bin/env bash
set -ex

MODNAME="langpack-RimWorld-fr"

# Mod designed to deliver the latest French translation files.
# This script copies the latest contents of RimWorld-fr/Core and RimWorld-fr/Royalty in the Languages/French subfolders of the current mod,
# then "langpack-RimWorld-fr" to the RimWorld's Mods folder at $RELEASE_DIR.
#
# All other translation mods will also add themselves in Languages/French
# using their own release-update scripts.
#
# Most mods do not support more than on subfolder level in DefInjected/,
# so filenames are prefixed with the mod names, ensuring their uniqueness.
# Do not use names with space !
#
# The file LoadFolders should ensure proper loading in the game, if there are
# additional contents.

# Organisation of the folders
# BASEDIR/
#  +-RimWorld-fr/ : local git for Ludeon/RimWorld-fr
#  +-langpack-RimWorld-fr/ : language pack mod
#    +-About/
#    |	+-About.xml
#    |	+-Other stuffs...
#    +-LoadFolders.xml

# RELEASE_DIR/
#  +-langpack-RimWorld-fr/ : language pack mod
#    +-LoadFolders.xml
#    +-About/
#    +-Languages/
#    |    +-French/
#    |      +-Keyed/
#    |        +-Core-...xml
#    |        +-Royalty-...xml
#    |        +-ModManager-...xml
#    |        +-OtherMods-...xml
#    |      +-DefInjected/
#    |        +-XXX_Def
#    |          +-Core-...xml
#    |          +-Royalty-...xml
#    |        +-etc.
#    +-...

# Set up working dirs variables.
# Alternative method: cut two slashes of dirname with "${P%/*/*}"
mydir=$(dirname "$(readlink -f "$0")")
BASEDIR=$(cd "$mydir" && cd ../.. && pwd)
MODPACK_DIR="$BASEDIR/$MODNAME"

# Location of RimWorld Mods folder
RELEASE_DIR="$HOME/.steam/steam/steamapps/common/RimWorld/Mods/"

# 0. Retrieve french language in all mods
# format: "ModName:LanguageRootFolder:GitReleaseBranch"
declare -a MODLIST=( \
  "Core;$HOME/git/RimWorld-lang/RimWorld-fr/Core;master"\
  "Royalty;$HOME/git/RimWorld-lang/RimWorld-fr/Royalty;master"\
  "ModManager;$HOME/git/FluffierThanThou/ModManager/Languages/French;1.2"\
  "EdBPrepareCarefully;$HOME/git/EdBPrepareCarefully-fr/Languages/French;master"\
  "Numbers;$HOME/git/Numbers/Numbers-fr/Languages/French;main"\
  "NumbersTraitAddOn;$HOME/git/Numbers/Numbers Trait AddOn-fr/Languages/French;main"\
  )

cd "$MODPACK_DIR"
[ -d "Languages" ] || mkdir "Languages"
[ -d "Languages/French" ] || mkdir "Languages/French"
[ -d "Languages/French/Keyed" ] || mkdir "Languages/French/Keyed"
[ -d "Languages/French/DefInjected" ] || mkdir "Languages/French/DefInjected"

# Copy some Core files 
cp --update -R "$HOME/git/RimWorld-lang/RimWorld-fr/Core/WordInfo" "Languages/French"
cp --update -R "$HOME/git/RimWorld-lang/RimWorld-fr/Core/Strings" "Languages/French"

for MODINFO in "${MODLIST[@]}"
do
  IFS=";" read -r -a MOD <<< "${MODINFO}"
  NAME=${MOD[0]}
  ROOT=${MOD[1]}
  RELEASETAG=${MOD[2]}
#   [ -d "Languages/French/Keyed/$NAME" ] || mkdir "Languages/French/Keyed/$NAME"
#   [ -d "Languages/French/DefInjected/$NAME" ] || mkdir "Languages/French/DefInjected/$NAME"

  cd "$ROOT"
  # save git current branch
  CURRENT="`git rev-parse --abbrev-ref HEAD`"
  git checkout $RELEASETAG
  # Copy to langpack-RimWorld-fr/Languages/French/$Name
  if [ -d "Keyed" ] ; then
    cd Keyed
    # Copy all files with mangled names
    for f in * ; do
      cp --update -R "$f" "$MODPACK_DIR/Languages/French/Keyed/$NAME-$f"
    done
  fi
  cd ..
  if [ -d "DefInjected" ] ; then
    cd DefInjected
    for d in * ; do
      # Preserve Def folder name
      [ -d "$MODPACK_DIR/Languages/French/DefInjected/$d" ]\
        || mkdir "$MODPACK_DIR/Languages/French/DefInjected/$d"
      cd "$d"
      # Copy all files with mangled names
      for f in * ; do
        cp --update -R "$f" "$MODPACK_DIR/Languages/French/DefInjected/$d/$NAME-$f"
      done
      cd ..
    done
  fi
  git checkout $CURRENT
  # Next
  cd "$MODPACK_DIR"
done

# 1. Validate all xml files
find . -maxdepth 5 -type f -name '*.xml' -exec sh -c '
  for f; do
    mimetype -b "$f" | grep -Eq "application/xml" &&
    xmllint --noout "$f"
  done
' sh {} +

# cd "Languages"
# tar -cvf "French.tar"  "French"
# tar -cvf "French (Français).tar"  "French"
# rm -Rf "./French"
cd "$MODPACK_DIR"

# 2. Create a zip archive

# First, save existing zip
[ -d "Archives" ] || mkdir "Archives"
if [ -f "Archives/$MODNAME.zip" ] ; then
  [ -d "Old-Archives" ] || mkdir "Old-Archives"
  LASTMODIFICATION="$(date +"%F-%H-%M-%S" -r Archives/"$MODNAME".zip)"
  cp "Archives/$MODNAME.zip" \
    "Old-Archives/$MODNAME-$LASTMODIFICATION.zip"
  rm -f "Archives/$MODNAME.zip"
fi

# Then, zip the whole FR dir
cd "$BASEDIR"
zip -r "$MODNAME/Archives/$MODNAME.zip" \
  "$MODNAME/About" \
  "$MODNAME/README.md"

# 3. Copy all files to $RELEASE_DIR
# NOTE: it may be better use extended glob to exclude some dirs like this ?
# shopt -s extglob
# cp --update -R "$MODNAME/!(Old-Archives | scripts | .git)" "$RELEASE_DIR"
cp --update -R "$MODNAME/" "$RELEASE_DIR"
# Clean up unnecessary files
rm -Rf "$RELEASE_DIR/$MODNAME/Old-Archives"
rm -Rf "$RELEASE_DIR/$MODNAME/scripts"
rm -Rf "$RELEASE_DIR/$MODNAME/.git"
rm -Rf "$RELEASE_DIR/$MODNAME/Archives"
rm -f  "$RELEASE_DIR/$MODNAME/.gitignore"

cd "$MODPACK_DIR"

# 4. Test in game

# 5. Push to Steam Workshop, copy PublishedFileId.txt to the local repo.

# 6. Create repo on GitHub.
#   - git clone
#   - Copy the correct files in the local repo.
#   - Commit and push modification to ($MODNAME)origin/master
#   - Verify texts
#   - Create release on github
#   - git pull to local repo

# 9. Push release to $RELEASE_DIR, then push to Steam Workshop


