EventEmitter = require('events').EventEmitter
Q = require('q')
Serial = require('serialport')

class Phone extends EventEmitter
  @listDevices = Serial.list
  constructor: (@device,baudrate) ->
    @isOpen = false
    @responseBuffer = []
    @baudrate = baudrate || 115200

    @port = new Serial.SerialPort(device, baudrate: @baudrate, false)

  open: () =>
    @port.on 'open', @_onOpen
    @port.on 'close', @_onClose
    promise = Q.ninvoke((cb) => @port.open(cb))
    # promise.fail (err) =>
    #   # console.log "port open failed:\t",err
    # promise.then () =>
    #   # console.log "open resolved with: \t",arguments
    return promise

  close: =>
    promise = Q.ninvoke((cb) => @port.close(cb))
    # promise.fail (err) =>
    #   # console.log "port close failed:\t",err
    # promise.then () =>
    #   # console.log "closed port with: \t",arguments
    return promise

  _onError: (err) =>
    @isOpen = false
    console.log "Serial port failed with: \t",err
    @port.removeListener('data',@_onData)

  _onClose: =>
    @isOpen = false
    @port.removeListener('data',@_onData)

  _onOpen: =>
    # console.log "port "+@device+" opened!"
    @port.on 'error', @_onError
    @responseBuffer = []
    @isOpen = true
    @port.on('data', @_onData)

  _buffer: ''
  _cmd_match: /(.+?)\r\r\n((.|[\r\n])*?(OK|ERROR.*))\r\n/g
  _onData: (data) =>
    @_buffer += data.toString()
    responses = @_buffer.match @_cmd_match
    if responses?.length > 0
      for response in responses
        [cmd,res] = response.replace(/\r\n$/,'').split(/\r\r\n/)
        if @responseBuffer?[0].request == cmd
          # TODO: ERROR or OK?
          isErr = /ERROR.*?$/.test res
          request = @responseBuffer.shift()
          if isErr
            request.deferred?.reject(res,cmd)
          else
            request.deferred?.resolve(res,cmd)
          @emit(cmd,res)
        @_buffer = @_buffer.replace response, ''

    unless @responseBuffer.length > 0 and @_buffer.indexOf(@responseBuffer?[0].request) >= 0
      unsolicited = @_buffer.match /\r\n(.*)\r\n/g
      if unsolicited?.length > 0
        for u in unsolicited
          [cmd,res] = u.replace(/\r\n/g, '').split(/:\s/)
          @emit('unsolicited',cmd,res)
          @_buffer = @_buffer.replace u, ''
      
  @isAlive: false
  @_poller: null
  @_pollID: null
  poll: (start, forever) =>
    console.log "poll ... starting? ", (not start? or start is true)
    @_poller = @_poller || Q.defer()
    if not start? or start is true
      # start the interval
      @_pollID = setInterval (() =>
        @ping().then(() =>
          @_poller.notify(true)
        ).fail(() =>
          @_poller.notify(false)
          if not forever and not @isOpen # port not available
            @_poller.reject()
            @poll(false)
        ).finally (()=>

        )
      ), 2500
    else
      # stop the interval
      clearInterval(@_pollID)
      @_pollID = null
      @_poller.resolve(true) if @_poller.isPending()
      @_poller = null

    return @_poller.promise

  ping: () =>
    sendPromise = @send('')
    sendPromise
      .then( () ->
        console.log('i am alive!',arguments)
      )
      .fail( () ->
        console.log('i am DEAD!',arguments)
      )
    sendPromise

  send: (request) =>
    deferred = Q.defer()
    if @isOpen
      wait = @responseBuffer.length * 100
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
      deferred.reject "phone not connected"
    return deferred.promise


# just for debug
device = process.argv[2]
phone = new Phone(device)

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