#!/bin/bash
# Copy the UART IP lab-style flow into the lab folder layout used in the class projects:
#
#   <dest>/TOP/RTL   uart_*.v, uart_defs.vh
#   <dest>/TOP/SIM   testbenches, apb_master.vh, run_function.tcl, run_post_max/min.tcl
#   <dest>/TOP/SYN   run_synthesis, script/, cons/
#   <dest>/TOP/PNR   all.tcl, uart_top.mmmc.view, uart_top_func.sdc, tempus.tcl, eco.tcl
#   <dest>/TOP/EC    script_rtl2syn.tcl, script_syn2pnr.tcl (+ links uart_defs.vh, lib/)
#
# The repository is not changed: this makes a copy (run it on the school server, after git pull).
# Paths inside the copied scripts are rewritten to the lab form (../RTL, ../SYN, ../PNR).
#
# Usage (from anywhere, in bash):
#   bash tools/uart_lab_tree.sh <dest>             scripts and sources only (git-tracked files)
#   bash tools/uart_lab_tree.sh <dest> --results   also the tool outputs already made in the repo
#                                                   (syn mapped/report/log, PnR outputs, sim logs)
#   bash tools/uart_lab_tree.sh <dest> -f          replace an existing <dest>/TOP (its results are lost)
#   bash tools/uart_lab_tree.sh <dest> --update    copy the git-tracked files again over an existing
#                                                   <dest>/TOP (scripts, RTL, testbench); tool results stay
# Example: bash tools/uart_lab_tree.sh ~/PROJ1/uart_ip
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST=""; RESULTS=0; FORCE=0; UPDATE=0
for a in "$@"; do
    case "$a" in
        --results) RESULTS=1 ;;
        -f)        FORCE=1 ;;
        --update)  UPDATE=1 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        -*)        echo "ERROR: unknown option $a"; exit 1 ;;
        *)         DEST="$a" ;;
    esac
done
[ -n "$DEST" ] || { echo "ERROR: give the destination folder, e.g. bash tools/uart_lab_tree.sh ~/PROJ1/uart_ip"; exit 1; }
TOP="$DEST/TOP"
case "$(cd "$DEST" 2>/dev/null && pwd)/" in
    "$ROOT"/*) echo "ERROR: the destination must be outside the repository"; exit 1 ;;
esac
if [ "$UPDATE" = 1 ]; then
    [ -d "$TOP" ] || { echo "ERROR: --update needs an existing $TOP"; exit 1; }
    [ "$RESULTS" = 0 ] && [ "$FORCE" = 0 ] || { echo "ERROR: --update cannot be used with --results or -f"; exit 1; }
    echo "update: git-tracked files are copied over $TOP, tool results are kept"
elif [ -e "$TOP" ]; then
    [ "$FORCE" = 1 ] || { echo "ERROR: $TOP exists (use -f to replace it, or --update to refresh the scripts only)"; exit 1; }
    rm -rf "$TOP"
fi
mkdir -p "$TOP"/{RTL,SIM,SYN,PNR,EC} || exit 1

# files of one repo folder: git-tracked only, or the whole folder with --results
copy_dir() {    # <repo folder> <dest folder> <names to skip...>
    local src="$1" dst="$2"; shift 2
    local skip=" $* "
    if [ "$RESULTS" = 1 ]; then
        ( cd "$ROOT/$src" && for f in * .[!.]*; do
              [ -e "$f" ] || continue
              case "$skip" in *" $f "*) continue ;; esac
              cp -a "$f" "$dst/"
          done )
    else
        ( cd "$ROOT" && git ls-files "$src" ) | while read -r f; do
            local rel="${f#$src/}"
            case "$skip" in *" ${rel%%/*} "*) continue ;; esac
            mkdir -p "$dst/$(dirname "$rel")"
            cp -p "$ROOT/$f" "$dst/$rel"
        done
    fi
}

# project-style files (wrappers, xrun arg files, repo clean script, repo READMEs) are not copied
copy_dir rtl/ip_uart "$TOP/RTL"
copy_dir sim/ip_uart "$TOP/SIM" run_uart_tests.sh run_uart_tests.py run_bug_models.py uart_rtl.f uart_probe.tcl
copy_dir syn/ip_uart "$TOP/SYN" README.md clean.tcl
copy_dir pnr/ip_uart "$TOP/PNR" README.md clean.tcl
copy_dir ec/ip_uart  "$TOP/EC"  README.md clean.tcl
cp -p "$ROOT/sim/ch14a_mcu/apb_master.vh" "$TOP/SIM/"      # shared APB BFM, `include in uart_top_tb.v

# repo paths -> lab paths in the copied scripts
for f in "$TOP"/SIM/*.tcl "$TOP"/SYN/script/*.tcl "$TOP"/PNR/all.tcl "$TOP"/EC/*.tcl; do
    [ -f "$f" ] || continue
    sed -i -e 's|\.\./\.\./rtl/ip_uart|../RTL|g' \
           -e 's|\.\./\.\./syn/ip_uart|../SYN|g' \
           -e 's|\.\./\.\./pnr/ip_uart|../PNR|g' \
           -e 's|-incdir \.\./ch14a_mcu|-incdir .|g' \
           -e 's|(sim/ip_uart)|(TOP/SIM)|g; s|(syn/ip_uart)|(TOP/SYN)|g; s|(pnr/ip_uart)|(TOP/PNR)|g' \
           -e 's|in ec/ip_uart|in TOP/EC|g; s|pnr/ip_uart/all.tcl|TOP/PNR/all.tcl|g' "$f"
done
chmod +x "$TOP/SYN/run_synthesis" 2>/dev/null

# LEC run folder: `include file and the cell model link (the GPDK045 folder is at / on both servers)
GPDK045=/GPDK045
mkdir -p "$TOP/EC/log" "$TOP/EC/lib"
ln -sf ../RTL/uart_defs.vh "$TOP/EC/uart_defs.vh"
ln -sf "$GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v" "$TOP/EC/lib/"

cat > "$TOP/README.txt" <<'EOF'
UART IP (uart_top) - lab-style flow, copied from the rv32i-cpu repository (tools/uart_lab_tree.sh)
Run order (each step in its own folder):
  1. RTL sim    cd SIM ; source run_function.tcl        (SimVision: run -> PASS line)
  2. Synthesis  cd SYN ; ./run_synthesis                (or genus, source ./script/uart_top_45nm.tcl)
  3. PnR        cd PNR ; innovus, source all.tcl
  3b. STA / ECO cd PNR ; tempus (tempus.tcl Practice 0; ECO demo: Practice 1 -> innovus, source eco.tcl -> Practice 2)
  4. Gate sim   cd SIM ; source run_post_max.tcl / run_post_min.tcl
  5. LEC        tar czf ~/lec_uart.tar.gz TOP (from the folder above TOP), on the LEC server:
                cd TOP/EC ; lec -xl -dofile script_rtl2syn.tcl / script_syn2pnr.tcl
The repository copy stays the original: change files there and make this copy again.
EOF

echo "UART lab tree: $TOP"
( cd "$TOP" && find . -maxdepth 2 | sort | sed 's|^\./||' | grep -v '^\.$' | head -60 )
# leftover repo paths (should be none)
LEFT=$(grep -ln "\.\./\.\./\(rtl\|syn\|pnr\|sim\)/" "$TOP"/SIM/*.tcl "$TOP"/SYN/script/*.tcl "$TOP"/PNR/all.tcl "$TOP"/EC/*.tcl 2>/dev/null)
[ -z "$LEFT" ] || { echo "WARNING: repo paths left in: $LEFT"; exit 1; }
echo "done"
