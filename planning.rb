
module Planning

  def self.check_types map
      map.each do |argument, type |
        unless argument.nil?
          unless argument.class==type
           raise "Invalid type, expected type: #{type}, received instance #{argument.inspect}" 
          end        
        end
      end    
  end
  
  #define all classes
  
#  class Predicate; end
#  class Argument; end
#  class Operator; end
#  class Bindings 
#  end
#  class Step < Bindings
#  end
#  class PredicateInstance; end
#  class Link; end
#  class Orderings; end
#  class OrderingException; end
#  class Planner; end
#  class Parser; end
  
end

require File.join(File.dirname(__FILE__), 'planning/predicate')
require File.join(File.dirname(__FILE__), 'planning/operator')
require File.join(File.dirname(__FILE__), 'planning/condition')
require File.join(File.dirname(__FILE__), 'planning/bindings')
require File.join(File.dirname(__FILE__), 'planning/step')
require File.join(File.dirname(__FILE__), 'planning/predicate_instance')
require File.join(File.dirname(__FILE__), 'planning/link')
require File.join(File.dirname(__FILE__), 'planning/ordering')
require File.join(File.dirname(__FILE__), 'planning/planner')
require File.join(File.dirname(__FILE__), 'planning/parser')


#class Plan
#  def initialize(start, finish)
#    @steps = [start, finish]
#    @links = []
#    @orderings = [[start,finish]]
#  end
#end

  

## TODO 

## (1) Store in steps/bindings unsuccessful values as well 
## in a separate mappings, i.e. those values which were
## tried, but lead to an unresolvable problem (see also (4))

## (2) Make Bindings versionable, so that it can be reverted
## to a pervious or a particular version (like it is done in orderings)

## (3) If a link unifies some parameters of 2 steps
## then the version numbers (or number?) of newly created
## binding version(s) should be recorded in that link

## (4) If a link is later abandoned as a not promising (or more precisely
## leading to a unresolvable problem) then the combined 
## set of bindings it created have to be recorded in unsuccessful
## records. What is important is that not individual values should be
## saved, but instead they should be saved as a set, which didn't yield
## a positive result, this mean that only the set as a whole
## is unsuccessful, individual values may possibly belong 
## to a successful set as well   

## (5) Create a list of steps, which need to be examined for
## unsatisfied preconditions. After a step is processed we add
## all of its predecessor steps to the end of this list. We
## maintain our current position in the list. Inside a step 
##  



