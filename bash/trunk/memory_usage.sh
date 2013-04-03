#!/bin/sh

/usr/bin/printf "%-6s %-9s %s\n" "PID" "Total" "Command"
/usr/bin/printf "%-6s %-9s %s\n" "---" "-----" "-------"

ps=$(which ps)
awk=$(which awk)
tail=$(which tail)
sort=$(which sort)
pmap=$(which pmap)

for PID in `$ps -e | $awk '$1 ~ /[0-9]+/ { print $1 }'`
do
   CMD=`$ps -o comm -p $PID | $tail -1`
   # Avoid "pmap: cannot examine 0: system process"-type errors
   # by redirecting STDERR to /dev/null
   TOTAL=`$pmap $PID 2>/dev/null | $tail -1 | \
$awk '{ print $2 }'`
   [ -n "$TOTAL" ] && /usr/bin/printf "%-6s %-9s %s\n" "$PID" "$TOTAL" "$CMD"
done | $sort -rn -k2
