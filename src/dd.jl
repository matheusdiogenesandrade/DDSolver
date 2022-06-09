module DecisionDiagram

include("symbols.jl")

export State

const State = Dict{Any, Any}

mutable struct Instance 
  empty_domain::Any             # Null condidate - used for the case where the function `get_candidates` returns an empty array
  domain::Vector{Any}           # Domain space for the candidates
  variables::Vector{Any}        # DD tree variables
  initial_state::State          # DD Tree root state
  width_limit::Int              # DD tree Width limit
  get_candidates                # Callback for listing the forward candidates of a given state
  get_next_state                # Callback for creating a new state
  not_redundant_state           # Callback for determining wether a given state is not redundant
  compact_width                 # Callback for compact DD tree width
  states::Vector{Vector{State}} # idx - variable index
  LOG::Bool                     # Flag to log 
  Instance(empty_domain::Any, domain::Vector{Any}, variables::Vector{Any}, initial_state::State, get_candidates, get_next_state, not_redundant_state) = new(empty_domain, domain, variables, initial_state, typemax(Int), get_candidates, get_next_state, not_redundant_state, nothing, Vector{Vector{State}}([Vector{State}() for variable in variables]), false)
end

################################ FORWARD ################################
# Forwards a given state `state` by the variable at `idx_variable`      #
# Input:                                                                #
#       idx_variable - Variable index in the array `dd.variables`       #
#       state        - A state object to be forwarded by `idx_variable` #
#       dd           - A DD instance object                             #
# Output:                                                               #
#       None                                                            #
#########################################################################

function forward(idx_variable::Int, state::State, dd::Instance)

  # get candidates
  candidates = dd.get_candidates(idx_variable, state, dd)  

  # check is there is any candidate, otherwise add the empty domain candidate
  isempty(candidates) && push!(candidates, dd.empty_domain)

  # log case
  dd.LOG && flush_println("  - In $state we have the candidates $candidates")

  # generate a new state by each candidate
  for candidate in candidates

    next_state = dd.get_next_state(idx_variable, state, candidate, dd)
    add_state(idx_variable, next_state, dd) 

    # log case
    dd.LOG && flush_println("   > Candidate $candidate generated state $next_state")

  end

end

############################## ADD STATE ################################
# Adds a given state `state` to the variable at `idx_variable`          #
# Input:                                                                #
#       idx_variable - Variable index in the array `dd.variables`       #
#       state        - A state object to be forwarded by `idx_variable` #
#       dd           - A DD instance object                             #
# Output:                                                               #
#       None                                                            #
#########################################################################

function add_state(idx_variable::Int, state::State, dd::Instance)

  # get the states set of the `idx_variable`
  states = dd.states[idx_variable]

  # check if the state `state` is redundant, case not, just store it
  (!in(state, states) && dd.not_redundant_state(idx_variable, state, states)) && push!(states, state)
end

########################### COMPACT WIDTH ###############################
# Compacts the width of the state set of the variable at `idx_variable` #
# Input:                                                                #
#       idx_variable - Variable index in the array `dd.variables`       #
#       dd           - A DD instance object                             #
# Output:                                                               #
#       None                                                            #
#########################################################################

function compact_width(idx_variable::Int, dd::Instance)

  # get states set length
  n = length(dd.states[idx_variable])

  # if it is not larger than the width limit
  n <= dd.width_limit && return

  # edge case: no callback given
  dd.compact_width == nothing && error("The index $idx_variable (with $n states) reached the width limit of $(dd.width_limit) and the `compact_width` function was not defined in the DecisionDiagram")

  # log case
  dd.LOG && flush_println(" * COMPACTING WIDTH FROM $n to $(dd.width_limit).")

  # compact
  dd.compact_width(idx_variable)

  # log case
  dd.LOG && flush_println(" * NEW STATES ARE THESE $(dd.states[idx_variable]).")

end

################################ RUN ####################################
# Executes the DD                                                       #
# Input:                                                                #
#       dd           - A DD instance object                             #
# Output:                                                               #
#       None                                                            #
#########################################################################


function run(dd::Instance)

  # log case
  dd.LOG && flush_println(" * Forwarding at the root.")

  # initialize the first variable with the initial state
  forward(1, dd.initial_state, dd) 

  # log case
  dd.LOG && flush_println(" * First depth has the states $(dd.states[1]).")

  # compacts the width of the first variable
  compact_width(1, dd)

  # for each variable from the first to the pre-last
  n = length(dd.variables)
  for idx in 1:n - 1 

    # log case
    dd.LOG && flush_println(" * Forwarding to index $(idx + 1) (variable $(dd.variables[idx + 1])):")

    # get states
    states = dd.states[idx]

    # edge case: no states found
    isempty(states) && error("The instance is infeasible")

    # forward each state
    [forward(idx + 1, state, dd) for state in states]

    # log case
    dd.LOG && flush_println(" * Depth $(idx + 1) has the states $(dd.states[idx + 1]).")

    # compact width
    compact_width(idx + 1, dd)

    # log case
    flush_println("Depth $idx has $(length(dd.states[idx])) states")

  end

  # edge case: no solution found
  isempty(dd.states[n]) && error("The instance is infeasible")
end

end

