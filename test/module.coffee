require 'coffee-script'
require '../src/mixin'

class EventEmitter extends require('events').EventEmitter
  constructor: -> @on('asdkjhasd',()->console.log("lkajsd"))

console.log EventEmitter

class Test
  @mixin require('events').EventEmitter
  constructor: ->
    console.log "bla"

console.log Test

t = new Test()

console.log t

t.on 'stuff', () -> console.log "stuff"
t.emit('stuff')