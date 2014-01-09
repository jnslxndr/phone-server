require 'coffee-script'
Modem = require('../src/at-modem').ATModem
# just for debug
device = process.argv[2]
phone = new Modem(device)
console.log phone

phone.on('AT', (response) -> console.log "AT was "+response)
phone.on('unsolicited', (code, response) ->
  console.log "Got notice for "+code+"\n\twith message:\t"+response)

phoneIsOpen = phone.open()
phoneIsOpen.then () ->
  console.log "ping!"
  phone.ping().then () -> console.log('pong')

  phone.send('E1').then(() -> console.log("echo mode set to 1"))
  phone.send('&V').then((r,c) -> console.log(arguments))
  phone.send('+CPIN=?').then((r,c) -> console.log(arguments))
  phone.send('+EXUNSOL="SQ,",2').then((r,c) -> console.log(arguments)) # turn on signal results
  phone.send('+CREG=?').then((r,c) -> console.log(arguments))
  phone.send('+TEST').then((r,c) -> console.log(arguments)) # ERROR
  phone.send('+CNUM').then((r,c) -> console.log(arguments)) # number reponse
  phone.send('+CPIN=').then((r,c) -> console.log(arguments)) # +CME ERROR
  phone.send('+CLTS=1').then((r,c) -> console.log('Requested timestamp: "'+r+'"')) 
  phone.send('+CCLK?').then((r,c) -> console.log('Clock: "'+r+'"')) 

  phone.poll().progress((state) ->
    console.log "polling... ",state
    # phone.close
    ).fail (err) ->
      console.log "polling failed! ",err
      # try reconnect!
  # setTimeout (()->phone.poll(false)), 10000
  
phoneIsOpen.fail (reason) ->
  console.error "Could not open connection to phone. reason:\t",reason

process.stdin.resume()