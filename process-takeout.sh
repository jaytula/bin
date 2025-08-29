#!/bin/bash

# ==============================================================================
# Google Photos Takeout - Metadata Fixer Script (v7 - Definitive)
#
# This definitive version modifies Phase 2.5 to copy metadata directly
# from the fixed .jpg to its orphaned .MP4, bypassing empty JSON files.
# This is the most robust and complete solution.
#
# ==============================================================================

# --- PRE-FLIGHT CHECKS ---
set -e
if ! command -v exiftool &> /dev/null; then
    echo "ERROR: exiftool is not installed or not in your PATH."
    exit 1
fi

echo "=================================================================="
echo "  Google Photos Metadata Fixer (v7 - Definitive) - Starting"
echo "=================================================================="
echo "Press Ctrl+C within 5 seconds to cancel."
sleep 5

# --- PHASE 1: FIND AND FIX CORRUPTED FILES ---
# (No changes here)
echo
echo "--- Phase 1: Finding and fixing corrupted image files... ---"
exiftool -r -fast -if 'not $filename =~ /-edited/i' . 2> errors.log || true
if [ -s errors.log ]; then
    grep "Error reading" errors.log | cut -d- -f2- | sed 's/^ *//' > files_to_fix.txt || true
    if [ -s files_to_fix.txt ]; then
        echo "Found corrupted files. Starting repair process..."
        while IFS= read -r file; do
            echo "  -> Fixing structure of: $file"
            exiftool -all= -tagsfromfile @ -all:all -unsafe -icc_profile -overwrite_original -q "$file"
            exiftool -d %s -tagsfromfile "${file}.supplemental-*.json" "-all:all<exififd:datetimeoriginal" "-GPSLatitude<GPSLatitude" "-GPSLongitude<GPSLongitude" "-GPSAltitude<GPSAltitude" "-Keywords<Tags" "-Subject<Tags" "-Caption-Abstract<Description" "-ImageDescription<Description" "-UserComment<Description" -overwrite_original -q "$file"
        done < files_to_fix.txt
        echo "Corruption repair complete."
    else
        echo "No files with 'Error reading' corruption found."
    fi
else
    echo "No errors found during initial scan."
fi
rm -f errors.log files_to_fix.txt

# --- PHASE 2: APPLY METADATA TO ALL ORIGINAL PHOTOS ---
# (No changes here)
echo
echo "--- Phase 2: Applying metadata from .json files to all originals... ---"
find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" -o -iname "*.mp4" -o -iname "*.mov" \) ! -iname "*-edited.*" ! -iname "MVIMG*.MP4" | while read -r media_file; do
    shopt -s nullglob
    json_files=("${media_file}.supplemental-"*.json)
    shopt -u nullglob

    if [ ${#json_files[@]} -eq 1 ]; then
        json_file="${json_files[0]}"
        echo "Processing: $media_file"
        exiftool -d %s \
            -tagsfromfile "$json_file" \
            "-all:all<exififd:datetimeoriginal" "-createdate<datetimeoriginal" "-modifydate<datetimeoriginal" \
            "-GPSLatitude<GPSLatitude" "-GPSLongitude<GPSLongitude" \
            "-GPSAltitude<GPSAltitude" \
            "-Keywords<Tags" "-Subject<Tags" \
            "-Caption-Abstract<Description" "-ImageDescription<Description" \
            "-UserComment<Description" \
            -overwrite_original "$media_file" 2>&1 | grep -v "Warning: \[minor\]" || true
    else
        echo "Warning: Could not find a unique JSON for $media_file. Skipping."
    fi
done
echo "Main metadata application complete."

# --- PHASE 2.5: APPLY METADATA TO ORPHANED MOTION PHOTO VIDEOS ---
echo
echo "--- Phase 2.5: Fixing orphaned Motion Photo (.MP4) videos... ---"
# Find only the .MP4 files from Motion Photos
find . -type f -iname "MVIMG*.MP4" | while read -r mp4_file; do
    # NEW LOGIC: Define the source as the corresponding .jpg file
    jpg_source_file="${mp4_file%.*}.jpg"

    # Check if the source .jpg file actually exists
    if [ -f "$jpg_source_file" ]; then
        echo "Applying metadata to orphan MP4: $mp4_file from $jpg_source_file"
        
        # Copy tags directly FROM the JPG TO the MP4
        exiftool -tagsfromfile "$jpg_source_file" \
            '-Track*Date<DateTimeOriginal' \
            '-Media*Date<DateTimeOriginal' \
            '-Keys:GPSCoordinates<Composite:GPSPosition' \
            -overwrite_original "$mp4_file" 2>&1 | grep -v "Warning: \[minor\]" || true
    else
        echo "Warning: Could not find source JPG for $mp4_file. Skipping."
    fi
done
echo "Orphaned Motion Photo video processing complete."


# --- PHASE 3: APPLY METADATA TO EDITED PHOTOS ---
# (No changes here)
echo
echo "--- Phase 3: Copying metadata from originals to '-edited' versions... ---"
exiftool -r -if '$filename =~ /-edited/i' \
    -tagsfromfile %d/%-.7f.%e \
    -all:all \
    -ext jpg -ext JPG \
    -overwrite_original . 2>&1 | grep -v "Warning: \[minor\]" || true

echo "Edited versions have been updated."
echo

# --- FINAL MESSAGE ---
echo "=================================================================="
echo "                        PROCESS COMPLETE!"
echo "=================================================================="
