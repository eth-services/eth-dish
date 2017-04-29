d3 = require 'd3'
KefirBus = require 'kefir-bus'

somata = require 'somata-socketio-client'

React = require 'react'
ReactDOM = require 'react-dom'

color = d3.scaleOrdinal(d3.schemeCategory20)

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

tickState = ({nodes, links}) ->
    console.log network
    _nodes = network.nodes.slice()
    _links = network.links.slice()
    # links.map (l) ->
    #     console.log 'link', l
    return {nodes: _nodes, links: _links}

pushTransaction = (tx, network) ->
    {from, to, hash, value, contractAddress, blockHash} = tx
    if !node_ids[blockHash]?
        network.nodes.push {id: blockHash, type: 'blocks', group: groups.blocks, value: 25}
        node_ids[blockHash] = blockHash
    if !node_ids[from]?
        network.nodes.push {id: from, type: 'accounts', group: groups.accounts, value: 10}
        node_ids[from] = from

    network.nodes.push {id: hash, type: 'transactions', group: groups.transactions, value: 10}
    node_ids[hash] = hash

    if to?
        if !node_ids[to]?
            network.nodes.push {id: to, type: 'accounts', group: groups.accounts, value: 10}
            node_ids[to] = to
        network.links.push {source: hash, target: to, value}
    else
        if !node_ids[contractAddress]
            network.nodes.push {id: contractAddress, type: 'contracts', group: groups.contracts, value: 10}
        network.links.push {source: hash, target: to: contractAddress, value}

    network.links.push {source: from, target: hash, value}
    network.links.push {source: hash, target: blockHash, value: 4}

simulation = {}

doSimulation = (network) ->
    console.log network
    network = JSON.parse JSON.stringify network
    svg = d3.select("svg")
    width = +svg.attr("width")
    height = +svg.attr("height")
    dragstarted = (d) ->
        if !d3.event.active
            simulation.alphaTarget(0.13).restart()
        d.fx = d.x
        d.fy = d.y

    dragged = (d) ->
        d.fx = d3.event.x
        d.fy = d3.event.y

    dragended = (d) ->
        if !d3.event.active
            simulation.alphaTarget(0)
        d.fx = null
        d.fy = null

    clicked = (d) ->
        console.log 'Clicked', d
        Dispatcher.clicks$.nodes.emit d

    simulation = d3.forceSimulation()
        .force("link", d3.forceLink().id((d) -> return d.id))
        .force("charge", d3.forceManyBody(12))
        .force("center", d3.forceCenter(width / 2, height / 2))
    svg = d3.select("svg")
    link = svg.append("g")
            .attr("class", "links")
        .selectAll("line")
        .data(network.links)
        .enter().append("line")
        .attr("stroke","#d3d3d3")
        .attr("stroke-width", (d) -> 2 + Math.pow(d.value / 1000000000000, 1/8))

    node = svg.append("g")
            .attr("class", "nodes")
        .selectAll("circle")
        .data(network.nodes)
        .enter().append("circle")
        .attr("r", (d) -> 4 + Math.sqrt(d.value))
        .attr('cx', (d) -> d.x)
        .attr('cy', (d) -> d.y)
        .attr("fill", (d) -> color(d.group))
        .on("click", clicked)
        .call(d3.drag()
            .on("start", dragstarted)
            .on("drag", dragged)
            .on("end", dragended))

    ticked = ->
        link
            .attr("x1", (d) -> d.source.x)
            .attr("y1", (d) -> d.source.y)
            .attr("x2", (d) -> d.target.x)
            .attr("y2", (d) -> d.target.y)

        node
            .attr("cx", (d) -> d.x)
            .attr("cy", (d) -> d.y)

    node.append("title")
        .text((d) -> d.type + ': ' + d.id)
        .attr("stroke","#333")
        .attr("fill","#333")

    simulation
        .nodes(network.nodes)
        .on("tick", ticked)

    simulation.force("link")
        .links(network.links)

    reloadSimulation = (network) ->
        node = node.data(network.nodes, (d) -> d.id)
        node.exit().remove()
        nodeEnter = node.enter().append("circle")
            .attr("r", (d) -> 4 + Math.sqrt(d.value))
            .attr('cx', (d) -> d.x)
            .attr('cy', (d) -> d.y)
            .attr("fill", (d) -> color(d.group))
            .call(d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended))

        node = nodeEnter.merge(node)
        link = link.data(network.links.filter((l) -> l.source?), (d) ->
            return d.source.id + "-" + d.target.id)
        link.exit().remove()
        link = link.enter().append("line")
            .attr("stroke","#d3d3d3")
            .attr("stroke-width", (d) -> 2 + Math.pow(d.value / 1000000000000, 1/8)).merge(link)

        simulation.nodes(network.nodes)
        simulation.force('link').links(network.links)#.linkDistance(50)
        simulation.alphaTarget(0.3).restart()


    somata.subscribe 'eth-mirror:events', 'blocks', (event) ->
        console.log 'new block:', event
        Dispatcher.blocks$.emit event
        network.nodes.push {id: event.hash, type: 'blocks', group: groups.blocks, value: 10, x: height / 2, y: width / 2}
        reloadSimulation(network)

    somata.subscribe 'eth-mirror:events', 'transactions', (event) ->
        console.log 'new transaction:', event
        pushTransaction event, network
        reloadSimulation(network)

    somata.subscribe 'eth-mirror:events', 'events', (event) ->
        console.log 'new event:', event
        event_id = "events:#{event.transactionHash}:#{event.logIndex}"
        if !node_ids[event.transactionHash]
            network.nodes.push {id: event.transactionHash, type: 'transactions', group: groups.transactions, value: 10}
            node_ids[hash] = hash
        network.nodes.push {id: event_id, type: 'events', group: groups.events, value: 10}
        network.links.push {source: event_id, target: event.transactionHash, value: 4}
        reloadSimulation(network)

App = React.createClass
    getInitialState: ->
        nodes: []
        links: []
        transactions: []

    componentDidMount: ->
        @subscribeBlocks()
        @subscribeClicks()
        Dispatcher.find 'transactions', {}, (err, transactions) =>
            transactions.items.map (t) =>
                pushTransaction t, network
                @setState {transactions}
            doSimulation(network)

    subscribeBlocks: ->
        Dispatcher.blocks$.onValue @handleNewBlock

    subscribeClicks: ->
        Dispatcher.clicks$.nodes.onValue @handleClick

    handleClick: (d) ->
        # @setState clicked_node: d

    handleNewBlock: (block) ->
        console.log block
        @setState block_number: block.number

    startSimulation: ->
        ticked = =>
            @setState tickState
        # need to do this inside of state ?

        #     link
        #         .attr("x1", (d) -> d.source.x)
        #         .attr("y1", (d) -> d.source.y)
        #         .attr("x2", (d) -> d.target.x)
        #         .attr("y2", (d) -> d.target.y)

        #     node
        #         .attr("cx", (d) -> d.x)
        #         .attr("cy", (d) -> d.y)
        # ...
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
                            <div className='swatch' style={"backgroundColor": color(groups[g_k])} />
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

Transaction = ({from, to, value, contractAddress}) ->

Block = ({transactions, hash, number}) ->

ReactDOM.render <App />, document.getElementById 'app'
