require 'date'

require 'orderging'
require 'predicate'

module Planning::Tests
  

  def test
    
    a = :asd
    
    p a
    p a.to_s+a.to_s
    c = Condition.new 1,2
    c2 = Condition.new 2
    
    p c.inspect
    p c2.inspect
    
    p c.class
  end

  #-------------- orderings ---------------
  
  def illegal_add ord, state1, state2 
    begin
      ord.add state1, state2
    rescue OrderingException =>e
      puts "OK: Got expected exception #{e.inspect}"
    rescue Exception =>e
      puts "FAIL: Unknown exception #{e.inspect}"
    else
      puts "FAIL: No error"
    end
  end
  
  def test_orderings
    ord = Orderings.new
    
    # s1 -> s2 -> s3
    ord.add :s1, :s2
    ord.dump
    ord.add :s2, :s3
    ord.dump
    illegal_add ord, :s3, :s1
    ord.dump
    
    # s4 -> s5-> s6
    ord.add :s4,:s5
    ord.dump
    ord.add :s5,:s6
    ord.dump
    
    # s4 -> s5-> s6 -> s1 -> s2 -> s3 
    ord.add :s6,:s1
    ord.dump
    
    illegal_add ord, :s1, :s4
    ord.dump
  end

  def test_predicate

    preds = []
    
    preds << Predicate.new('ON', ['x', 'y'])
    preds << Predicate.new('~ON', ['x', 'y'])
    preds << Predicate.new('!ON', ['x', 'y'])
    preds << Predicate.new('ON', ['y', 'z'], false)
    preds << Predicate.new('OVER', ['y', 'z'], false)
    preds << Predicate.new('UNDER', ['y', 'z'])
    
    preds.each{ |pr| p pr }
    
    if Predicate.new('~ON', ['x', 'y']) != Predicate.new('!ON', ['x', 'y'])
        raise "Comparison failure"
    end 
    
  end

end

 