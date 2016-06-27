# contains the factory functions for generating the (non)-linear system as a
# vector function, and for generating the corresponding Jacobian matrix function

# sub-module for generated system/jacobian functions
module Generated

end

using DataStructures
# unfortunately, can't do this because collect() fails if either of the 
# type parameters are unions ... should file an issue for this
# typealias SymbolMap OrderedDict{Union{Node, Component}, Union{Symbol, Expr}}
# have to do this instead:
typealias SymbolMap OrderedDict{Any, Any}

# turns out this is STILL a problem - have to do this hacky thing
# you'd think this conversion would already be the case?
# necessary in julia 0.4.5 - haven't tested higher versions
Base.convert{T1<:Any, T2<:Any}(t::Type{Pair{Any, Any}}, 
    x::Pair{T1, T2}) = Pair{Any, Any}(x.first, x.second)

# generate a node => symbol map for a circuit
# also maps components with dummy currents to their dummy current symbols
function gen_sym_map(circ::Circuit)

    # order the nodes
    nodes_vec = collect(circ.nodes)
    n_nodes = length(nodes_vec)

    # us an ordered dictionary to FIRST map all the nodes, THEN the 
    # dummy current components
    sym_map = SymbolMap()
    
    for i = 1:n_nodes
        sym_map[nodes_vec[i]] = :(x[$(i)])
    end

    # find all components that use dummy currents
    j = n_nodes + 1
    for node in circ.nodes
        for port in node.ports
            if uses_dummy_current(port.component)
                if !(port.component in keys(sym_map))
                    sym_map[port.component] = :(x[$(j)])
                    j += 1
                end
            end
        end
    end

    return sym_map
end

# given a symbol map (which contains an ordering of nodes) generate an
# ordering of circuit components
function get_components_ordered(sym_map::SymbolMap)
    
    components = OrderedSet{Component}()

    for (node, sym) in collect(sym_map)
        if typeof(node) != Node break end
        for port in node.ports
            push!(components, port.component)
        end
    end

    return components
end

# generate the expressions for the system of equations for a circuit
# (used in gen_sys_F)
function gen_sys_exprs(circ::Circuit)

    nodes_vec = collect(circ.nodes)
    n_nodes = length(nodes_vec)

    # find all components that use dummy currents
    dummy_current_components = Set{Component}()
    for node in circ.nodes
        for port in node.ports
            if uses_dummy_current(port.component)
                push!(dummy_current_components, port.component)
            end
        end
    end
    
    # order the dummy current components
    dummy_current_components = collect(dummy_current_components)
    n_dummy_currents = length(dummy_current_components)

    # map from nodes to their voltage symbols
    nv_symbols = Dict{Node, Union{Symbol, Expr}}()
    for i = 1:n_nodes
        nv_symbols[nodes_vec[i]] = :(x[$(i)])
    end

    # map from components to their dummy current symbols
    dummy_current_symbols = Dict{Component, Union{Symbol, Expr}}()
    for i = 1:n_dummy_currents
        dummy_current_symbols[dummy_current_components[i]] = :(x[$(i + n_nodes)])
    end

    sym_map = gen_sym_map(circ)

    function get_dum_cur(comp::Component)
        if comp in keys(sym_map)
            return sym_map[comp]
        else # (if there's no dummy current for this component it doesn't matter)
            return :_
        end
    end

    # the expressions that we're going to return
    exprs = []
    
    nodes_sym_map = collect(sym_map)[1:n_nodes]
    for (node, sym) in nodes_sym_map

        # if this is the ground node, then just set the voltage to zero
        if node == circ.gnd
            push!(exprs, :($(sym)))
            continue
        end


        # otherwise sum the currents going IN to the node
        expr = 0.
        for port in node.ports

            # if either port on the component is floating, set current to zero
            # (same as doing nothing ... since we sum currents)
            if is_floating(other_port(port))
                continue
            end

            expr = :($(expr) + $(dciv(port.component, PortSyms(port => sym, 
            other_port(port) => sym_map[other_port(port).node]),
                port, get_dum_cur(port.component)))
            )
        end

        push!(exprs, expr)
    end

    # need to get every component in the circuit, in an ordered fashion
    # do this based on the ordered set
    components = get_components_ordered(sym_map)

    for comp in components

        # add any extra relations - make sure neither port is floating
        if is_floating(p1(comp)) || is_floating(p2(comp))
            continue
        end

        extra_eqns = dcsatisfy(comp, 
            PortSyms(p1(comp) => sym_map[p1(comp).node],
                p2(comp) => sym_map[p2(comp).node]),
            get_dum_cur(comp))

        append!(exprs, extra_eqns)
    end

    return exprs
end

# generate the function describing the system of equations: F = 0
# place the function in a special sub-module 
function gen_sys_F(func_label::Symbol, circ::Circuit)

    # get the system expressions
    # sys_exprs = 

    nv_exprs = gen_sys_exprs(circ)
    n_exprs = length(nv_exprs)

    func_expr = quote
        
        # x is the vector of node voltage and dummy current variables
        # nv is the memory to write the evaluated equations to
        function $(func_label)(x::Vector{Float64}, nv::Vector{Float64})
            
            $( ex = quote end;
            for i = 1:n_exprs
                push!(ex.args, :(nv[$(i)] = $(nv_exprs[i])))
            end;
            ex )
        end
    end

    Generated.eval(func_expr)
end