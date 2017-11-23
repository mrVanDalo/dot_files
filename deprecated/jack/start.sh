#!/bin/bash
#
#
#     $$$$$\                     $$\        $$$$$$\        
#     \__$$ |                    $$ |      $$  __$$\       
#        $$ | $$$$$$\   $$$$$$$\ $$ |  $$\ \__/  $$ |      
#        $$ | \____$$\ $$  _____|$$ | $$  | $$$$$$  |      
#  $$\   $$ | $$$$$$$ |$$ /      $$$$$$  / $$  ____/       
#  $$ |  $$ |$$  __$$ |$$ |      $$  _$$<  $$ |            
#  \$$$$$$  |\$$$$$$$ |\$$$$$$$\ $$ | \$$\ $$$$$$$$\       
#   \______/  \_______| \_______|\__|  \__|\________|      
#                                                          
#                                                          
#


setup_dummy(){
    jack_control ds dummy 
}

setup_komplete(){

    # device parameter configuration
    # ==============================
    #
    # to find configuration options do
    # jack_control dp
    jack_control ds alsa
    jack_control dps device hw:${device_number}  # use usb card
    jack_control dps duplex True  # record and playback ports
    jack_control dps rate 48000   # use cd sample rate
    jack_control dps hwmon False  # no hardware monitoring

    # nperiods are the splitup of the 
    # sound-ring-buffer. 2 are ok for internal cards
    # but for usb you should use 3 because 
    # you can have to write in junks to the card
    # so there is one backup slice in the middle 
    jack_control dps nperiods 3   


    # engine parameter configuration
    # ==============================
    #
    # to find configuration options do
    # jack_control ep

    #jack_control eps name awesome       # name of the jackserver 
    jack_control eps sync True

    # realtime kernel 
    # set True for using a realtime kernel
    jack_control eps realtime True
    # set priority if realtime kernel is set True
    jack_control eps realtime-priority 10

}

internal_device_number=0
komplete_device_number=`aplay -l | grep Vestax | cut -d":" -f1 | cut -d" " -f2`
babyface_device_number=`aplay -l | grep Babyface | cut -d":" -f1 | cut -d" " -f2`
h2n_device_number=`aplay -l | grep H2n | cut -d":" -f1 | cut -d" " -f2`

# this should be more readable some day
if [[ $babyface_device_number == "" ]]; then
    if [[ $komplete_device_number == "" ]]; then
        if [[ $h2n_device_number == "" ]]; then 
            device_number=$internal_device_number
        else 
            device_number=$h2n_device_number
        fi
    else
        device_number=$komplete_device_number
    fi
else
    device_number=$babyface_device_number
fi
setup_komplete

# start the jack monster :D
# -------------------------
jack_control start
