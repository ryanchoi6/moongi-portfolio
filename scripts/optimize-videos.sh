#!/usr/bin/env bash
# optimize-videos.sh — Compress all videos for web deployment
# Usage: bash scripts/optimize-videos.sh
#
# Creates compressed MP4 + WebM + poster JPEGs alongside originals.
# Originals are moved to videos-original/ for backup.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIGINAL_BACKUP="$PROJECT_ROOT/videos-original"

# Background videos (higher compression, no audio)
BG_VIDEOS=(
	"intro-bg.mp4"
	"studio-bg.mp4"
	"videos/brand-vault/brand-bg.mp4"
)

# All portfolio videos (standard compression)
PORTFOLIO_DIRS=(
	"videos/architects-office"
	"videos/brand-vault"
)

mkdir -p "$ORIGINAL_BACKUP"

compress_bg() {
	local src="$1"
	local dir=$(dirname "$src")
	local base=$(basename "$src" .mp4)
	local mp4_out="${dir}/${base}.mp4"
	local webm_out="${dir}/${base}.webm"
	local poster_out="${dir}/${base}-poster.jpg"

	echo "━━━ BG: $src"

	# Backup original
	local backup_dir="$ORIGINAL_BACKUP/$(dirname "$src")"
	mkdir -p "$backup_dir"
	cp "$PROJECT_ROOT/$src" "$backup_dir/" 2>/dev/null || true

	# Poster JPEG (first frame)
	ffmpeg -y -i "$PROJECT_ROOT/$src" -vframes 1 -vf "scale=-2:720" -q:v 2 "$PROJECT_ROOT/$poster_out" 2>/dev/null
	echo "  ✓ poster: $poster_out"

	# Compressed MP4 (CRF 32, no audio, 720p)
	ffmpeg -y -i "$PROJECT_ROOT/$src" \
		-c:v libx264 -crf 32 -preset slow \
		-vf "scale=-2:'min(720,ih)'" \
		-an -movflags +faststart \
		"$PROJECT_ROOT/${dir}/${base}-compressed.mp4" 2>/dev/null
	echo "  ✓ mp4:    ${dir}/${base}-compressed.mp4 ($(du -h "$PROJECT_ROOT/${dir}/${base}-compressed.mp4" | cut -f1))"

	# WebM (CRF 38, no audio, 720p)
	ffmpeg -y -i "$PROJECT_ROOT/$src" \
		-c:v libvpx-vp9 -crf 38 -b:v 0 \
		-vf "scale=-2:'min(720,ih)'" \
		-an \
		"$PROJECT_ROOT/$webm_out" 2>/dev/null
	echo "  ✓ webm:   $webm_out ($(du -h "$PROJECT_ROOT/$webm_out" | cut -f1))"

	# Replace original with compressed
	mv "$PROJECT_ROOT/${dir}/${base}-compressed.mp4" "$PROJECT_ROOT/$mp4_out"
	echo ""
}

compress_portfolio() {
	local src="$1"
	local dir=$(dirname "$src")
	local base=$(basename "$src" .mp4)
	local mp4_out="${dir}/${base}.mp4"
	local webm_out="${dir}/${base}.webm"
	local poster_out="${dir}/${base}-poster.jpg"

	# Skip background videos (handled separately)
	for bg in "${BG_VIDEOS[@]}"; do
		[ "$src" = "$bg" ] && return 0
	done

	echo "━━━ Portfolio: $src"

	# Backup original
	local backup_dir="$ORIGINAL_BACKUP/$(dirname "$src")"
	mkdir -p "$backup_dir"
	cp "$PROJECT_ROOT/$src" "$backup_dir/" 2>/dev/null || true

	# Poster JPEG (first frame)
	ffmpeg -y -i "$PROJECT_ROOT/$src" -vframes 1 -vf "scale=-2:720" -q:v 2 "$PROJECT_ROOT/$poster_out" 2>/dev/null
	echo "  ✓ poster: $poster_out"

	# Compressed MP4 (CRF 28, AAC 128k, 720p)
	ffmpeg -y -i "$PROJECT_ROOT/$src" \
		-c:v libx264 -crf 28 -preset slow \
		-vf "scale=-2:'min(720,ih)'" \
		-c:a aac -b:a 128k \
		-movflags +faststart \
		"$PROJECT_ROOT/${dir}/${base}-compressed.mp4" 2>/dev/null
	echo "  ✓ mp4:    ${dir}/${base}-compressed.mp4 ($(du -h "$PROJECT_ROOT/${dir}/${base}-compressed.mp4" | cut -f1))"

	# WebM (CRF 35, Opus 96k, 720p)
	ffmpeg -y -i "$PROJECT_ROOT/$src" \
		-c:v libvpx-vp9 -crf 35 -b:v 0 \
		-vf "scale=-2:'min(720,ih)'" \
		-c:a libopus -b:a 96k \
		"$PROJECT_ROOT/$webm_out" 2>/dev/null
	echo "  ✓ webm:   $webm_out ($(du -h "$PROJECT_ROOT/$webm_out" | cut -f1))"

	# Replace original with compressed
	mv "$PROJECT_ROOT/${dir}/${base}-compressed.mp4" "$PROJECT_ROOT/$mp4_out"
	echo ""
}

echo "═══════════════════════════════════════"
echo "  Moongi Portfolio — Video Optimizer"
echo "═══════════════════════════════════════"
echo ""

# Process background videos
echo "▸ Background Videos (CRF 32, no audio)"
echo "───────────────────────────────────────"
for bg in "${BG_VIDEOS[@]}"; do
	if [ -f "$PROJECT_ROOT/$bg" ]; then
		compress_bg "$bg"
	else
		echo "  ⚠ Not found: $bg"
	fi
done

# Process portfolio videos
echo "▸ Portfolio Videos (CRF 28, AAC 128k)"
echo "───────────────────────────────────────"
for dir in "${PORTFOLIO_DIRS[@]}"; do
	if [ -d "$PROJECT_ROOT/$dir" ]; then
		for f in "$PROJECT_ROOT/$dir"/*.mp4; do
			[ -f "$f" ] || continue
			rel="${f#$PROJECT_ROOT/}"
			compress_portfolio "$rel"
		done
	fi
done

# Also handle root portfolio videos (if any non-bg mp4s exist)
for f in "$PROJECT_ROOT"/*.mp4; do
	[ -f "$f" ] || continue
	rel="${f#$PROJECT_ROOT/}"
	is_bg=false
	for bg in "${BG_VIDEOS[@]}"; do
		[ "$rel" = "$bg" ] && is_bg=true
	done
	$is_bg || compress_portfolio "$rel"
done

echo ""
echo "═══════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════"
echo ""
echo "MP4 sizes:"
find "$PROJECT_ROOT" -name "*.mp4" -not -path "*/videos-original/*" -not -path "*/.git/*" -exec du -h {} \; | sort -rh
echo ""
echo "Total MP4:"
find "$PROJECT_ROOT" -name "*.mp4" -not -path "*/videos-original/*" -not -path "*/.git/*" -exec du -ch {} + | tail -1
echo ""
echo "WebM files:"
find "$PROJECT_ROOT" -name "*.webm" -not -path "*/videos-original/*" -exec du -h {} \; | sort -rh
echo ""
echo "Poster images:"
find "$PROJECT_ROOT" -name "*-poster.jpg" -exec du -h {} \; | sort -rh
echo ""
echo "Done! Originals backed up to: $ORIGINAL_BACKUP"
