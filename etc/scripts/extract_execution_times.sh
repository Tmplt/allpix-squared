#!/usr/bin/env bash

# Script used on Allpix² logs to extract event execution times and averaged module execution times.
# Only detector-specific module execution times are averaged.
# When averaging modules execution times, the number of detectors is found by grepping how many times
# the last module (probably DefaultDigitizer) appears in the logs module summary section.
#
# Note that event execution times are printed in milliseconds while module execution times are printed in seconds.

# Enable Bash "Strict Mode"
set -euo pipefail
IFS=$'\n\t'

usage() { echo "$0 <-e|-m> <log_file>"; }

### Parse command line arguments ###

if (( $# == 0 )); then
  usage
  exit 1
fi

event_flag='false'
module_flag='false'

while getopts "em" flag; do
  case "${flag}" in
    e) event_flag=true ;;
    m) module_flag=true ;;
    *) usage; exit 1 ;;
  esac
done

log=${@:$OPTIND:1}
if [ -z "$log" ] || [ $event_flag == 'false' ] && [ $module_flag == 'false' ]; then
  echo "Missing log file or flags. Flags must precede the log file."
  exit 2
fi

### Main function definitions ###

# Calculates the millisecond difference between two date-compatible timestamps
function ms_diff {
  # Consider all passed arguments as base 10 by prefixing with '10#'
  local sec_diff=$(( 10#$(date -d "$1" +%s) - 10#$(date -d "$2" +%s) ))
  local nano_diff=$(( 10#$(date -d "$1" +%N) - 10#$(date -d "$2" +%N) ))
  echo $(( (sec_diff * 1000) + (nano_diff / 1000000) ))
}

function extract_event_times {
  # Extract the timestamp from each started event, and the last finished event.
  # Resulting array will be number_of_events + 1
  pattern="s/^.*|\s*\(\S*\)|.*$/\1/p"
  readarray -t timestamps <<< $(grep -e 'Running event' -e 'Finished run' "$log" | sed -n $pattern)

  # Calculate how many milliseconds each event required
  for idx in "${!timestamps[@]}"; do
    if (( idx >= ${#timestamps[@]} - 1 )); then break; fi
    ms_diff "${timestamps[idx + 1]}" "${timestamps[idx]}"
  done
}

# Calulcates all arguments with bc and prints result as a float with prefix 0 and six significant digits
function _bc {
  echo $(echo "$@" | bc -l | awk '{printf "%.6g", $0}')
}

function extract_avg_module_times {
  # Extract lines containing module names and the time it took to run them
  readarray -t entries <<< $(grep -e 'Module \S* took' "$log" | awk '{print $4 " " $6}')

  # First, print out times for global modules; these need not be averaged.
  for entry in "${entries[@]}"; do
    [[ "$entry" == *":"* ]] && continue # modules containing ':' are not global
    echo $entry
  done

  # Now, collect times for remaining detector-specific modules.
  declare -A module_times
  for entry in "${entries[@]}"; do
    [[ "$entry" != *":"* ]] && continue # modules without ':' are not module-specific
    module=$(echo $entry | sed -n "s/\(\S*\):.*$/\1/p")
    local seconds=$(echo $entry | awk '{print $2}')

    # If the module does not already exist, create it with $seconds as start value.
    # If the module does exist in the map, add $seconds to it.
    module_times[$module]=$(_bc "${module_times[$module]:-0} + $seconds")
  done

  # Figure out how many detectors there are by counting how many the last module shows up in the log summary
  detector_count=$(for entry in "${entries[@]}"; do echo $entry; done | grep $module | wc -l)

  # Print the module averages
  for key in "${!module_times[@]}"; do
    echo $key $(_bc "${module_times[$key]} / $detector_count")
  done
}

### Execution ###

if [ $event_flag == 'true' ]; then
  extract_event_times
fi

if [ $module_flag == 'true' ]; then
  [[ $event_flag == 'true' ]] && echo # Seperate outputs with newline
  extract_avg_module_times
fi

# vim: shiftwidth=2
