EventEmitter = require('events').EventEmitter
Q = require('q')
Serial = require('serialport')

class Phone extends EventEmitter
  @listDevices = Serial.list
  constructor: (@device,baudrate) ->
    @isOpen = false
    @responseBuffer = []
    @baudrate = baudrate || 115200
    @port = new Serial.SerialPort(device, baudrate: @baudrate)
    @port.on 'open', @_onOpen
    @port.on 'close', @_onClose

  open: () ->
    @port.open()

  _onClose: ->
    @isOpen = false
    @port.off('data',@_onData)

  _onOpen: =>
    console.log "port "+@device+" opened!"
    @responseBuffer = []
    @isOpen = true
    @port.on('data', @_onData)
  _buffer: ''
  _cmd_match: /(.+?)\r\r\n((.|[\r\n])*?(OK|ERROR.*))\r\n/g
  _onData: (data) =>
    @_buffer += data.toString('ascii')
    # {_buffer} = @
    # console.log('>>> buffer:',{_buffer})
    # console.log('>>> raw:', data)
    # console.log('>>> tostring:', data.toString())
    responses = @_buffer.match @_cmd_match
    # console.log('>>> responses:', responses)
    # console.log('>>> requrests:', @responseBuffer)
    if responses?.length > 0
      for response in responses
        [cmd,res] = response.replace(/\r\n$/,'').split(/\r\r\n/)
        if @responseBuffer?[0].request == cmd
          # TODO: ERROR or OK?
          @responseBuffer.shift().deferred?.resolve(res,cmd)
          @emit(cmd,res)
        # console.log "Response Command ", cmd
        # console.log "Response Response ", res
        @_buffer = @_buffer.replace response, ''

    unless @responseBuffer.length > 0 and @_buffer.indexOf(@responseBuffer?[0].request) >= 0
      unsolicited = @_buffer.match /\r\n(.*)\r\n/g
      if unsolicited?.length > 0
        for u in unsolicited
          [cmd,res] = u.replace(/\r\n/g, '').split(/:\s/)
          @emit('unsolicited',cmd,res)
          @_buffer = @_buffer.replace u, ''
      
  @_pollID: null
  @isAlive: false
  poll: (stop) =>
    @ping().delay(2000).then () =>
      @poll()

  ping: () =>
    @send('')
      .then( () -> console.log('i am alive!',arguments))
      .fail( () -> console.log('i am DEAD!',arguments))

  send: (request) =>
    deferred = Q.defer()
    if @isOpen
      wait = @responseBuffer.length * 100
      console.log wait
      timeout = wait + 2000
      request = 'AT'+request
      _request = {request, deferred}
      request_index = @responseBuffer.push _request
      Q.delay(wait).done () =>
        @port.write request+'\r', (err, results) ->
          deferred.notify(results)
          if err
            deferred.reject(new Error(err))
      deferred.promise = deferred.promise.timeout(timeout,"Phone not available")
      deferred.promise.finally () =>
        index = @responseBuffer.indexOf _request
        @responseBuffer.splice(index,1) if index >= 0

    else
      deferred.promise.thenReject "phone not connected"
    return deferred.promise


# just for debug
device = process.argv[2]
phone = new Phone(device)

phone.on('AT', (response) -> console.log "AT was "+response)
phone.on('unsolicited', (code, response) ->
  console.log "Got notice for "+code+"\n\twith message:\t"+response)
setTimeout (() ->
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

  phone.poll()
  # setTimeout (()->phone.poll(false)), 60000
  ), 5000

