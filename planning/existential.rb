
module Planning

  
  class ExistentialConstaint 
    
    attr_reader :predicate, :vars, :step
    
    def initialize predicate, vars, step
      @predicate = predicate
      @vars = vars
      @step = step
    end
  
    #TODO
    ...
    
  end
    
end