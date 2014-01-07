###
  Staalplaat Phone Server
  -----------------------
  Connect a GSM/AT modem via osc
  * TODO: automated call control
  * TODO: SIM PIN call procedure
  * TODO: Forward signal information
###
BROADCAST = '255.255.255.255'
PORT = 57441
PING_TIME = 5


OscEmitter = require('osc-emitter')
dtmfin = require 'node-dtmfin'

osc = new OscEmitter();

# Prepare
osc.add BROADCAST, PORT
osc._socket.bind()

ping_interval = null
startPing = (osc) ->
  ping_interval = setInterval (() -> osc.emit '/staal/phone/ping'), PING_TIME*1000

stopPing = () ->
  clearInterval ping_interval

audio_devices = dtmfin.list()

# exit abnormally, when no audio devices are present
process.exit -1 if audio_devices.length == 0

setTimeout (() ->
  osc._socket.setBroadcast(true)
  startPing(osc)
  try
    info = dtmfin.open 0, (code) ->
      osc.emit '/staal/phone/key', code
  catch e
    console.error "Failed to open audio device. Exiting"
  ), 1000
