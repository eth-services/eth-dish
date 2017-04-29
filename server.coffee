polar = require 'polar'
polar = require 'somata-socketio'

config = {
    port: 3826
}

app = polar config

app.get '/', (req, res) ->
    res.render 'base'

app.start()
