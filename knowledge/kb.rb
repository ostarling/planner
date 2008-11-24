

class Fact
  attr_reader :name, :arguments, :negative
  def == other
      @name==other.name && @arguments==other.arguments    
  end
  def initialize(name, *arguments)
    @name=name.to_s
    @negative = (@name[-1]=='!')
    if @neagtive
      @name = @name[0..-2]
    end 
    @arguments=arguments
  end 
  
  def to_s
  (@negative ? "~" : "") + @name.to_s + "(" + @arguments.each{|x| '"'+x.to_s+'"'}.join(",") + ")"
  end
end

class ArgumentList
  attr_reader :names
  def initialize(*names)
      @names = names
  end
end


class Autodef
   def initialize(kb)
     @kb = kb
   end
    
   def method_missing name, *args
     @kb.define name, *args
   end    
end

class KnowledgeBase
  
  def initialize
    @facts = {}
    @factsIndex = {}
  end
  
  def factKey fact
    key = fact.name.to_s + "+" + fact.arguments.each{|x| '"'+x.to_s+'"'}.join(",")
  end
  
  def test fact
      f =  @facts[ factKey(fact) ]
      
      f.nil? ? false : f.negative==fact.negative
  end
  
  
  def add(fact)
    @facts[ factKey(fact) ] = fact
  end
  
  def remove(fact)
      @facts.delete(factKey(fact))
  end

  
    
  def define(*fact)
      add Fact.new(fact[0], fact[1..-1])
  end
  
  def print
    p "Current facts are:"
    @facts.each{ |k,f|
      p "#{k} ==> #{f.to_s}"
    }
    p "Done"
  end
    
end