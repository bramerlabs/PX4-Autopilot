#!/bin/bash
# File: launch_drones.sh

# Configuration
NUM_DRONES=3
PX4_DIR=~/Desktop/Bramer/PX4-Autopilot
MAVSDK_DIR=~/Desktop/Bramer/os/communication/mavcom/MAVSDK/build/src/mavsdk_server/src
MODEL=gz_x500
WORLD_DIR=$PX4_DIR/Tools/simulation/gz/worlds
BUILD_DIR=$PX4_DIR/build/px4_sitl_default

# Clean up existing processes and directories
echo "Killing running instances"
pkill -f px4
pkill -f gzserver
pkill -f gzclient
pkill -f mavsdk_server
rm -rf $BUILD_DIR/instance_*
rm -rf /tmp/px4_instance_*

# Verify cleanup
if ps aux | grep -E 'px4|gz|mavsdk_server' | grep -v grep; then
  echo "Error: Some processes still running. Please terminate manually."
  exit 1
fi

# Build PX4
echo "Building PX4 SITL"
cd $PX4_DIR
make px4_sitl_default

# Set Gazebo model path
export GZ_SIM_RESOURCE_PATH=$GZ_SIM_RESOURCE_PATH:$PX4_DIR/Tools/simulation/gz/models
if ! gz model -l | grep -q x500; then
  echo "gz_x500 model not found. Attempting to download..."
  cd $PX4_DIR/Tools/simulation/gz/models
  git clone https://github.com/PX4/px4_gz_models.git
  mv px4_gz_models/gz_x500 .
  export GZ_SIM_RESOURCE_PATH=$GZ_SIM_RESOURCE_PATH:$PX4_DIR/Tools/simulation/gz/models
fi

# Launch SITL instances
echo "Starting $NUM_DRONES SITL instances"
for ((i=0; i<$NUM_DRONES; i++)); do
  INSTANCE_DIR=$BUILD_DIR/instance_$i
  mkdir -p $INSTANCE_DIR
  cd $INSTANCE_DIR
  echo "Starting instance $i in $INSTANCE_DIR"
  export PX4_SIM_MODEL=$MODEL
  export PX4_INSTANCE=$i
  $BUILD_DIR/bin/px4 -i $i -d $BUILD_DIR/etc > out.log 2> err.log &
  sleep 1
done

# Wait for SITL to initialize
sleep 5

# Launch Gazebo with default world or inline SDF
echo "Launching Gazebo"
if [ -f $WORLD_DIR/empty.sdf ]; then
  gz sim -r $WORLD_DIR/empty.sdf &
else
  echo "No default world found. Creating inline SDF"
  cat << EOF > /tmp/temp_x500.sdf
<?xml version="1.0" ?>
<sdf version="1.6">
  <world name="default">
    <include>
      <uri>model://gz_x500</uri>
      <name>x500_0</name>
      <pose>0 0 0 0 0 0</pose>
      <plugin name="gz_x500_plugin" filename="libgz_x500_plugin.so">
        <mavlink_udp_port>14540</mavlink_udp_port>
      </plugin>
    </include>
    <include>
      <uri>model://gz_x500</uri>
      <name>x500_1</name>
      <pose>2 0 0 0 0 0</pose>
      <plugin name="gz_x500_plugin" filename="libgz_x500_plugin.so">
        <mavlink_udp_port>14560</mavlink_udp_port>
      </plugin>
    </include>
    <include>
      <uri>model://gz_x500</uri>
      <name>x500_2</name>
      <pose>4 0 0 0 0 0</pose>
      <plugin name="gz_x500_plugin" filename="libgz_x500_plugin.so">
        <mavlink_udp_port>14580</mavlink_udp_port>
      </plugin>
    </include>
  </world>
</sdf>
EOF
  gz sim -r /tmp/temp_x500.sdf &
fi

# Wait for Gazebo
sleep 5

# Launch mavsdk_server instances
echo "Launching mavsdk_server instances"
for ((i=0; i<$NUM_DRONES; i++)); do
  PORT=$((14540 + 20 * i))
  GRPC_PORT=$((50051 + i))
  $MAVSDK_DIR/mavsdk_server -p $GRPC_PORT udpout://127.0.0.1:$PORT &
  echo "Started mavsdk_server for drone $((i+1)) on gRPC port $GRPC_PORT, MAVLink port $PORT"
  sleep 1
done

echo "Launched $NUM_DRONES drones"
