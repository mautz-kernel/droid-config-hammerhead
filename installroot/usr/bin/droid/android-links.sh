#!/usr/bin/env bash

MNT=$(grep "Where=" /lib/systemd/system/android.mount | cut -d'=' -f 2)/media/0

#fix a stupid mistake in previous versions
if [ "$(readlink -- /home/nemo/Pictures/Android)" = "/android/Pictures" ]; then
  for i in Music Pictures Playlists Downloads Videos; do
    unlink /home/nemo/$i/Android 
  done
  unlink /home/nemo/Music/AndroidPodcasts
  unlink /home/nemo/Pictures/Camera/Android
fi

if [ ! -h "/home/nemo/Pictures/Android" ]; then
  if [ -d $MNT/Pictures ]; then
    for i in Music Pictures Playlists; do
      ln -s $MNT/$i /home/nemo/$i/Android
    done
    ln -s $MNT/Podcasts /home/nemo/Music/AndroidPodcasts
    ln -s $MNT/DCIM /home/nemo/Pictures/Camera/Android
    ln -s $MNT/Download /home/nemo/Downloads/Android
    ln -s $MNT/Movies /home/nemo/Videos/Android
  fi
fi
