#!/usr/bin/env bash

      source_number=""

      ## new_source is used to make sure loopback is only ever reloaded once
      while [ true ]; do
        pactl subscribe | while read x event y type num; do
          if [ $event == "'new'" -a $type == 'source' ]; then
            echo "event: $event, type: $type, num: $num"
            SOURCE=$(pactl list short sources | grep bluez_source | awk '{ print $2 }') 
            if [ ! -z "$SOURCE" ]; then
              echo "unloading module-loopback"
              pactl unload-module module-loopback
              echo "Loading bluetooth loopback to fifo with input latency of 500ms"
              echo "source: $SOURCE, sink: BluetoothFifo"
              pactl load-module module-loopback latency_msec=500 format=s16le rate=44100 channels=2 source=$SOURCE sink=BluetoothFifo source_dont_move=true sink_dont_move=true
              retval=$?
              if [ $retval -ne 0 ]; then
                # start subscription again on failure. it seems to get stuck
	        break
              fi
            fi 
          fi
        done
      done
