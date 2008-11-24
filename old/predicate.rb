module Planning

class Predicate
  
  attr_reader :idx, :variables, :positive
  
  @@names = []
  @@name_index = {}
  @@arg_count_index = {}
  
  def initialize(name, variables, positive=true)
      name = name.to_s    
      @positive=positive
      @variables = variables

      if name =~ /^[~|!]/
        #p "name '#{name}' starts with a NOT, truncating"
        name = name[1..-1]
        #p "truncated to '#{name}'"
        @positive = !@positive
      end
      
      @idx = @@name_index[name]
      if @idx.nil?
        #p "#{name} not in table"
        @@names << name
        @idx = @@names.size
        @@name_index[name] = @idx
        @@arg_count_index[name] = @variables.size
      else
        arg_count = @@arg_count_index[name]
        if arg_count!=@variables.size
          raise "Argument number mismatch for #{self}, expected #{arg_count}"
        end
      end
  end
  
  def == other
    @idx==other.idx && @positive==other.positive
  end
  
  def name
    @@names[@idx]
  end
  
  def to_s
    (@positive ? '' : '¬')+ name + @variables.to_s 
  end
  
  def inverse
      Predicate.new @name, @variables, !@positive    
  end
  
end




end