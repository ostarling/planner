module Planning
  
  
  # Represents an operator, i.e. an abstract step.
  # On creation converts its own parameters and
  # those of precondition and effect predicates
  # to Argument type.
  # Used as a template when creating plan steps.
  # Never changes since created
  class Operator
  
    attr_reader :name, :parameters, :preconditions, :effects  
    # name - String
    # parameters - String[]
    # preconditions - Predicate[]
    # effects - Predicate[]
    def initialize(name, parameters, preconditions, effects)
        @var_names = []
        @name_idx_map = {}
        @name = name
        @parameters = map_vars parameters
        @preconditions = preconditions.map do |pr|
          case pr
            when Predicate: map_predicate pr
            when ExistentialConstraint: map_existential pr
            else raise "Unsupported precondition {@pr.inspect}" 
          end
        end
        @effects = effects.map do |pr|
          map_predicate pr 
        end
        @var_names.each_with_index do |name, index|
          @name_idx_map[name] = index
        end
    end  
    
    def map_predicate pr
      Predicate.new pr.name, map_vars(pr.variables), pr.positive
    end

    def map_existential ex
      ExistentialConstraint.new map_predicate(ex.predicate), map_vars(ex.vars)
    end
    
  
    # Maps an array of variable names to an array of 
    # Argument objects. If Argument objects are 
    # supplied instead, their names are used for mapping
    # and new Argument objects are created instead.   
    def map_vars names
      names.map do |var|
        if var.is_a? Argument
          var = var.name
        end
        idx = @var_names.index var
        if idx.nil?
          idx = introduce_parameter var
        end
        Argument.new var, idx
      end
    end  
    
    # Adds a named parameter to this operator.
    # This method is typically used to describe initial and goal states
    # <b>returns</b> the index assigned to the introduced parameter 
    def introduce_parameter name
      idx = @var_names.size
      @var_names << name
      @name_idx_map[name] = idx
      idx
    end
  
    # Tells whether this operator can <b>achive an unbound predicate</b>
    def achieves? pred #Predicate
      eff = effect_for pred
      not(eff.nil?)
    end
    
    def effect_for pred
      @effects.find{|c| c == pred } 
    end
  
    # Returns an <b>index of a name</b> or raises an error if no match
    def name_index name
      idx = @name_idx_map[name]
      if idx.nil?
        raise "Error: Name #{name} is not used in operator #{@name}"
      end
      idx
    end
  
    # Returns <b>a parameter name</b> by an index or raises an error if 
    # an index is out of range
    def name_by_index idx
      if idx < 0 || idx >= @var_names.size
        raise "Error: Index #{idx} is out of range [0..#{@var_name.size}] in operator #{@name}"
      end
      @var_names[idx]  
    end
  
    # Returns the size of names table
    def names_size
      @var_names.size
    end
    
    def to_s
      name + "(" + parameters.join(", ")+")"      
    end
    
    def dump
        self.to_s + ": precond {" + @preconditions.join(",") + "}, effects {"  + @effects.join(',') + "}"
    end
  end
  
  
end