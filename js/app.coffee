d3 = require 'd3'
KefirBus = require 'kefir-bus'

somata = require 'somata-socketio-client'

React = require 'react'
ReactDOM = require 'react-dom'
Dish = require './dish-js'

d3_color = d3.scaleOrdinal(d3.schemeCategory20)
colors = (key) ->
    key = key.split('.').slice(-1)[0]
    color = d3_color(key)

DataService = somata.remote.bind null, 'eth-mirror:data'
Dispatcher = {
    find: (type, query, cb) ->
        DataService 'find', type, query, {}, cb
    blocks$: new KefirBus()
    clicks$:
        nodes: new KefirBus()
}

groups = {
    'blocks': 1
    'transactions': 2
    'accounts': 3
    'contracts': 4
    'events': 5
}

node_ids = {}
node_index = 0

network = {
    nodes: []
    links: []
}

pushTransaction = (tx, Dish) ->
    {from, to, hash, value, contractAddress, blockHash} = tx
    entities = {nodes: [], links: []}
    if !(blockHash in Dish.node_ids)
        entities.nodes.push {id: blockHash, type: 'blocks', value: 25}
    if !(from in Dish.node_ids)
        entities.nodes.push {id: from, type: 'accounts', value: 10}

    entities.nodes.push {id: hash, type: 'transactions', value: 10}

    if to?
        if !(to in Dish.node_ids)
            entities.nodes.push {id: to, type: 'accounts', value: 10}
        entities.links.push {source: hash, target: to, value}
    else
        if !(contractAddress in Dish.node_ids)
            entities.nodes.push {id: contractAddress, type: 'contracts', value: 10}
        entities.links.push {source: hash, target: to: contractAddress, value}

    entities.links.push {source: from, target: hash, value}
    entities.links.push {source: hash, target: blockHash, value: 4}

    Dish.pushEntities entities

App = React.createClass
    getInitialState: ->
        nodes: []
        links: []
        transactions: []

    componentDidMount: ->
        @subscribeBlocks()
        @subscribeClicks()
        Dispatcher.find 'transactions', {}, (err, transactions) =>

            MyDish = new Dish({nodes: [], links: []}, Dispatcher.clicks$, colors)
            transactions ||= {}
            transactions.items ||= []
            transactions.items.map (t) =>
                pushTransaction t, MyDish    
            @setState {transactions}
            # MyDish = new Dish(network, Dispatcher.clicks$, colors)
            MyDish.startSimulation()
            # doSimulation(network)

            somata.subscribe 'eth-mirror:events', 'blocks', (event) ->
                console.log 'new block:', event
                Dispatcher.blocks$.emit event
                new_entities = nodes: [{id: event.hash, type: 'blocks', value: 10}]
                if event.parentHash in MyDish.node_ids
                    new_entities.links = [{source: event.hash, target: event.parentHash, value: 10}]

                MyDish.pushEntities new_entities

            somata.subscribe 'eth-mirror:events', 'transactions', (event) ->
                console.log 'new transaction:', event
                pushTransaction event, MyDish

            somata.subscribe 'eth-mirror:events', 'events', (event) ->
                console.log 'new event:', event
                event_id = "events:#{event.transactionHash}:#{event.logIndex}"
                new_entities = {
                    nodes: [{id: event_id, type: 'events', value: 10}]
                    links: [{source: event_id, target: event.transactionHash, value: 4}]
                }
                if !(event.transactionHash in MyDish.node_ids)
                    new_entities.nodes.push {id: event.transactionHash, type: 'transactions', value: 10}

                MyDish.pushEntities new_entities

    subscribeBlocks: ->
        Dispatcher.blocks$.onValue @handleNewBlock

    subscribeClicks: ->
        Dispatcher.clicks$.nodes.onValue @handleClick

    handleClick: (d) ->
        # @setState clicked_node: d

    handleNewBlock: (block) ->
        @setState block_number: block.number

    startSimulation: ->
        ticked = =>
            @setState tickState

        @simulation = d3.forceSimulation()
            .force("link", d3.forceLink().id((d) -> return d.id))
            .force("charge", d3.forceManyBody(35))
            .force("center", d3.forceCenter(400 / 2, 400 / 2))
        @simulation
            .nodes(network.nodes)
            .on("tick", ticked)

        @simulation.force("link")
            .links(network.links)
            .linkDistance(50)

    render: ->

        <div className='hello-dish'>
            <div className='nav'>
                <h3>ethereum dish</h3>
                <div className='legend'>
                    {Object.keys(groups).map (g_k, i) ->
                        <div key=i className='legend-entry'>
                            <div className='swatch' style={"backgroundColor": colors(g_k)} />
                            <div className='legend-label'>{g_k}</div>
                        </div>
                    }
                </div>
                <div className='block-indicator'>block {@state.block_number}</div>
                <pre>{JSON.stringify @state.clicked_node}</pre>
            </div>
        </div>
                # <svg width=400 height=400 >
                #     <g className='nodes'>
                #         {@state.nodes.map (n) ->
                #             <circle fill={color(n.group)} r=5 cx=n.x cy=n.y />
                #         }
                #     </g>
                #     <g className='links'>
                #         {@state.links.map (l) ->
                #             <line stroke="#333" x1=l.source.x x2=l.target.x y1=l.source.y y2=l.target.y />
                #         }
                #     </g>
                # </svg>

# This is a hypothetical functional setState update that should keep the network
# in the react component. I don't think it plays nicely w/ the immutable network
# object in the simulation
tickState = ({nodes, links}) ->
    _nodes = network.nodes.slice()
    _links = network.links.slice()
    # links.map (l) ->
    #     console.log 'link', l
    return {nodes: _nodes, links: _links}

# Item components
Transaction = ({from, to, value, contractAddress}) ->

Block = ({transactions, hash, number}) ->

ReactDOM.render <App />, document.getElementById 'app'
