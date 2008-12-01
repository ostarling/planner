
module Planning

  
  class ExistentialConstraint 
    
    # predicate - the predicate to check
    # vars - free variables 
    attr_reader :predicate, :vars
    
    def initialize predicate, vars
      @predicate = predicate
      @vars = vars
    end
  
    def to_s
      "!E("+@vars.join(",")+"):{"+@predicate.to_s+"}"
    end
  end
  
  class ExistentialConstraintInstance 

    def initialize contraint, step
        @constraint = contraint
        @predicate_instance = PredicateInstance.new contraint.predicate, step
        @step = step      
    end
    
    def to_s
      "!E("+@vars.join(",")+"):{"+@predicate_instance.to_s+"}"
    end

            
  end
    
end