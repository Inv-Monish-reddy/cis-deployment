#!/bin/bash
# Start both apps
#java -cp /deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar com.rtwo.med.device.simulation.Main -ip connectengine -d VividVueM12Device &
#java -cp /deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar com.rtwo.med.device.simulation.Main -ip connectengine -d Smithsc9Device &
#java -cp /deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar com.rtwo.med.device.simulation.Main -ip connectengine -d EvitaV600Device &
# Prevent container from exiting
#wait

set -e

DEVICES=${DEVICES}

for device in $(echo "$DEVICES" | tr ',' ' ')
do
  echo "Starting device: $device"
  java -cp /deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar com.rtwo.med.device.simulation.Main -ip connectengine -d "$device" &
done

wait