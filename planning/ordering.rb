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
  
  def initialize prev_version, version, order=nil, next_ords=nil#, prev_ords=nil  
    @prev_version = prev_version
    if prev_version.nil? && (order.nil? || next_ords.nil?)# || prev_ords.nil? )
      raise "Invalid arguments: either prev_version or both order and next_ords should be non-nil"
#      raise "Invalid arguments: either prev_version or order, next_ords and prev_ords should be non-nil"
    end
    
    @version = version
    @order = order
    @next_ords = next_ords
    #@prev_ords = prev_ords
  end
  
  def chain version, order, next_ords #, prev_ords
    OrderingData.new self, version, order, next_ords #, prev_ords
  end
  
  def order
    @order.nil? ? @prev_version.order : @order 
  end
  def next_ords
    @next_ords.nil? ? @prev_version.next_ords : @next_ords 
  end
#  def prev_ords
#    @prev_ords.nil? ? @prev_version.prev_ords : @prev_ords 
#  end
  
  def order_unset?
    @order.nil?
  end
  def next_ords_unset?
    @next_ords.nil?
  end
#  def prev_ords_unset?
#    @prev_ords.nil?
#  end
  
end

class Ordering

#  @@debug = true
  
  attr_reader :step 
  attr_accessor :trace
  
  def initialize orderings, step, order, version
    @orderings = orderings
    @step = step
    #                     prev_version, version, order, next_ords #, prev_ords  
    @data = OrderingData.new nil, version, order, [] #, []  
    @trace = 0
  end
  
  def order= value
    if @data.order_unset? && @data.version==@orderings.cur_version
      @data.order = value
    else
      @data = @data.chain @orderings.cur_version, value, nil #, nil 
    end
  end
  
  def order
    @data.order
  end
  
  def next_ords
    @data.next_ords
  end
  
#  def prev_ords
#    @data.prev_ords
#  end
  
  def add_next_ords ord
    unless @data.next_ords.include? ord
      new_next_ords=[]
      new_next_ords.push *(@data.next_ords)
      new_next_ords << ord
      if @data.next_ords_unset? && @data.version==@orderings.cur_version
        @data.next_ords = new_next_ords
      else
        @data = @data.chain @orderings.cur_version, nil, new_next_ords #, nil
      end
      
      #add_prev_ords self
    end
  end
  
#private
#  def add_prev_ords ord
#    new_prev_ords=[]
#    new_prev_ords.push *(@data.prev_ords)
#    new_prev_ords << ord
#    if @data.prev_ords_unset? && @data.version==@orderings.cur_version
#      @data.prev_ords = new_prev_ords
#    else
#      @data = @data.chain @orderings.cur_version, nil, nil, new_prev_ords
#    end
#  end
#public
  
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
  
  def initialize
    @steps = {}
    @version = 0
    @order_step = 10
    @trace=0
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
  
  
  def add step1, step2
    
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


end

