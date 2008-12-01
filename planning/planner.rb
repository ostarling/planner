
#require File.join(File.dirname(__FILE__), 'step.rb')
#require File.join(File.dirname(__FILE__), 'link.rb')
#require File.join(File.dirname(__FILE__), 'ordering.rb')



module Planning

  class Planner

    # The planner maintains a list of unresolved steps (steps which do not have links for all their preconditions)
    # Initially it contains the GOAL step. Newly created steps are added to the end of this list; this
    # results in width-first plan search.
    # Matching precondition search (starts in satisfy_condition method) is optimised in the following way
    #  1. first it searches in steps which are aleady ordered to be _before_ the current step
    #     directly or indirectly (due to transitivity of ordering). This set of steps is beneficial
    #     as no new oredering constrains have to be created if a suitable step is found. During the 
    #     traversal all these steps are collected in a set which will be used in step 3. 
    #  2. all steps which are ordered _after_ (again directly and indirectly) the current steps are
    #    collected into a set of exclude nodes, as these are the nodes which can't be reordered 
    #    to precede the current step.
    #  3. it searches in unrelated steps; it iterates through a global list of steps and exludes already
    #   seen _before_ and _after_ steps. Steps will be processed starting from older ones. (This feels to be 
    #   better than the reversed order, no claims though).
    #
    #  For simple predicate match this search is done in 2 passes. The first one is used for compelte match
    #  the second one for the incomplete. The second pass may use already created node lists for steps 1 and 2
    #  instead of traversing the orderings graph. When resolving threats the steps in _after_ can be safely ignored
    # 
    #  For existential constraints (e.g. !E x: ON(A,x))the search is done similarly - first in _before_ 
    #  set and then in unrelated steps (after building the _after_ set, of course). The search algorithm 
    # locates steps which: 
    #   * (type A, threat steps) effect a predicate which breaks the current non-existential precondition 
    #     (e.g. ON(A,B)). These steps must be either reordered to be after the current step, or must be 
    #     "screened" with a step which neutralises the unwanted predicate
    #   * (type B, protective steps) effect a not-predicate (e.g. !ON(A,B)), which can be used for screening 
    #     (e.g. for ON(A,B)) as it neutralises any earlier positive predicates with the same set of parameters. 
    #     For all steps which are _before_ this step these positive predicate effects are ignored. This is done 
    #     by maintaining a current effective filter of screening predicates.
    # The goal of satisfying an existential constraint is netralising all A-steps. This is done in the following
    # way. (in all cases B-steps are first searched in _before_ set, then in unrelated set).
    #   1. A-steps in _before_ set can't be reordered, so for them a B-step is searched first in
    #       _before_ set, then in unrelated set. If none can be found a new protective step is created
    #   2. For A-steps in unrelated set reordering is attempted first. Then B-steps are searched in
    #        _before_ set, then in unrelated set. If none can be found a new protective step is created
    #  Once all A-type steps are screened the contraint is satisfied.
     
    
    attr_reader :operators
    
    def initialize operators, start, finish
      @operators = operators # all applicable operators
      @start = start
      @finish = finish
      @step=0
    end
    
    def reset
      # steps currently in the plan,
      #make minimal plan
      @steps = [@start, @finish]
      # Si > Sj,  stores pairs as [Si, Sj]
      # init orderings
      @orderings = Orderings.new  @start, @finish 
      # Si -(c)-> Sj  : key:c, value:Link(Si, c, Sj)
      @links = {}    
      
      @unresolved_steps=[@finish]
      @current_unresolved_step_idx = 0
    end
    
    
    def find_plan max_steps=9999
      reset          
      @max_steps = max_steps
      
      dump
      
      @step = 0
      
      if deepen_plan
        puts "****** FOUND A PLAN! ********"
        dump
        puts "****** FOUND A PLAN! ********"
      else
        puts ">>>>>>>>>>>>> Latest state:"
        dump
        puts "<<<<<<<< SORRY, COULD NOT FIND A PLAN, I'M TOO STUPID YET >>>>>>>>>>>>>>"
            
      end
    end
    
    def deepen_plan
      
      @step +=1
      
      if @step > @max_steps
          return false        
      end
       
      dump
      
      condition = select_subgoal #plan
      unless condition.nil?
        satisfy_condition condition #plan, operators
  #      resolve_threats #plan
  #      #if resolve_threats fails and satisfy_condition returned an existing operator
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
        puts "Unresolved conditions:"
        i=@current_unresolved_step_idx
        while i < @unresolved_steps.size() do
          step = @unresolved_steps[i]          puts "?? #{step}: " +
            step.not_met_conditions.join(", ")
          i += 1
        end
        @orderings.dump
    end
    
    
    def get_current_step
      step = @unresolved_steps[ @current_unresolved_step_idx ]
      
    end
    
    def select_subgoal
      #pick a plan step Sneed from STEPS(plan)
      #with a precondition c that has not been achieved
      
      #step = @steps.find{ |st| !st.satisfied? }
      #return step.first_not_met_condition
      
      unless @current_unresolved_step_idx>=@unresolved_steps.size
        step = @unresolved_steps[ @current_unresolved_step_idx ]
        #sanity check
        cond = step.first_not_met_condition
        if cond.nil? && @current_unresolved_step_idx < @unresolved_steps.size
          raise "Error! We are returnning null, but there are more unresolved steps"
        end
        p "Subgoal: #{cond}"
        cond
      else
        nil
      end
      
    end
    
    
    def restore_plan link_to_delete, ordering_version_to_restore, added_step=nil
      invalidate_link link_to_delete
      restore_ordering ordering_version_to_restore
      unless added_step.nil?
          if @steps[-1]==added_step 
            @steps.pop
          else
            raise "Unexpected element in @steps, last element should have matched #{added_step}"            
          end        
          if @unresolved_steps[-1]==added_step
            @unresolved_steps.pop
          else
            raise "Unexpected element in @unresolved_steps, last element should have matched #{added_step}"            
          end
      end
    end
    
  
    def satisfy_with_existing_step condition
      
      #choose a step Sadd from operators or STEPS(plan) that has c as an effect
      step = @steps.find do |st| 
        if st.effects? condition 
          puts "Trying #{st} with complete match"
          link = add_link st, condition
          satisfy_check_and_deepen st, condition, link
        else
          false
        end
      end
      
      step
    end
    
    
    def satisfy_partially_with_existing_step condition
      
      #choose a step Sadd from operators or STEPS(plan) that has c as an effect
      step = @steps.find do |st|
        eff = st.partial_effect_for condition
        unless eff.nil?
          puts "Trying #{st} with partial match of #{eff}"
          
          #first create a link, this will also mark current versions of the steps          
          link = add_link st, condition
          #now add missing bindings to the cause(source) step
          condition.assign_missing_bindings st, eff

          satisfy_check_and_deepen st, condition, link
        else
          false
        end
      end

      step
        
    end
      
    
    def satisfy_with_new_step condition
      
      step = nil
      
      op=@operators.find do |op| 
        
        p "Nil predicate! #{condition.inspect}" if condition.predicate.nil?
         
        eff = op.effect_for condition.predicate
        unless eff.nil?
          
          puts "Trying new operator #{op} with effect #{eff}"
          
          step = Step.new op
          @steps << step
          @unresolved_steps << step

          #first create a link, this will also mark current versions of the steps          
          link = add_link step, condition
          condition.assign_missing_bindings step, eff
          
          if satisfy_check_and_deepen step, condition, link, step
            return step
          else
            false
          end
        else
          false  
        end  
      end
      
      nil
    end
    
    def satisfy_check_and_deepen step, condition, link, new_step=nil
      begin
          version = @orderings.cur_version if version.nil?
#         TODO check that we do not rely on these orderings any more          
#          unless new_step.nil?
#            add_ordering @start, new_step
#            add_ordering new_step, @finish
#          end
          add_ordering step, condition.step
          resolve_threats
      rescue OrderingException
        restore_plan link, version, new_step
        return false
      else
        move_next = condition.step.satisfied?
        @current_unresolved_step_idx += 1 if move_next
        res = deepen_plan #returns true if succeeds
        unless res
          @current_unresolved_step_idx -= 1 if move_next  
          restore_plan link, version, new_step
        end
        return res
      end 
    end
      
    
    def satisfy_condition condition
        case condition
        when PredicateInstance: satisfy_predicate_condition condition
        when ExistentialConstraintInstance: satisfy_existential_constraint condition 
        else raise 
        end      
    end
      
    def satisfy_predicate_condition condition 
      
      step = satisfy_with_existing_step(condition) 
      
      unless step.nil?
        puts "Satisified with an existing step:  #{condition} with #{step}"
        return true
      end
      
      step = satisfy_partially_with_existing_step(condition)
      unless step.nil?
        puts "Satisified with an existing step partially:  #{condition} with #{step}"
        return true
      end
      
      step = satisfy_with_new_step(condition)
      unless step.nil?
        puts "Satisified with a NEW step: #{condition} - #{step}"
        return true
      end
      
      puts "Could not satisfy #{condition}"
      return false
    end
    
    
    def satisfy_existential_constraint constraint
      constraint.step
      constraint.predicate
            
    end
    
    
    def resolve_threats
      
      puts "Resolving threats..."
      #for each Sthreat that threatens a link Si-(c)->Sj in LINKS(plan)
      @steps.each{|step|
          @links.each{|key, link|
            # resolved_threat? should be faster, so check it first
            unless link.resolved_threat? step
              if link.threatend_by? step
                
                puts "Resolving threat to #{link} by #{step}"
                  
                si, sj = link.initial, link.condition.step
                
                #choose either
                #     Promotion: Add step -< si to ORDERlNGS(plan)
                #     Demotion: Add sj -< step to ORDERINGS(plan)
                #TODO randomise or add euristics which determine whether promostion
                # or demotion to try first
                promotion = rand(2)==1 ? true : false
                first_time = true
                begin
                  if promotion
                    puts "Trying promotion..."
                    add_ordering step, si
                  else
                    puts "Trying demotion..."
                    add_ordering sj, step                
                  end
                rescue OrderingException
                  if first_time
                      first_time = false
                      puts "...failed, trying the opposite option"
                      promotion = !promotion
                      retry
                  else
                      puts "...failed. Could not resolve threat to #{link} by #{step}"
                      #if not CONSISTENT(plan) then fail
                      ## re-raise OrderingException so that it is
                      ## properly handled upper on the call stack
                      raise ####"Can't order step #{step} so that it does not threaten link #{link}"                  
                  end
                else
                  puts "Threat resolved."
                  link.add_resolved_threat step
                end
              end
            end
          }
      }
      puts "Resolved all current threats"
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
      link.detach_and_revert
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
    
    
#    def solution?
#      #== check complete
#      #A complete plan is one in which every precondition of every step is achieved by some
#      # other step.
#      #== check consistent
#      select_subgoal==nil && plan_consistent?
#    end
  
#  #  This is controlled by ordering automatically  
#    def plan_consistent?
#      # A consistent plan is one in which there are no 
#      #contradictions in the ordering or binding
#      #constraints. A contradiction occurs when both Si-< Sj and Si>-Sj,- hold or
#      # both v = A and v = B hold (for two different constants A and B). 
#      # Both -< and = are transitive, so, for example, a plan
#      #with Si -< S2, S2 -< S3, and S3 -< Si is inconsistent.
#  
#      true  
#    end
  end  
end