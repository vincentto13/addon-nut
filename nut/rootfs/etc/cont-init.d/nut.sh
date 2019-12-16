#!/usr/bin/with-contenv bashio
# ==============================================================================
# Community Hass.io Add-ons: Network UPS Tools
# Configures Network UPS Tools
# ==============================================================================
readonly USERS_CONF=/etc/nut/upsd.users
declare upsmonpwd
declare nutmode
declare shutdowncmd
declare username
declare password

# Fix permissions
chmod -R 660 /etc/nut/*
chown -R root:nut /etc/nut/*

nutmode=$(bashio::config 'mode')
bashio::log.info "Setting mode to ${nutmode}..."
sed -i "s#%%nutmode%%#${nutmode}#g" /etc/nut/nut.conf

if bashio::config.equals 'mode' 'netserver' ;then

    bashio::log.info "Generating ${USERS_CONF}..."
    # Create Monitor User
    upsmonpwd=$(shuf -ze -n20  {A..Z} {a..z} {0..9}|tr -d '\0')

        {
            echo
            echo "[upsmonmaster]"
            echo "  password = ${upsmonpwd}"
            echo "  upsmon master"
        } >> "${USERS_CONF}"

    for user in $(bashio::config "users|keys"); do

        bashio::config.require.username "users[${user}].username"
        username=$(bashio::config "users[${user}].username")

        bashio::log.info "Configuring user: ${username}"
        if ! bashio::config.true 'i_like_to_be_pwned'; then
            bashio::config.require.safe_password "users[${user}].password"
        else
            bashio::config.require.password "users[${user}].password"
        fi
        password=$(bashio::config "users[${user}].password")

        {
            echo
            echo "[${username}]"
            echo "  password = ${password}"
        } >> "${USERS_CONF}"

        for instcmd in $(bashio::config "users[${user}].instcmds"); do
            echo "  instcmds = ${instcmd}" >> "${USERS_CONF}"
        done

        for action in $(bashio::config "users[${user}].actions"); do
            echo "  actions = ${action}" >> "${USERS_CONF}"
        done

        if bashio::config.has_value "users[${user}].upsmon"; then
            upsmon=$(bashio::config "users[${user}].upsmon")
            echo "  upsmon ${upsmon}" >> "${USERS_CONF}"
        fi
    done

    for device in $(bashio::config "devices|keys"); do

        upsname=$(bashio::config "devices[${device}].name")
        upsdriver=$(bashio::config "devices[${device}].driver")
        upsport=$(bashio::config "devices[${device}].port")
        bashio::log.info "Configuring Device named ${upsname}..."
            {
                echo
                echo "[${upsname}]"
                echo "  driver = ${upsdriver}"
                echo "  port = ${upsport}"
            } >> /etc/nut/ups.conf
        
        for configitem in $(bashio::config "devices[${device}].config"); do
            echo "  ${configitem}" >> /etc/nut/ups.conf
        done

        echo "MONITOR ${upsname}@localhost 1 upsmonmaster ${upsmonpwd} master" \
            >> /etc/nut/upsmon.conf

    done
    bashio::log.info "Starting the UPS drivers..."
    # Run upsdrvctl
    if bashio::debug; then
        upsdrvctl -D start
    else
        upsdrvctl start
    fi

fi

shutdowncmd="halt"
if bashio::config.true 'shutdown_hassio'; then
    bashio::log.warning "UPS Shutdown will shutdown Hassio"
    shutdowncmd="/usr/bin/shutdownhassio"
fi

echo "SHUTDOWNCMD  ${shutdowncmd}" >> /etc/nut/upsmon.conf