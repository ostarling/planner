module Planning

  # a class for complex conditions 
  class Condition
    def eval context
    end    
  end
  
  
  class ConditionVariable < Condition
    def initialize name
      @name=name
    end
    def eval context
      context[@name]      
    end
  end
  
  class ConditionConst < Condition
    def initialize value
      @value=value
    end
    def eval context
      @value
    end
  end
  
  class NotCondition < Condition
    def initialize cond
      @cond=cond
    end
    def eval context
      ! @cond.eval(context)      
    end
  end
  class BinaryCondition < Condition
    def initialize operation, op1, op2
      raise "Unknown operation #{operation}" unless 
        [ :eq, :neq, :lt, :gt, :lte, :gte].include? operation
      @operation=operation
      @op1=op1
      @op2=op2
    end
    def eval context
      v1=@op1.eval(context)
      v2=@op2.eval(context)
      case @operation
      when :eq
        v1==v2
      when :neq 
        v1!=v2
      when :gt 
        v1>v2
      when :lt 
        v1<v2
      when :gte 
        v1>=v2
      when :lte
        v1<=v2
      end
    end
  end
  
  class MultinodeCondition < Condition
    def initialize op, conditions
      raise "Unknown operation #{op}" unless [ :and, :or].include? op
      @operation=op
      @conditions=conditions
    end
    def eval context
      case @operation
      when :or
          not @conditions.find{|c| c.eval(context)}.nil?
      when :and 
          @conditions.find{|c| not c.eval(context)}.nil?
      end
    end
  end
      
  
  class SampleContext
      def initialize 
          @values = {}
      end
      def []= name, value
        @values[name] = value
      end
      def [] name
          @values[name]        
      end    
  end
  
  
  
  def self.assert expected, actual
    unless expected==actual
        raise StandardError, "Expected '#{expected}', but got #{actual}", caller[0..-2]
    else
      #puts "OK"      
    end
  end
  
  def self.test
      ctx = SampleContext.new
      ctx['x']='A'
      ctx['y']='B'
      ctx['z']='C'
    
      c = MultinodeCondition.new :and, [BinaryCondition.new(:eq, ConditionVariable.new('x'), ConditionConst.new('A')), 
                            BinaryCondition.new(:eq, ConditionVariable.new('y'), ConditionConst.new('B'))]
      assert true,  c.eval(ctx)                        

  
      c = MultinodeCondition.new :and, [BinaryCondition.new(:eq, ConditionVariable.new('x'), ConditionConst.new('A2')), 
                            BinaryCondition.new(:eq, ConditionVariable.new('y'), ConditionConst.new('B'))]
      assert false, c.eval(ctx)                        
      c = MultinodeCondition.new :and, [BinaryCondition.new(:eq, ConditionVariable.new('x'), ConditionConst.new('A')), 
                            BinaryCondition.new(:eq, ConditionVariable.new('y'), ConditionConst.new('YB'))]
      assert false, c.eval(ctx)                        
      c = MultinodeCondition.new :or, [BinaryCondition.new(:eq, ConditionVariable.new('x'), ConditionConst.new('A')), 
                            BinaryCondition.new(:eq, ConditionVariable.new('y'), ConditionConst.new('YB'))]
      assert true, c.eval(ctx)                        
      c = MultinodeCondition.new :or, [BinaryCondition.new(:eq, ConditionVariable.new('x'), ConditionConst.new('A2')), 
                            BinaryCondition.new(:eq, ConditionVariable.new('y'), ConditionConst.new('B'))]
      assert true, c.eval(ctx)                        
  end
  
  
  test
end