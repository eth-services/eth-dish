d3 = require 'd3'

Dish = class Dish

    constructor: (@network, @emitter, @color) ->
        console.log '[Dish] Created a new dish', @network

    link_ids: []
    node_ids: []
    started: false

    startSimulation: ->
        @network = JSON.parse JSON.stringify @network
        svg = d3.select("svg")
        @width = +svg.attr("width")
        @height = +svg.attr("height")

        @simulation = d3.forceSimulation()
            .force("link", d3.forceLink().id((d) -> return d.id))
            .force("charge", d3.forceManyBody(1))
            .force("center", d3.forceCenter(@width / 2, @height / 2))

        @dragstarted = dragstarted = (d) =>
            if !d3.event.active
                @simulation.alphaTarget(0.13).restart()
            d.fx = d.x
            d.fy = d.y

        @dragged = dragged = (d) ->
            d.fx = d3.event.x
            d.fy = d3.event.y

        @dragended = dragended = (d) =>
            if !d3.event.active
                @simulation.alphaTarget(0)
            d.fx = null
            d.fy = null

        @clicked = clicked = (d) =>
            console.log 'Clicked', d
            @emitter?.nodes.emit d

        @svg = d3.select("svg")
        @link = svg.append("g")
                .attr("class", "links")
            .selectAll("line")
            .data(@network.links)
            .enter().append("line")
            .attr("stroke","#d3d3d3")
            .attr("stroke-width", (d) -> 2 + Math.pow(d.value / 1000000000000, 1/8))

        @node = svg.append("g")
                .attr("class", "nodes")
            .selectAll("circle")
            .data(@network.nodes)
            .enter().append("circle")
            .attr("r", (d) -> 4 + Math.sqrt(d.value))
            .attr('cx', (d) -> d.x)
            .attr('cy', (d) -> d.y)
            .attr("fill", (d) => @color(d.type))
            .on("click", clicked)
            .call(d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended))

        ticked = =>
            @link
                .attr("x1", (d) -> d.source.x)
                .attr("y1", (d) -> d.source.y)
                .attr("x2", (d) -> d.target.x)
                .attr("y2", (d) -> d.target.y)

            @node
                .attr("cx", (d) -> d.x)
                .attr("cy", (d) -> d.y)

        @node.append("title")
            .text((d) -> d.type + ': ' + d.id)
            .attr("stroke","#333")
            .attr("fill","#333")

        @simulation
            .nodes(@network.nodes)
            .on("tick", ticked)

        @simulation.force("link")
            .links(@network.links)

        @started = true

    pushEntities: ({nodes, links}) ->
        x = @height / 2
        y = @width / 2
        if nodes?.length
            nodes.map (node) =>
                @node_ids.push node.id
                @network.nodes.push Object.assign {}, node, {x, y}
        if links?.length
            links.map (link) =>
                @link_ids.push link.id
                @network.links.push Object.assign {}, link, {x, y}
        if @started
            @reloadSimulation()

    reloadSimulation: ->
        {dragstarted, dragended, dragged} = @
        @node = @node.data(@network.nodes, (d) -> d.id)
        @node.exit().remove()
        nodeEnter = @node.enter().append("circle")
            .attr("r", (d) -> 4 + Math.sqrt(d.value))
            .attr('cx', (d) -> d.x)
            .attr('cy', (d) -> d.y)
            .attr("fill", (d) => @color(d.type))
            .call(d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended))

        @node = nodeEnter.merge(@node)
        @link = @link.data(@network.links.filter((l) -> l.source?), (d) ->
            return d.source.id + "-" + d.target.id)
        @link.exit().remove()
        @link = @link.enter().append("line")
            .attr("stroke","#d3d3d3")
            .attr("stroke-width", (d) -> 2 + Math.pow(d.value / 1000000000000, 1/8)).merge(@link)

        @simulation.nodes(@network.nodes)
        @simulation.force('link').links(@network.links)#.linkDistance(50)
        @simulation.alphaTarget(0.3).restart()

module.exports = Dish