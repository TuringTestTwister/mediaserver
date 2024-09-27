#! /usr/bin/env nix-shell
#! nix-shell -i bash -p gst_all_1.gstreamer -p gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good

# gst-launch-1.0 -v filesrc location="/tmp/bluetooth" ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! wavenc ! tcpserversink port=4953 host=0.0.0.0
# gst-launch-1.0 -v filesrc location="/tmp/bluetooth" ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! tcpserversink port=4953 host=0.0.0.0
# cat /tmp/bluetooth | gst-launch-1.0 -vvv fdsrc ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! tcpserversink port=4953 host=0.0.0.0
cat /tmp/bluetooth | gst-launch-1.0 -vvv fdsrc ! queue ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! tcpserversink port=4953 host=0.0.0.0
