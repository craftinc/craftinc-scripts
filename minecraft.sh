#!/bin/bash

SERVICE='craftbukkit.jar'

# numbers of CPU cores; used only for the parallel garbage collector threads
CPU_COUNT=8

# maximum memory which the JAVA VM is allowed to allocate (M is megabyte)
XMX=-Xmx10000M

# initial memory which the JAVA VM is allocating (M is megabyte)
XMS=-Xms3000M

# Replace with path which contains your craftbukkit.jar
MCPATH='/my/path/to/craftbukkit'



# ========================================================================
# == Don't change anything below this line unless you know what you do. ==
# ========================================================================
BUKKIT="$MCPATH/$SERVICE"
INVOCATION="java $XMX $XMS -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts -jar $BUKKIT nogui"

if [[ "$MCPATH" == '/my/path/to/craftbukkit' ]]; then
    echo "Please configure the \"MCPATH\" variable in the $0 file." >&2
    exit 1
fi

SCREEN_NAME="$(cat "$MCPATH/screen_name" 2> /dev/null)"
if [[ -z "$SCREEN_NAME" ]]; then
    SCREEN_NAME="minecraft.$(head -c12 /dev/urandom | xxd -p)"
    echo -n "$SCREEN_NAME" > "$MCPATH/screen_name"
fi

ME=$(whoami)

psgrep() {
    psgreptmp=$(mktemp)

    ps auxww > "$psgreptmp"
    grep -v "$$" "$psgreptmp" | egrep --color=auto -i "$1"
    rm "$psgreptmp"
}

send_to_screen() {
    screen -p 0 -S "$SCREEN_NAME" -X stuff "$1"
}

mc_service_running() {
    psgrep "$SERVICE" | grep -v -i 'screen' | grep 'java' | grep -- "$XMX" | grep -- "$XMS" | grep "$BUKKIT" > /dev/null
    return $?
}

mc_start() {
    if ! mc_status; then
        echo "Starting..."
        cd "$MCPATH"
        screen -dmS "$SCREEN_NAME" $INVOCATION
        sleep 2
        mc_status
    fi
}

mc_stop() {
    if mc_status; then
        echo "Sending message to users..."
        send_to_screen 'say SERVER SHUTTING DOWN IN 10 SECONDS!'
        sleep 10
        echo "Saving..."
        send_to_screen 'save-all'
        sleep 2
        echo "Stopping..."
        send_to_screen 'stop'
        sleep 6
        mc_status
    fi

}

mc_save() {
    if mc_status; then
        echo "Saving..."
        send_to_screen 'save-all'
    fi
}

mc_reload() {
    if mc_status; then
        echo "Reloading..."
        send_to_screen 'reload'
        echo "DONE"
    fi
}

mc_reset_permissions() {
    if mc_status; then
        echo "Unbanning ddidderr..."
        send_to_screen 'pardon ddidderr'
        echo "Unbanning mice_on_drugs..."
        send_to_screen 'pardon mice_on_drugs'
        echo "Unbanning Mochaccino..."
        send_to_screen 'pardon Mochaccino'

        echo "ddidder -> admin"
        send_to_screen 'pex user ddidderr group set admin'
        echo "mice_on_drugs -> mod"
        send_to_screen 'pex user mice_on_drugs group set mod'
        echo "Mochaccino -> mod"
        send_to_screen 'pex user Mochaccino group set mod'

        echo "Reloading permissions..."
        send_to_screen 'pex reload'
        echo "DONE"
    fi
}

mc_custom_command() {
    if mc_status; then
        if [[ -z "$1" ]]; then
            echo "You must specify a command." >&2
            exit 1
        fi

        echo "Trying to issue command: \"$1\""
        send_to_screen "$1"
        tail -fn50 "$MCPATH/logs/latest.log"
    fi
}

mc_status() {
    if mc_service_running; then
        echo "$SERVICE is running."
        return 0
    else
        echo "$SERVICE is stopped."
        return 1
    fi
}

mc_online() {
    if mc_status; then
        send_to_screen 'list'
        sleep 2s
        tac "$MCPATH/logs/latest.log" | egrep -om 1 "There are.*players online"
    fi
}

case "$1" in
    start)
        mc_start
        ;;
    stop)
        mc_stop
        ;;
    restart)
        $0 stop
        sleep 10
        $0 start
        ;;
    reload)
        mc_reload
        ;;
    reset_permissions)
        mc_reset_permissions
        ;;
    custom)
        mc_custom_command "${*:2}"
        ;;
    online)
        mc_online
        ;;
    status)
        mc_status
        ;;
    save)
        mc_save
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|save|online|status|reset_permissions}"
        exit 1
        ;;
esac
