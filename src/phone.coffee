EventEmitter = require('events').EventEmitter
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
          @responseBuffer.shift().callback?(res,cmd)
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
    clearInterval(@_pollID) if @_pollID and !!!stop
    @_pollID = setInterval @ping, 2000 unless !!stop or @_pollID

  ping: () =>

    @send('', () -> console.log('i am alive!') )

  send: (request, callback) =>
    if @isOpen
      queueLength = @responseBuffer.length
      request = 'AT'+request
      @responseBuffer.push {request, callback}
      setTimeout (() =>
        @port.write(request+'\r')
        ), queueLength*100
    else
      callback?(null,"phone not connected")
      "phone not connected"


# just for debug
device = process.argv[2]
phone = new Phone(device)
phone.on('AT', (response) -> console.log "AT was "+response)
phone.on('unsolicited', (code, response) ->
  console.log "Got notice for "+code+"\n\twith message:\t"+response)
setTimeout (() ->
  console.log "ping!"
  phone.ping()
  phone.send('E1', () -> console.log("echo mode set to 1"))
  phone.send('&V', (r,c) -> console.log(arguments))
  phone.send('+CPIN=?', (r,c) -> console.log(arguments))
  phone.send('+EXUNSOL="SQ,",2', (r,c) -> console.log(arguments)) # turn on signal results
  phone.send('+CREG=?', (r,c) -> console.log(arguments))
  phone.send('+TEST', (r,c) -> console.log(arguments)) # ERROR
  phone.send('+CNUM', (r,c) -> console.log(arguments)) # number reponse
  phone.send('+CPIN=', (r,c) -> console.log(arguments)) # +CME ERROR
  phone.send('+CLTS=1', (r,c) -> console.log('Requested timestamp: "'+r+'"')) 
  phone.send('+CCLK?', (r,c) -> console.log('Clock: "'+r+'"')) 

  phone.poll()
  # setTimeout (()->phone.poll(false)), 60000
  ), 5000

