#!/bin/bash
# Gera o appcast.xml do Sparkle para uma release.
#
# Uso: scripts/make_appcast.sh <versão> <build> <dmg> <atributos de assinatura>
#   Os atributos vêm do sign_update, ex.: sparkle:edSignature="…" length="…"
set -euo pipefail

VERSION="$1"
BUILD="$2"
DMG_NAME="$(basename "$3")"
SIGNATURE="$4"
REPO="maiaxi/afina"
DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

cat <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Afina</title>
    <link>https://github.com/$REPO</link>
    <item>
      <title>Afina $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/$REPO/releases/tag/v$VERSION</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/$DMG_NAME" type="application/octet-stream" $SIGNATURE />
    </item>
  </channel>
</rss>
XML
