#!/bin/bash
# Run multiple instances of PX4 SITL with Gazebo in headless mode for gz_x500 model
# Assumes PX4 is built with 'make px4_sitl_default'

# Number of instances (default 2, override with argument)
sitl_num=2
[ -n "$1" ] && sitl_num="$1"

# Set up paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_path="$SCRIPT_DIR/../../"
build_path="${src_path}/build/px4_sitl_default"  # Corrected to match standard build

# Kill existing processes
echo "Killing running instances"
pkill -x px4 || true
pkill -f gzserver || true  # Stop any Gazebo server

sleep 1

# Start Gazebo in headless mode
echo "Starting Gazebo in headless mode"
gz sim -s -r "${src_path}/Tools/simulation/gz/worlds/default.sdf" &
sleep 5  # Wait for Gazebo to initialize

# Launch PX4 SITL instances
n=0
while [ $n -lt $sitl_num ]; do
    working_dir="$build_path/instance_$n"
    [ ! -d "$working_dir" ] && mkdir -p "$working_dir"

    pushd "$working_dir" &>/dev/null
    echo "Starting instance $n in $(pwd)"
    export PX4_INSTANCE=$n
    export PX4_SIM_MODEL=gz_x500
    $build_path/bin/px4 -i $n -d "$build_path/etc" >out.log 2>err.log &
    popd &>/dev/null

    n=$(($n + 1))
done

echo "Launched $sitl_num PX4 instances with Gazebo in headless mode"
