module Planning

class Argument
  attr_reader :name, :idx

  def initialize name, idx
    @name = name
    @idx = idx
  end

  def to_s
    @name+"#"+@idx.to_s
  end 
  
  def == other
    other.respond_to?(:name) && other.respond_to?(:idx) &&
      other.name==@name && other.id==@id
  end
end

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
        p "\"#{name}\" not in table"
        if name==""
          raise
        end
        @idx = @@names.size
        @@names << name
        @@name_index[name] = @idx
        @@arg_count_index[name] = @variables.size
      else
        arg_count = @@arg_count_index[name]
        if arg_count != @variables.size
          raise "Argument number mismatch for #{self}, expected #{arg_count}"
        end
      end
  end
  
  def == other
    #p "other=#{other.inspect}"
    @idx==other.idx && @positive==other.positive
  end
  
  def name
    n = @@names[@idx]
    #p "name(): @idx=#{@idx}, @@names=#{@@names.inspect}"
    n
  end
  
  def to_s
    (@positive ? '' : '~')+ name + "##{@idx}" + "("+
        @variables.join(", ")+")" 
  end
  
  def inverse
      Predicate.new name, @variables, !@positive    
  end
  
end

end