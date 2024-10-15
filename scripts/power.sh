#!/bin/bash

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

flag_c=false

number_format="%07.3f"
time_interval=1

usage_desc() {
    echo "Usage: $0 [-c]"
    echo "  -c Clear the terminal screen before displaying the output"
    exit 1
}

exit_fn() {
    trap SIGINT
    echo ""
    exit
}

# Parse options
while getopts "c" option; do
    case $option in
    c) flag_c=true ;;
    *) usage_desc ;;
    esac
done

if $flag_c; then
    clear
fi

# Path to the energy reading in microjoules (for CPU)
cpu_energy_file="/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"

# Check if the CPU energy file exists
if [ ! -f "$cpu_energy_file" ]; then
    echo "CPU Energy file not found. Make sure intel-rapl is supported and loaded."
    exit 1
fi
LC_NUMERIC="en_US.UTF-8"

display_values() {
    formatted_gpu_power=$(printf "$number_format" "$gpu_power")
    formatted_cpu_power=$(printf "$number_format" "$cpu_power_watts")
    formatted_total_power=$(printf "$number_format" "$total_power")

    # Goes to the start of the first line
    echo -ne "\r"

    # Print the values (-n to not append a newline at the end)
    echo "CPU Power Consumption: $formatted_cpu_power W"
    echo "GPU Power Consumption: $formatted_gpu_power W"
    echo "---"
    echo -n "SUM Power Consumption: $formatted_total_power W"
}

trap "exit_fn" INT

# Function to read energy and calculate CPU power
while true; do

    # call this initially so there is always display
    display_values

    # Read the initial CPU energy value
    cpu_energy1=$(sudo cat $cpu_energy_file)

    # Wait for 1 second
    sleep $time_interval

    # Read the new CPU energy value after 1 second
    cpu_energy2=$(sudo cat $cpu_energy_file)

    # Calculate the CPU energy difference (in microjoules)
    cpu_energy_diff=$((cpu_energy2 - cpu_energy1))

    # Convert CPU energy difference to joules (1 µJ = 1e-6 J)
    cpu_energy_joules=$(echo "$cpu_energy_diff / 1000000" | bc -l)

    # Since we measured over 1 second, CPU power in watts is equal to energy in joules
    cpu_power_watts=$(echo "$cpu_energy_joules / $time_interval" | bc -l)

    # Get GPU power consumption using nvidia-smi (in watts)
    gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits)

    total_power=$(echo "$gpu_power + $cpu_power_watts" | bc -l)

    # moves the cursor up 3 lines
    # called at the end so the cursor is default down, and it doesnt accidentally go over the start
    tput cuu 3

done
