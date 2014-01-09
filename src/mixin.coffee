Object.prototype.mixin = (Klass) ->
  # assign class properties
  for key, value of Klass
    @[key] = value
 
  # assign instance properties
  for key, value of Klass.prototype
    @::[key] = value
  @
