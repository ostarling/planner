
#require 'bindings'

#p Bindings
#p Step

module Planning

  class Step < Bindings
    attr_reader :operator, :bindings, :sid
    
    @@id_counter=1
    
    def initialize operator, id=nil
      super operator
      @links = {} #stores links for conditions
      if id.nil?
        @sid = @@id_counter
        @@id_counter += 1
      else
        @sid=id
      end
    end
    
    def == other
      @sid == other.sid && self.class==other.class
    end
  
    # A step is satisfied if all preconditions have links to steps which 
    # statisfy them
    def satisfied?
      first_not_met_condition.nil?
    end
    
    #whether this step causes 'effect' which is a PredicateInstance
    def effects? condition
      not(effect_for(condition).nil?)
    end
    
    # finds and returns an effect which meets the specified condition
    # returns nil if none such exists
    def effect_for condition
      #p @operator.effects
      @operator.effects.find do |eff| 
        eff==condition.predicate && condition.holds?(self, eff)
      end
    end

    #whether this step causes 'effect' which is a PredicateInstance
    def effects_partially? condition
      not(partial_effect_for(condition).nil?)
    end
    def partial_effect_for condition
      @operator.effects.find do |eff| 
        eff==condition.predicate && condition.holds_partially?(self, eff)
      end
    end
    
        
    # Retuns the first precondition (PredicateInstance)
    # which does not have a cause link attached to it
    def first_not_met_condition
      c = @operator.preconditions.find do |pre|
#        p @links
#        p @links.has_key?(pre)
        not (@links.has_key? pre)
      end
      make_instance(c) unless c.nil?
    end
    
    def make_instance condition
        case condition
        when Predicate: PredicateInstance.new(c, self) 
        when ExistentialConstraint: ExistentialConstraintInstance.new(c, self)
        else raise
        end      
    end
    
    
    def not_met_conditions
      @operator.preconditions.select { |pre|
        not (@links.has_key? pre)
      }.map{ |pre|  
          PredicateInstance.new(pre, self)
      }
    end
    
  private  
    # Used internally for adding a fact to this step, useful for describing
    # initial and final states. Specifies a predicate name
    # parameter values and positiveness.
    # <b>Returns</b> a newly created predicate
    def add_fact name, values, positive
      vars = []
      set_values do
        values.each_with_index do |value,index|
          arg_name = "$arg" + @operator.names_size.to_s
          vars << arg_name
          @operator.introduce_parameter arg_name 
          adjust_size 
          set_values arg_name=>value        
        end
      end
      Predicate.new name, vars, positive    
    end
  
  public
    # Adds a percondition to this step. Used for describing the goal state  
    def add_precondition name, values, positive
      @operator.preconditions << add_fact(name, values, positive)
    end
  
    # Adds an effect to this step. Used for describing the initial state  
    def add_effect name, values, positive
      @operator.effects << add_fact(name, values, positive)
    end
    
    def to_s
      "S##{@sid}:" + @operator.name + "(" + 
        @operator.parameters.map{|p| set?(p) ? get_value(p) : "?#{p}"}.join(',')+")"
    end
    
    def add_link link
      @links[link.condition.predicate] = link
    end
    
    def remove_link condition
      @links.delete(condition.predicate)
    end
  end

end