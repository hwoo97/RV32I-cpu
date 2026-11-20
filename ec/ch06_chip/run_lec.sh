#!/bin/bash
# Conformal LEC of the ch6 MCU chip (rv32i_chip): two comparisons
#   rtl2syn : RTL (rtl/ch06_exception)            vs Genus netlist   (rtl2syn.do)
#   syn2pnr : Genus netlist                       vs Innovus netlist (syn2pnr.do)
#
# Pack (school server, after synthesis and PnR): one tar with everything LEC needs
#   bash ec/ch06_chip/run_lec.sh --pack
#   -> ec/ch06_chip/out/lec_ch06_chip.tar.gz (RTL, both netlists, these scripts; no PDK files)
#   On the LEC server: mkdir rv32i_lec; cd rv32i_lec; tar xzf lec_ch06_chip.tar.gz
#                      setenv GPDK045_DIR <GPDK045 folder>; bash ec/ch06_chip/run_lec.sh
#
# Batch (no window, quits, prints the compare summary):
#   bash ec/ch06_chip/run_lec.sh                  # rtl2syn, then syn2pnr
#   bash ec/ch06_chip/run_lec.sh syn2pnr          # one comparison
#   -> run folder: ec/ch06_chip/runs/<compare>/  (log/<compare>.log)
# Interactive (run folder ec/ch06_chip/runs/work/):
#   bash ec/ch06_chip/run_lec.sh -i rtl2syn       # LEC prompt: paste the STEP blocks of rtl2syn.do
#   bash ec/ch06_chip/run_lec.sh --gui rtl2syn    # LEC window, the whole dofile runs in it, stays open
#   bash ec/ch06_chip/run_lec.sh -i --gui rtl2syn # LEC window, STEP blocks yourself
#
# Environment (csh: setenv NAME value, or env NAME=value bash ...):
#   GPDK045_DIR   GPDK045 folder (cell and pad models are linked from it, never copied)
#   SYN_NETLIST   default syn/ch06_chip/runs/t13ns/mapped/rv32i_chip_syn_final.v
#   PNR_NETLIST   default pnr/ch06_chip/runs/t13ns/out/rv32i_chip_pnr.v if it exists,
#                 else pnr/ch06_chip/runs/work/out/rv32i_chip_pnr.v
#   LEC_CMD       LEC launch command (default: lec -xl)
#
# Pass: the compare summary has Equivalent points and no Non-equivalent / Abort points

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EC_DIR="$(cd "$(dirname "$0")" && pwd)"
LEC_CMD="${LEC_CMD:-lec -xl}"

MODE=batch
GUI=0
PACK=0
while [ $# -gt 0 ]; do
    case "$1" in
        -i)     MODE=interactive; shift ;;
        --gui)  GUI=1; shift ;;
        --pack) PACK=1; shift ;;
        *)      break ;;
    esac
done
CMPS="${*:-rtl2syn syn2pnr}"
for c in $CMPS; do
    case "$c" in rtl2syn|syn2pnr) ;; *) echo "ERROR: unknown comparison '$c' (use rtl2syn or syn2pnr)"; exit 1 ;; esac
done

# -- netlists --
SYN_NETLIST="${SYN_NETLIST:-$ROOT/syn/ch06_chip/runs/t13ns/mapped/rv32i_chip_syn_final.v}"
if [ -z "$PNR_NETLIST" ]; then
    if [ -f "$ROOT/pnr/ch06_chip/runs/t13ns/out/rv32i_chip_pnr.v" ]; then
        PNR_NETLIST="$ROOT/pnr/ch06_chip/runs/t13ns/out/rv32i_chip_pnr.v"
    else
        PNR_NETLIST="$ROOT/pnr/ch06_chip/runs/work/out/rv32i_chip_pnr.v"
    fi
fi
[ -f "$SYN_NETLIST" ] || { echo "ERROR: synthesized netlist not found: $SYN_NETLIST (run syn/ch06_chip/run_syn.sh 13)"; exit 1; }
case "$CMPS" in *syn2pnr*)
    [ -f "$PNR_NETLIST" ] || { echo "ERROR: PnR netlist not found: $PNR_NETLIST (run STEP 8 of pnr/ch06_chip)"; exit 1; } ;;
esac

# -- pack: repo-relative paths so the tar unpacks into the same layout --
if [ "$PACK" = 1 ]; then
    [ -f "$PNR_NETLIST" ] || { echo "ERROR: PnR netlist not found: $PNR_NETLIST"; exit 1; }
    mkdir -p "$EC_DIR/out" || exit 1
    TAR="$EC_DIR/out/lec_ch06_chip.tar.gz"
    SYN_REL="${SYN_NETLIST#$ROOT/}"
    PNR_REL="${PNR_NETLIST#$ROOT/}"
    case "$SYN_REL$PNR_REL" in /*) echo "ERROR: netlists must be inside the repository for --pack"; exit 1 ;; esac
    ( cd "$ROOT" && tar czf "$TAR" \
        rtl/ch06_exception sim/ch06_exception/pad_power.v \
        ec/ch06_chip/run_lec.sh ec/ch06_chip/rtl2syn.do ec/ch06_chip/syn2pnr.do \
        ec/ch06_chip/clean.tcl ec/ch06_chip/README.md tools/clean.tcl \
        "$SYN_REL" "$PNR_REL" ) || exit 1
    echo "packed: $TAR"
    tar tzf "$TAR" | sed 's/^/  /'
    echo "copy it to the LEC server, then: tar xzf lec_ch06_chip.tar.gz; bash ec/ch06_chip/run_lec.sh"
    exit 0
fi

# -- library models (from the PDK, not in the repo) --
if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi
CELL_V="$GPDK045_DIR/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v"
PAD_V="$GPDK045_DIR/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v"
for f in "$CELL_V" "$PAD_V"; do
    [ -f "$f" ] || { echo "ERROR: model not found: $f"; exit 1; }
done
if [ "$GUI" = 1 ] && [ -z "$DISPLAY" ]; then
    echo "ERROR: --gui needs an X display (DISPLAY is empty). Use MobaXterm with X11 forwarding, then run again"
    exit 1
fi

# Run folder with the relative paths the dofiles use
setup_run() {
    rm -rf "$1" && mkdir -p "$1/log" "$1/lib" || exit 1
    ln -s "$CELL_V" "$1/lib/slow_vdd1v0_basicCells.v"
    ln -s "$PAD_V" "$1/lib/pads_SS_s1vg.v"
    ln -s "$ROOT/sim/ch06_exception/pad_power.v" "$1/lib/pad_power.v"
    ln -s "$ROOT/rtl/ch06_exception" "$1/rtl"
    for h in rv32i_defs.vh mcu_memmap.vh; do ln -s "$ROOT/rtl/ch06_exception/$h" "$1/$h"; done
    ln -s "$SYN_NETLIST" "$1/syn.v"
    [ -f "$PNR_NETLIST" ] && ln -s "$PNR_NETLIST" "$1/pnr.v"
    echo "syn netlist: $SYN_NETLIST" >  "$1/inputs.txt"
    echo "pnr netlist: $PNR_NETLIST" >> "$1/inputs.txt"
}

# -- Interactive / GUI: runs/work --
if [ "$MODE" = interactive ] || [ "$GUI" = 1 ]; then
    CMP="$(echo $CMPS | awk '{print $1}')"
    setup_run "$EC_DIR/runs/work"
    cd "$EC_DIR/runs/work" || exit 1
    NOGUI="-nogui"; [ "$GUI" = 1 ] && NOGUI=""
    echo "LEC interactive ($CMP), folder: $PWD"
    if [ "$MODE" = interactive ]; then
        echo "  paste the STEP blocks of $EC_DIR/$CMP.do one at a time"
        echo "  or run it all : dofile $EC_DIR/$CMP.do"
        exec $LEC_CMD $NOGUI
    fi
    echo "  the whole dofile runs in the window; LEC stays open at the end (type exit to close)"
    exec $LEC_CMD -dofile "$EC_DIR/$CMP.do"
fi

# -- Batch --
RC=0
for c in $CMPS; do
    RUN="$EC_DIR/runs/$c"
    setup_run "$RUN"
    cd "$RUN" || exit 1
    printf 'dofile %s\nexit -force\n' "$EC_DIR/$c.do" > batch.do
    echo "== $c == (folder: $RUN)"
    $LEC_CMD -nogui -dofile batch.do > log/lec_stdout.log 2>&1 < /dev/null
    LOG="log/$c.log"
    if [ ! -f "$LOG" ]; then
        echo "FAIL: no log ($RUN/$LOG) - see $RUN/log/lec_stdout.log"
        tail -20 log/lec_stdout.log
        RC=1; continue
    fi
    grep -E "^\s*(// )?Error" "$LOG" | head -10
    echo "-- compare summary --"
    grep -E "^\s*(Compared points|Equivalent|Non-equivalent|Abort|Not-compared)" "$LOG"
    if grep -qE "^\s*(Non-equivalent|Abort)" "$LOG"; then
        echo "FAIL: $c has non-equivalent or aborted points (log: $RUN/$LOG)"; RC=1
    elif ! grep -qE "^\s*Equivalent" "$LOG"; then
        echo "FAIL: $c - no compare result found (log: $RUN/$LOG)"; RC=1
    else
        echo "PASS: $c"
    fi
done
exit $RC
