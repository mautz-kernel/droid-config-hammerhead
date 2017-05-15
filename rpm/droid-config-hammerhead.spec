# These and other macros are documented in ../droid-configs-device/droid-configs.inc

%define device hammerhead
%define vendor lge

%define vendor_pretty LG
%define device_pretty Nexus 5

%define dcd_path ./

# Adjust this for your device
%define pixel_ratio 2.0

# We assume most devices will
%define have_modem 1

# Community HW adaptations need this
%define community_adaptation 1

Provides: ofono-configs
%include droid-configs-device/droid-configs.inc



