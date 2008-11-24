require 'date'

module Planning

  # Stores  values of all variables of a step
  # for a particular version
  class BindingData
    attr_reader :version, :values
  
    def initialize values, version=0
      @values = values
      @version = version
    end
  
    # Returns a new instance of BindingData which
    # represents the next version, copies all values
    # from the current one into the new one
    def next_version
      vals = []
      vals.push( *@values)
      BindingData.new vals, @version+1
    end
  end
  
  # Stores current values of all variables (and their history) 
  # of a step
  class Bindings
   
    def initialize operator
      @operator = operator
      # batch mode controls how versioning is done
      @batch_mode = false
      # array of BindingData
      @bindings = [ BindingData.new( [nil] * operator.names_size) ]
    end
  
    def adjust_size
      cur_data = @bindings[-1]
      if cur_data.values.size < @operator.names_size
        cur_data.values.push( * ([nil] * (@operator.names_size - cur_data.values.size)) )
      end
    end
    
    def size
        cur_values.size    
    end
  
    # returns array of current values
    def cur_values
      @bindings[-1].values
    end
  
    def cur_version
      @bindings[-1].version
    end
    
    def revert_to version
      while version > cur_version do
        @bindings.pop
      end
    end
  
    # Tells whether this Bindings object has all values
    # set to non-nil in the current version of its bindings
    def complete?
      cur_values.all{ |value| value!=nil }
    end
  
  
    # Tells whether all variables named by "arg" 
    # are initialised to non-nil values in this Binding.
    # "arg" can be an Array of Argument or a Predicate
    def all_set? arg
      case arg
        when Predicate: all_set? arg.variables 
        else arg.all?{ |var| set? var }
      end
    end
    
  
    # Tells whether all variables named by "arg" 
    # are initialised to non-nil constant values in this Binding.
    def all_const? arg
      case arg
        when Predicate: all_const? arg.variables 
        else arg.all?{ |var| is_constant?(get_value(var)) }
      end
    end
    
    # Tells whether an Argument arg is set to non-nil
    # in this Binding
    def set? arg
     get_value(arg)!=nil
    end
  
    def as_index arg
      if arg.respond_to? :idx
        arg.idx
      else
        @operator.name_index(arg)
      end
    end
    
    def get_value arg
      cur_values[as_index(arg)]
    end
    
    # shorthand for get_value
    def [] name
      get_value name
    end
  
  
    # Creates a new version of data and
    # sets a value or executes a block if given against it
    # passes self into the block as the only argument,
    # multiple set_values may be issued inside the block
    # and will not lead to creation of new version of data for each change
    def set_values  values_map=nil
      @bindings << @bindings[-1].next_version unless @batch_mode
      #p values_map
      unless values_map.nil?
        values_map.each do |name, value| 
          check_value_type value
#          p as_index(name)
#          p value
          cur_values[as_index(name)]=value
        end
      end
      if block_given?
        @batch_mode = true
        yield self
        @batch_mode = false
      end
    end
  
    def check_value_type value
      unless is_constant?(value) or value.is_a?(Condition)
        raise "Error: value must be either a constant or a Condition. Value=#{value.inspect}"
      end
    end
    
    def is_constant? value
      value.is_a?(Numeric) ||  value.is_a?(String) || 
        value.is_a?(Symbol) || value===true || value===false ||
        value.is_a?(Time) || value.is_a?(Date)
    end
    
  end
  
    
end

