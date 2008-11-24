
module Planning

  # This is a Predicate linked to a Step
  # It uses Bindings which belong to the linked Step
  class PredicateInstance
    
    attr_reader :predicate, :step
    
    def initialize predicate, step
      @predicate = predicate
      @step = step
    end
  
    def == other
      @predicate==other.predicate && holds?(other.step[p])
    end
  
    # Tells whether this PredicateInstance holds in another step
    # (which is represented by just Bindings). In fact it tests
    # whether all its named parameters are bound to the same values
    # or unbound in both places   
    def holds? step, effect
      @predicate.variables.each_with_index do |var, idx|
        unless @step[var] == step[effect.variables[idx]]
          return false
        end 
      end
    end
    
    # Tells whether this PredicateInstance <b>holds <i>partially</i></b> in another step
    # (which is represented by just Bindings). In fact it tests
    # whether all its named parameters are bound to the same values
    # or unbound in both places OR (which classifies as <i>partially</i>)
    # a bound value in predicate is not (yet) bound in one of them
    def holds_partially? step, effect
      used_values = step.cur_values
      this_used_values = @step.cur_values
      @predicate.variables.each_with_index do |var, idx|
        this_val = @step[var]
        val = step[effect.variables[idx]]
        unless this_val == val || 
            (val.nil? && !used_values.include?(this_val)) || 
            (this_val.nil? && !this_used_values.include?(val)) 
          return false
        end 
      end
    end
    
    # Assigns unbound variables of effect to those matching of
    # a precondition. This is needed in order to satisfy a precondition
    # if a partial effect match was found (a partially unbound effect,
    # which is further bound by this method)
    def assign_missing_bindings step, effect
      step.set_values do |st|
        @predicate.variables.each_with_index do |var, idx|
          other_var = effect.variables[idx] 
          if @step.set? var
            unless st.set? other_var
              st.set_values other_var => @step[var]
            else
              #do a sanity check, values must match!
              if @step[var]!=st[other_var]
                raise "Values do not match! @step[#{var.inspect}]=#{@step[var].inspect}, "+
                  "st[#{other_var.inspect}]=#{st[other_var].inspect}"
              end
            end
          elsif step.set? other_var
            @step.set_values var => step[other_var]
          end 
        end
      end
    end
    
    # Tells whether all variables of this predicate
    # are bound to non-null values
    def complete?
      @step.all_set? @predicate
    end
    
    # Tells whether all variables of this predicate
    # are bound to constant non-null values (not to variables)
    def instance?
      @step.all_const? @predicate
    end
    
    # returns parameter values as an array
    def arg_values
      @predicate.parameters.map{|p| @step[p]}
    end
  

    # Returns the logically inverse PredicateInstance, i.e. NOT(this)
    def inverse
      PredicateInstance.new @predicate.inverse, @step      
    end
    
    def to_s
      (@predicate.positive ? "" : "!") + @predicate.name + 
        "("+ @predicate.variables.map{|v| 
              val=@step[v]
              val.nil? ? "?#{v}" : val }.join(',')+")"
    end
    
  end
  
end