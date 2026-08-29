set +e

## Unload any existing loopbacks into BluetoothFifo so duplicates never stack.
## Only loopbacks targeting our fifo are touched -- any other loopback is left
## alone.
unload_fifo_loopbacks() {
  for MOD in $(pactl list modules short | grep module-loopback | grep "sink=BluetoothFifo" | awk '{ print $1 }'); do
    echo "Unloading existing BluetoothFifo loopback module #$MOD"
    pactl unload-module "$MOD"
  done
}

## At boot a phone can connect (creating the bluez source) seconds before
## module-pipe-sink has created BluetoothFifo; loading the loopback then fails
## with "Module initialization failed" and audio never flows.
wait_for_fifo_sink() {
  for _ in $(seq 1 30); do
    if pactl list sinks short | awk '{ print $2 }' | grep -qx "BluetoothFifo"; then
      return 0
    fi
    echo "Waiting for BluetoothFifo sink to appear..."
    sleep 1
  done
  return 1
}

load_bluetooth_loopback() {
  SOURCE=$1
  unload_fifo_loopbacks
  if ! wait_for_fifo_sink; then
    echo "FAILURE: BluetoothFifo sink never appeared; cannot load loopback"
    return 1
  fi
  echo "Loading bluetooth loopback to fifo with input latency of 500ms"
  echo "source: $SOURCE, sink: BluetoothFifo"
  for _ in $(seq 1 3); do
    if pactl load-module module-loopback latency_msec=500 format=s16le rate=44100 channels=2 source=$SOURCE sink=BluetoothFifo source_dont_move=true sink_dont_move=true; then
      echo "module-loopback loaded"
      pactl list modules short | grep module-loopback
      return 0
    fi
    echo "module-loopback failed to load, retrying..."
    sleep 2
  done
  echo "FAILURE: could not load module-loopback for source $SOURCE"
  return 1
}

## module-bluetooth-policy runs with a2dp_source=false / auto_switch=false, so
## when a phone (re)connects nothing switches its card away from the "off"
## profile. Without the a2dp_source profile no bluez source is created, the
## "new source" handler below never fires, and no audio flows. Force the
## profile ourselves. Speakers are unaffected: only devices that can send us
## audio (phones, laptops) expose an a2dp_source profile.
activate_a2dp_source() {
  CARD_NUM=$1
  CARD=$(pactl list cards short | grep -e "^$CARD_NUM\s" | awk '{ print $2 }')
  if [[ -z "$CARD" ]] || [[ ! $CARD =~ "bluez_card" ]]; then
    return 0
  fi
  ## Retry: right after connecting, bluez may not have the AVDTP endpoint
  ## ready yet and the profile switch can fail transiently.
  for _ in $(seq 1 5); do
    CARD_SECTION=$(pactl list cards | sed -n "/^Card #$CARD_NUM\$/,/^Card #[0-9]/p")
    if ! echo "$CARD_SECTION" | grep -q "a2dp_source"; then
      echo "Card $CARD has no a2dp_source profile (speaker?), leaving it alone"
      return 0
    fi
    ACTIVE_PROFILE=$(echo "$CARD_SECTION" | grep "Active Profile:" | awk '{ print $3 }')
    if [[ "$ACTIVE_PROFILE" == "a2dp_source" ]]; then
      echo "Card $CARD already on a2dp_source"
      return 0
    fi
    echo "Card $CARD active profile is '$ACTIVE_PROFILE', switching to a2dp_source"
    if pactl set-card-profile "$CARD" a2dp_source; then
      echo "Card $CARD switched to a2dp_source"
      return 0
    fi
    echo "Failed to set a2dp_source on $CARD, retrying..."
    sleep 2
  done
  echo "FAILURE: could not switch $CARD to a2dp_source"
  return 1
}

## new_source is used to make sure loopback is only ever reloaded once
while [ true ]; do
  echo "pactl subscribe"
  pactl subscribe | while read x event y type num; do
    # if [ $type != 'client' ]; then
    #   echo "event: $event, type: $type, num: $num"
    # fi
    # When a Bluetooth device that can send us audio (phone/laptop) connects,
    # make sure its card is on the a2dp_source profile so a source appears.
    if [ $event == "'new'" -a $type == 'card' ]; then
      activate_a2dp_source ${num:1}
    fi

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
          load_bluetooth_loopback $SOURCE
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
