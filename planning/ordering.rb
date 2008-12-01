module Math

  def self.min a,b
    a<b ? a : b 
  end
  def self.max a,b
    a>b ? a : b 
  end
  
end

module Planning
  


class OrderingException < Exception
  
end


class OrderingData
  
  attr_reader :prev_version, :version
  attr_writer :order
  
  def initialize prev_version, version, order=nil, next_ords=nil, prev_ords=nil  
    @prev_version = prev_version
    if prev_version.nil? && (order.nil? || next_ords.nil? || prev_ords.nil? )
      #raise "Invalid arguments: either prev_version or both order and next_ords should be non-nil"
      raise "Invalid arguments: either prev_version should be non-nil "+
            "or order, next_ords and prev_ords all should be non-nil"
    end
    
    @version = version
    @order = order
    @next_ords = next_ords
    @prev_ords = prev_ords
  end
  
  def chain version, order, next_ords, prev_ords
    OrderingData.new self, version, order, next_ords, prev_ords
  end
  
  def order
    @order.nil? ? @prev_version.order : @order 
  end
  def next_ords
    @next_ords.nil? ? @prev_version.next_ords : @next_ords 
  end
  def prev_ords
    @prev_ords.nil? ? @prev_version.prev_ords : @prev_ords 
  end
  
  def order_unset?
    @order.nil?
  end
  def next_ords_unset?
    @next_ords.nil?
  end
  def prev_ords_unset?
    @prev_ords.nil?
  end
  
end

class Ordering

#  @@debug = true
  
  attr_reader :step 
  attr_accessor :trace
  
  def initialize orderings, step, order, version
    @orderings = orderings
    @step = step
    #                     prev_version, version, order, next_ords, prev_ords  
    @data = OrderingData.new nil, version, order, [], []  
    @trace = 0
  end
  
  def order= value
    if @data.order_unset? && @data.version==@orderings.cur_version
      @data.order = value
    else
      @data = @data.chain @orderings.cur_version, value, nil, nil 
    end
  end
  
  def order
    @data.order
  end
  
  def next_ords
    @data.next_ords
  end
  
  def prev_ords
    @data.prev_ords
  end
  
  def add_next_ords ord
    unless @data.next_ords.include? ord
      new_next_ords=[]
      new_next_ords.push *(@data.next_ords)
      new_next_ords << ord
      if @data.next_ords_unset? && @data.version==@orderings.cur_version
        @data.next_ords = new_next_ords
      else
        @data = @data.chain @orderings.cur_version, nil, new_next_ords, nil
      end
      
      ord.add_prev_ords self
    end
  end
  
private
  def add_prev_ords ord
    new_prev_ords=[]
    new_prev_ords.push *(@data.prev_ords)
    new_prev_ords << ord
    if @data.prev_ords_unset? && @data.version==@orderings.cur_version
      @data.prev_ords = new_prev_ords
    else
      @data = @data.chain @orderings.cur_version, nil, nil, new_prev_ords
    end
  end
public
  
  def to_s
    "{step #{@step} @#{trace}, "+
    "order=#{@data.order}, version=#{@data.version}, "+
    "next=[#{list_to_s(@data.next_ords)}]}"
  end
  
  def list_to_s list
    list.collect{|ord| ord.step.to_s+":"+ord.order.to_s }.join(',')
  end
  
  
#  @@MIN_GEN=-2000000000
#  @@MAX_GEN=2000000000
  
  def min_next
    unless next_ords.empty?
      next_ords.inject{|min, ord| min.order>ord.order ? ord : min}
    else
      nil
    end
  end

#  
#  Reverts to the specified version. 
#  If this entry is older than the version specified, returns false.
#  Otherwise returns true
#  
  def revert_to version
    while !@data.nil? && @data.version > version
      @data = @data.prev_version
    end
    !@data.nil?
  end
  
  
end


class Orderings
  
  def initialize start, finish
    @steps = {}
    @version = 0
    @order_step = 10
    @trace=0
    @start = start
    @finish = finish
    # it is implied that start is before finish
    #ostart = get_ordering @start
    #ofinish = get_ordering @finish
    #ostart.add_next_ords ofinish
  end
  
  def cur_version
    @version
  end

  def get_ordering step, order=1
    ord = @steps[step]
    if ord.nil?
      ord = Ordering.new self, step, order, @version
      @steps[step] = ord
    end
    ord
  end
  
  def revert_to version
     puts "Orderings: Reverting to version #{version}"
     vals = @steps.values
     vals.each{|ord|
        @steps.delete ord.step unless ord.revert_to version  
     }
     @version = version
  end
  
  
  def dump
    puts "Dumping orderings"
    @steps.each{|step,ord|
      puts "#{step} ==> ["+ord.next_ords.map{|o| o.step}.join(", ")+"]"
      #puts "#{step} => #{ord}" 
    }
    puts "=="
  end
  
#  def dump_tree start=nil
#    if start.nil?
#      m = @steps.each_value.inject{|m,s| m.order<s.order ? m : s}
#    end
#  end
  

  # returns 
  #  1 - if the step is after 'relative_to' step
  # -1 - if the step is before 'relative_to' step
  #  0 - if there is no defined ordering relation between these steps
  def get_relative_position step, relative_to
    
    #this method must not be invoked with relative_to equal to @start or @finish
    raise if [@start,@finish].include? relative_to
    
    #handle special cases
    return -1 if step==@start
    return 1 if step==@finish
    
    ostep = get_ordering step
    orel = get_ordering relative_to
    
    if ostep.order < orel.order
      #'step' can possibly be before
      res = find_before orel, ostep
      return res.nil? ? 0 : -1

    elsif ostep.order > orel.order
      #'step' can possibly be after
      res = find_after orel, ostep
      return res.nil? ? 0 : 1
    
    else
      #'step' is surely unrelated
      return 0      
    end
    

  end
  
  def find_after obase, ostep
      obase.next_ords.each do |o|
        return o if o.step = ostep.step
        if o.order < ostep.order
          res = find_after o, ostep
          return res unless res.nil?
        end
      end
      return nil
  end
  
  def find_before obase, ostep
      obase.prev_ords.each do |o|
        return o if o.step = ostep.step
        if o.order > ostep.order
          res = find_before o, ostep
          return res unless res.nil?
        end
      end
      return nil
  end

  def add step1, step2
    
    # check obvious ordering violations
    raise OrderingException.new("Can't put @{step2} after the GOAL step") if step1==@finish
    raise OrderingException.new("Can't put @{step1} before the INITIAL step") if step2==@start
    
    # don't actually add orderings like AFTER INITIAL and BEFORE GOAL
    # as it is implied and enforced for all other steps 
    if step1==@start || step2==@finish
      return
    end
    
    @trace += 1 # allocate a new unique trace value
    @version += 1
    begin
  
      
      o1 = get_ordering step1
      o2 = get_ordering step2
      
      #p o1, o2
      
      unless o1.next_ords.include? o2

        puts "Adding ordering #{step1} << #{step2}"

        o1.add_next_ords o2
        #o2.prev << o1
        
        
        #puts "next_ords became #{o1.next_ords}"
        
        if o1.order >= o2.order
          propogate o2, o1.order
        end
#      else
#        puts "Ignoring duplicate ordering"
      end
    rescue OrderingException
      puts "Failed to add ordering #{step1} << #{step2}"
      @version -= 1
      revert_to @version
      raise
    end
  end

  def propogate ordering, order
    
    #p "in propogate with #{ordering} and #{order}"
    
    if ordering.trace == @trace
      raise OrderingException.new, "Circular reference", caller
    end

    ordering.trace = @trace
    min_ord = ordering.min_next
    min_next = min_ord.nil? ? nil : min_ord.order

    # if there is no next
    if min_next.nil?
      ordering.order = order + @order_step
#      p "there is no next, setting gerenation to #{ordering.order} "
      return
    end

    #max_prev = ordering.max_prev
    
    if order+1 < min_next 
#      p "case 1"
      ordering.order = (min_next - order) / 2 + order
    else
      if order-min_next > @order_step      
#        p "case 2"
        ordering.order = order + @order_step
      else
#        p "case 3"
        ordering.order = order + @order_step / 2
      end
     
      ordering.next_ords.each{|o|
         propogate o, ordering.order if o.order<=ordering.order }  
    end
    
  end
  
end


class IteratorPathElement
  attr_accessor
  def initialise orderings
    @orderings = orderings
    @position = 0
  end
  def has_more?
    @position+1 < @orderings.size
  end
  def next
    if has_more?
      @position += 1
      @orderings[@position]
    else
      nil
    end
  end
  #returns the current ordering
  def cur_ordering
    @orderings
  end
end

class OrderingNetIterator

  def initialize base_ordering, method_name=:prev_ords
      @base = base_ordering
      @path = []  #corresponds to  
      @method_name = method_name
  end  
  
  def get_data ordering
    ordering.__send__(@method_name)
  end
  
  #moves pointer to the next step in the tree
  #returns the next Ordering element or nil no more elements left
  def next
    # if the path is empty attempt create the first path element 
    if @path.empty?
      ords = get_data @base
      if ords.empty?
        # if the base ordering has no related orderings to traverse
        # return false 
        return nil
      else
        #otherwise create the path element 
        @path << IteratorPathElement.new(ords[0])
        return ords[0] 
      end     
    else
      # The path is not empty, we have to advance to the next element
      cur_elem = @path[-1]
      # We use the depth-first algorithm, check whether we can deepen first
      ords = get_data(cur_elem.cur_ordering)
      unless ords.empty?
        # deepen the path
        @path << IteratorPathElement.new(ords[0])
        return ords[0]
      else
        # move to next element
        
        # remove path elements which have enumerated already all their children  
        until cur_elem.has_more?
          @path.pop
          if @path.empty?
            return nil
          end
          cur_elem = @path[-1]
        end
        
        #actually move to the next sibling element
        return cur_element.next
      end
    end
  end
  
  def get_current
    return nil if @path.size==0
    
    cur_elem = @path[-1]
    get_data(cur_elem[:ord])[cur_elem[:idx]]
          
  end
  
end


class LazyTreeLinearizer

  def initilize iterator
    @iterator = iterator
    @linearized = []
  end
    
  def get idx
    raise if idx<0
    if idx<=@linearized.size
      @linearized[idx]
    else
      i=@linearized.size
      while i<=idx
        elem = @iterator.next
        unless elem.nil?
          @linearized << elem
          i += 1
        else
          return nil
        end
      end
      return @linearized[-1]
    end
  end
end

class LinearizerIterator
  def initalize linearizer 
    @linearizer = linearizer
    self.reset
  end
  def reset
    @position = 0    
  end
  def next
    res = @linearizer.get @position
    @position +=1 unless res.nil?
    res
  end
end

class FileringLinearizer

  def initialize @linearizer_iterator 
    @cached = []
  end
  
    
end

end

