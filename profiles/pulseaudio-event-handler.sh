set +e

## new_source is used to make sure loopback is only ever reloaded once
while [ true ]; do
  echo "pactl subscribe"
  pactl subscribe | while read x event y type num; do
    # if [ $type != 'client' ]; then
    #   echo "event: $event, type: $type, num: $num"
    # fi
    # When a Bluetooth speaker (sink) connects, route all audio to it.
    # module-switch-on-port-available is unloaded (to protect source routing),
    # so we handle sink switching manually here.
    #
    # IMPORTANT: Only route to dedicated speakers, NOT phones/laptops.
    # When a phone connects to stream audio TO us, it appears as both a
    # bluez_source and a bluez_sink. Routing snapclient back to the phone's
    # sink would create a feedback loop. A real speaker only has a sink,
    # never a source. We detect this by extracting the device MAC from the
    # sink name (e.g. bluez_sink.F4_2B_7D_27_C8_57) and checking if a
    # matching bluez_source exists.
    if [ $event == "'new'" -a $type == 'sink' ]; then
      SINK_NUM=${num:1}
      SINK=$(pactl list sinks short | grep -e "^$SINK_NUM\s" | awk '{ print $2 }')
      if [[ ! -z "$SINK" ]] && [[ $SINK =~ "bluez_sink" ]]; then
        # Extract device MAC from sink name (e.g. bluez_sink.F4_2B_7D_27_C8_57.a2dp_sink -> F4_2B_7D_27_C8_57)
        DEVICE_MAC=$(echo "$SINK" | sed 's/bluez_sink\.\([^.]*\).*/\1/')
        # Check if this device also has a source (= phone/laptop, not a speaker)
        MATCHING_SOURCE=$(pactl list sources short | grep "bluez_source\.$DEVICE_MAC")
        if [[ -z "$MATCHING_SOURCE" ]]; then
          echo "New Bluetooth speaker detected: $SINK"
          for INPUT in $(pactl list sink-inputs short | awk '{ print $1 }'); do
            echo "Moving sink-input $INPUT to $SINK"
            pactl move-sink-input "$INPUT" "$SINK"
          done
          pactl set-default-sink "$SINK"
          echo "Set default sink to $SINK"
        else
          echo "Skipping sink $SINK — device also has a source (phone/laptop, not a speaker)"
        fi
      fi
    fi

    if [ $event == "'new'" -a $type == 'source' ]; then
      echo "event: $event, type: $type, num: $num"
      # Remove leading hashmark
      SOURCE_NUM=${num:1}
      echo "Got source num: $SOURCE_NUM"
      SOURCE=$(pactl list sources short | grep -e "^$SOURCE_NUM\s" | awk '{ print $2 }')
      echo "Got source from num: $SOURCE"
      SOURCE_ALT=$(pactl list short sources | grep bluez_source | awk '{ print $2 }')
      echo "Alt source: $SOURCE_ALT"
      if [[ ! -z "$SOURCE" ]]; then
        if [[ $SOURCE =~ "bluez_source" ]]; then
          pactl unload-module module-loopack
          echo "unloaded module-loopback"
          echo "Loading bluetooth loopback to fifo with input latency of 500ms"
          echo "source: $SOURCE, sink: BluetoothFifo"
          pactl load-module module-loopback latency_msec=500 format=s16le rate=44100 channels=2 source=$SOURCE sink=BluetoothFifo source_dont_move=true sink_dont_move=true
          retval=$?
          echo "module-loopback loaded"
          pactl list modules short | grep module-loopback
          if [ $retval -ne 0 ]; then
            echo "FAILURE: running 'pactl list modules short'"
            # start subscription again on failure. it seems to get stuck
          fi
        else
          echo "skipping: source is not bluetooth"
          echo "BAD SOURCE: $SOURCE"
        fi
      else
        echo "skipping: empty source"
      fi
    fi

    ## Hack to continuously monitor for automatically added loopbacks that go straight to ALSA and remove
    ## @TODO: Figure out why loopback getting added automatically
    # GOOD_LOOPBACK=$(pactl list modules short | grep module-loopback | grep BluetootFifo | head -n 1)
    # if [[ ! -z "$GOOD_LOOPBACK" ]]; then
    #   # Don't unload bad loopback unless good loopback found
    #   BAD_LOOPBACK=$(pactl list modules short | grep module-loopback | grep media.role | head -n 1)
    #   BAD_LOOPBACK_NUM=$(echo $BAD_LOOPBACK | awk '{ print $1 }')
    #   if [[ ! -z "$BAD_LOOPBACK_NUM" ]] ; then
    #     echo "Found bad loopback, unloading"
    #     echo $BAD_LOOPBACK
    #     pactl unload-module $BAD_LOOPBACK_NUM
    #     echo "bad loopback unloaded"
    #     pactl list modules short | grep module-loopback
    #   fi
    # fi
  done
  # done < <(pactl subscribe)
done
