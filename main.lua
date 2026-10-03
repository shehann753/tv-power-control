-- ===================================================================
-- Air780E LuatOS - TV Power Control via HiveMQ Cloud
-- ===================================================================

PROJECT           = "Air780E_TV_Control"
VERSION           = "1.0.0"

sys               = require("sys")

-- -------------------------------------------------------------------
-- HiveMQ Cloud Credentials & Endpoint
-- -------------------------------------------------------------------
local MQTT_HOST   = "limesweat-343b2053.a01.euc1.aws.hivemq.cloud"
local MQTT_PORT   = 8883              -- Secure MQTTS Port
local MQTT_IS_SSL = true              -- Required for HiveMQ Cloud TLS

local USERNAME    = "tv_admin"        -- Replace with Access Management Username
local PASSWORD    = "5mzRLDYj22fWKiD" -- Replace with Access Management Password
local CLIENT_ID   = "Air780E_" .. (mobile.imei() or "000000000000000")

local TOPIC_CTRL  = "home/tv/power"
local RELAY_PIN   = 1 -- Default Relay GPIO Pin on AIR780E modules

-- -------------------------------------------------------------------
-- Hardware Initialization
-- -------------------------------------------------------------------
gpio.setup(RELAY_PIN, 0) -- Initialize pin LOW (Default power state)

-- -------------------------------------------------------------------
-- Main Application Task
-- -------------------------------------------------------------------
sys.taskInit(function()
    log.info("LTE", "Waiting for 4G cellular network connection...")
    sys.waitUntil("IP_READY")
    log.info("LTE", "4G Connected! IP address acquired.")

    -- 1. Create MQTT Client Instance with TLS enabled
    local mqttc = mqtt.create(nil, MQTT_HOST, MQTT_PORT, MQTT_IS_SSL)
    if not mqttc then
        log.error("MQTT", "Failed to initialize MQTT instance")
        return
    end

    -- 2. Configure Authentication & Reconnect Policy
    mqttc:auth(CLIENT_ID, USERNAME, PASSWORD)
    mqttc:keepalive(60)
    mqttc:autoreconn(true, 3000)

    -- 3. Set Event Callbacks
    mqttc:on(function(client, event, data, payload)
        if event == "conack" then
            log.info("MQTT", "Successfully authenticated & connected to HiveMQ Cloud!")
            client:subscribe(TOPIC_CTRL)
        elseif event == "recv" then
            log.info("MQTT RX", "Topic: " .. tostring(data) .. " | Payload: " .. tostring(payload))

            if payload == "OFF" or payload == "0" then
                gpio.set(RELAY_PIN, 1) -- Set GPIO HIGH -> Trigger Relay -> Cut TV Power
                log.info("RELAY", "Relay Energized -> TV Power CUT")
            elseif payload == "ON" or payload == "1" then
                gpio.set(RELAY_PIN, 0) -- Set GPIO LOW -> Release Relay -> Restore TV Power
                log.info("RELAY", "Relay Released -> TV Power RESTORED")
            end
        elseif event == "disconnect" then
            log.warn("MQTT", "Disconnected from HiveMQ Cloud broker")
        elseif event == "error" then
            log.error("MQTT Error", tostring(data))
        end
    end)

    -- 4. Initiate Connection
    mqttc:connect()

    -- Keep task alive
    while true do
        sys.wait(10000)
    end
end)

sys.run()
