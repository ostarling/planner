module Planning

  # Represents a link from a source step ("initial") to
  # a target step which achieves a particular condition (PredicateInstance).
  class Link
    
    # S initial --> PredicateInstance(step, predicate)
    
    attr_reader :initial, :condition
    
    def initialize initial, condition
      Planning.check_types initial=>Step, condition=>PredicateInstance
      @initial = initial
      @condition = condition
      # stored already resolved threats for this link
      # so that on new iterations they are not analysed 
      @resolved_threats = []
      
      @src_version = @initial.cur_version
      @dst_version = @condition.step.cur_version
      
  #    # what are these bindings for?
  #    @src_bindings = Hash.new
  #    @dst_bindings = Hash.new
    end
    
    def resolved_threat? step
      @resolved_threats.include? step
    end
    
    def add_resolved_threat step
      @resolved_threats << step
    end
  
  #  def add_src_bindings map
  #    @src_bindings.merge! map
  #  end
  #  
  #  def add_dst_bindings map
  #    @dst_bindings.merge! map
  #  end
  #  
    # reverts the bindings created by this link
    # from the source and the target steps
    # by reverting bindings to remembered versions
    def revert_bindings
      @initial.revert_to @src_version
      @condition.step.revert_to @dst_version
    end
    
    def detach_and_revert
      revert_bindings
      @condition.step.remove_link @condition
    end
    
    def to_s
      "#{initial}--(#{@condition})-->#{@condition.step}"
    end
    
  end
    
end