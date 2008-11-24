require 'date'

module Planning

require 'predicate'
require 'ordering'

class Operator

  attr_reader :name, :parameters, :preconditions, :effects
  
  # name - String
  # parameters - String[]
  # preconditions - Predicate[]
  # effects - Predicate[]
  def initialize(name, parameters, preconditions, effects)
      @name = name
      @parameters = parameters
      @preconditions = preconditions
      @effects = effects    
  end  
  
  def achieves? pred #Predicate
    @effects.find{|c| c == pred } != nil
  end
  
end

class Bindings
  
  
  
  def initialize operator
    @operator = operator
    @bindings = {}
    define @operator.parameters
    @operator.preconditions.each{|pre| 
      define pre.arguments
    }
    @operator.effects.each{|eff| 
      define eff.arguments
    }
  end

  def size
      @bindings.size    
  end
  
  def define variables
    variables.each{|var| @bindings[var]=:nothing}
  end
  
  def introduce name, value
    @bindings[name]=value
  end

  def complete?
    @bindings.all{ |key, value| value!=:nothing }
  end
  
  def all_set? arg
    case arg
      when Predicate: all_set? arg.variables 
      else arg.all?{ |var| set? var }
    end
  end
  
  def set? name
    get_value(name)!=:nothing
  end
  
  def get_value name
    value = @bindings[name]  
    check_value value, name
    value
  end
  
  def [] name
    get_value name
  end

private
  def check_value value, name
    if value.nil? 
      raise "Error: Name #{name} is not used in operator #{operator.name}"
    end
  end
  
public
  def check_varname name
    value = @bindings[name]  
    check_value value, name
  end
  
  def bind(name, value)
    check_varname name
    @bindings[name] = value
  end
  
  def unbind(name)
    check_varname name
    @bindings[name] = :nothing
  end
  
  def check_value_type value
    unless is_constant(value) or value.is_a?(Condition)
      raise "Error: value must be either a constant or a Condition"
    end
  end
  
  def is_constant value
    value.is_a?(Numeric) ||  value.is_a?(String) || 
      value.is_a?(Symbol) || value===true || value===false ||
      value.is_a?(Time) || value.is_a?(Date)
  end
  
end


class PredicateInstance
  
  attr_reader :predicate, :step
  
  def initialize predicate, step
    @predicate = predicate
    @step = step
  end

  def == other
    @predicate==other.predicate && holds?(other.step.bindings[p])
  end
  
  def holds? bindings
    @predicate.parameters.all?{|p| @step.bindings[p]==bindings[p]}
  end
  
  def argValues
    @predicate.parameters.each{|p| @step.bindings[p]}
  end

  def set_vars step
    @predicate.parameters.each{|p| 
      step.bindings.bind(p, @step.bindings[p]) if @step.bindings.set? p
    }
  end
  
  def inverse
    PredicateInstance.new @predicate.inverse, @step      
  end
  
  def to_s
    (@predicate.positive ? "" : "!") + @predicate.name + 
      "("+ @predicate.variables.map{|v| @step.bindings[v]}.join(',')+")"
  end
  
end


class Step
  attr_reader :operator, :bindings, :sid
  
  @@id_counter=1
  
  def initialize operator, id=nil
    @operator = operator
    @bindings = Bindings.new @operator
    @links = {}
    if id.nil?
      @sid = @@id_counter
      @@id_counter += 1
    else
      @sid=id
    end
  end

  def satisfied?
    first_not_met_condition==nil
  end
  
  #whether this step causes 'effect' which is a PredicateInstance
  def effects? condition
    effect_for(condition) != nil
  end
  
  # finds and returns an effect which meets the specified condition
  # returns nil if none such exists
  # TODO later extend to return a set of effects which may be   
  def effect_for condition
    @effects.find{|eff| 
      eff==condition.predicate && condition.holds?(@bindings)
    }
  end
  
  def first_not_met_condition
    c = @operator.preconditions.find{|pre|
      ! (@links.has_key? pre)
    }
    Precondition.new(c, self) unless c.nil?
  end
  
  def add_fact name, values, positive
    vars = []
    values.each_with_index do |value,index|
      arg_name = "$arg" + @bindings.size.to_s
      vars << arg_name
      @bindings.introduce arg_name, value        
    end
    Predicate.new name, vars, positive    
  end
  
  def add_precondition name, values, positive
    @operator.preconditions << add_fact(name, values, positive)
  end

  def add_effect name, values, positive
    @operator.effects << add_fact(name, values, positive)
  end
  
  def to_s
    "Step #{@sid}: " + @operator.name + "(" + 
      @operator.parameters.map{|p| @bindings.set?(p) ? @bindings.get_value(p) : "?#{p}"}.join(',')+")"
  end
  
  def add_link link
    @links[link.condition.predicate] = link
  end
  
  def remove_link condition
    @links.delete(condition.predicate)
  end
end
  
  


#class Plan
#  def initialize(start, finish)
#    @steps = [start, finish]
#    @links = []
#    @orderings = [[start,finish]]
#  end
#end




class Link
  
  # S initial --> PredicateInstance(step, predicate)
  
  attr_reader :initial, :condition
  
  def initialize initial, condition
    @initial = initial
    @condition = condition
    @resolved_threats = []
  end
  
  def resolved_threat? step
    @resolved_threats.include? step
  end
  
  def add_resolved_threat step
    @resolved_threats << step
  end
  
  def to_s
    "Step #{@initial.id}--(#{@condition})-->Step #{@condition.step.id}"
  end
  
end




#==============NOTES
# sort operators by precondition size/complexity


class Planner
  
  def initialize operators, start, finish
    @operators = operators # all applicable operators
    @start = start
    @finish = finish
    @step=0
  end
  
  def reset
    @steps = [] # steps currently in the plan
    @orderings = Orderings.new # Si > Sj,  stores pairs as [Si, Sj]
    @links = {}    # Si -(c)-> Sj  : key:c, value:Link(Si, c, Sj)
    @unresolved_steps=[]
    @current_unresolved_step = 0
  end
  
  
  def find_plan 
    reset          
    #make minimal plan
    @steps << @start << @finish
    add_ordering @start, @finish
    @unresolved_steps << @finish
    
    dump
    
    @step = 0
    
    if new_iteration
      puts "****** FOUND A PLAN! ********"
      dump    
    end
  end
  
  def new_iteration
    
    @step +=1
     
    dump
    
    unless solution?
      condition = select_subgoal #plan
      choose_operator condition #plan, operators
#      resolve_threats #plan
#      #if resolve_threats fails and choose_operator returned an existing operator
#      #then it might be that a solution would be to create a new step an place
#      #it before the one which wants the "condition" to be satisfied
    else
      true
    end
  end
  
  def dump
      puts "===== Dumping step #{@step} ===="
      puts "Steps:"
      @steps.sort{|a,b| a.sid<=>b.sid}.each do |st|
        puts st  
      end
      puts "Links:"
      @links.each do |key,link|
        puts link
      end
      @orderings.dump
  end
  
  
  def select_subgoal
    #pick a plan step Sneed from STEPS(plan)
    #with a precondition c that has not been achieved
    
    #step = @steps.find{ |st| !st.satisfied? }
    #return step.first_not_met_condition
    
    unless @current_unresolved_step>=@unresolved_steps.size
      step = @unresolved_steps[@current_unresolved_step]
      step.first_not_met_condition
    else
      nil
    end
    
  end
  
  def choose_operator condition

    #choose a step Sadd from operators or STEPS(plan) that has c as an effect
    ## first check existing steps
    s = @steps.find do |st| 
      if st.effects? condition 
        link = add_link st, condition
        begin
          version = add_ordering st, condition.step
          resolve_threats
        rescue OrderingsException
          invalidate_link link
          restore_ordering version
          false
        else
          new_iteration #returns true on succeeds
        end 
      else
        false
      end
    end

    if s.nil?
      op=@operators.find{ |op| 
        if op.achieves? effect 
        
          new_step = Step.new op
          condition.set_vars new_step
          version = add_ordering @start, new_step
          add_ordering new_step, @finish
          #add the causal link Sadd —(c)-> Sneed to LINKS(plan)
          link = add_link new_step, condition
          #add the ordering constraint Sadd ~< Sneed to ORDERiNGS(plan)
          begin
              add_ordering new_step, condition.step
              resolve_threats
          rescue OrderingsException
            invalidate_link link
            restore_ordering version
            false
          else
            new_iteration #returns true if succeeds
          end 
        else
          false  
        end  
      }
    end    
    
#    op = find_operator_by_effect condition.predicate
#    #if there is no such step then fail
#    if op.nil?
#      raise "Can't find an operator to satisfy #{condition.predicate}"
#    end
#
#    # === do this inside add_step, first consider existing steps
#    # === if not hit, add a new one
#    #if Sadd is a newly added step from operators then
#    #     add Sadd to STEPS(plan)
#    #     add Start -< Sadd -< Finish to ORDERINGS( plan)
#    new_step = Step.new op
#    condition.set_vars s
#    add_ordering [@start, s]
#    add_ordering [s, @finish]
#    #add the causal link Sadd —(c)-> Sneed to LINKS(plan)
#    add_link new_step, condition
#    #add the ordering constraint Sadd ~< Sneed to ORDERiNGS(plan)
#    add_ordering new_step, condition.step
  end
  
  def resolve_threats
    #for each Sthreat that threatens a link Si-(c)->Sj in LlNKS(plan)
    @steps.each{|step|
        @links.each{|key, link|
          # resolved_threat? should be faster, so check it first
          unless link.resolved_threat? step
            if threatens? step, link  
              si, sj = link.initial, link.result
              
              #choose either
              #     Promotion: Add step -< si to ORDERlNGS(plan)
              #     Demotion: Add sj -< step to ORDERINGS(plan)
              #TODO randomise or add euristics which determine whether promostion
              # or demotion to try first
              promotion = true
              begin
                if promotion
                  add_ordering step, si
                else
                  add_ordering sj, step                
                end
              rescue OrderingsException
                if promotion
                    promotion = false
                    retry
                else
                    #if not CONSISTENT(plan) then fail
                    ## re-raise OrderingException so that it is
                    ## properly handled upper on the call stack
                    raise ####"Can't order step #{step} so that it does not threaten link #{link}"                  
                end
              else
                link.add_resolved_threat step
              end
            end
          end
        }
    }
  end
  
  def threatens? step, link
    step.effects? link.condition.inverse
  end

  # creates a new link and returns it 
  def add_link step, condition
    # need to review whether we need links as a has table of this kind
    link = Link.new(step, condition)
    @links[condition] = link
    condition.step.add_link link
    link
  end
  
  # removes the link from the list of active links
  # puts the bindings of the link into unsuccessful bindings
  # for the resuslt step only 
  def invalidate_link link
    @links.delete(link.condition)
    
  end
  
  # returns version of orderings 
  # which was current right before adding this ordering
  def add_ordering step1, step2
    ver = @orderings.cur_version
    @orderings.add step1, step2
    ver
  end
  
  def restore_ordering version
    @orderings.revert_to version
  end

  
  def find_operator_by_effect effect
    @operators.find{ |op| op.achieves? effect }
  end
  
  
  def solution?
    #== check complete
    #A complete plan is one in which every precondition of every step is achieved by some
    # other step.
    #== check consistent
    select_subgoal==nil && plan_consistent? 
  end

#  This is controlled by ordering automatically  
  def plan_consistent?
    # A consistent plan is one in which there are no 
    #contradictions in the ordering or binding
    #constraints. A contradiction occurs when both Si-< Sj and Si>-Sj,- hold or
    # both v = A and v = B hold (for two different constants A and B). 
    # Both -< and = are transitive, so, for example, a plan
    #with Si -< S2, S2 -< S3, and S3 -< Si is inconsistent.

    true  
  end
  
end


## TODO 

## (1) Store in bindings unsuccessful values as well 
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



end #of-module