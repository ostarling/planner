
#require File.join(File.dirname(__FILE__), 'step.rb')
#require File.join(File.dirname(__FILE__), 'link.rb')
#require File.join(File.dirname(__FILE__), 'ordering.rb')



module Planning

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
      @current_unresolved_step_idx = 0
    end
    
    
    def find_plan max_steps=9999
      reset          
      @max_steps = max_steps
      #make minimal plan
      @steps << @start << @finish
      add_ordering @start, @finish
      @unresolved_steps << @finish
      
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
          unless new_step.nil?
            add_ordering @start, new_step
            add_ordering new_step, @finish
          end
          add_ordering step, condition.step
          resolve_threats
      rescue OrderingException
        restore_plan link, version, new_step
        false
      else
        move_next = condition.step.satisfied?
        @current_unresolved_step_idx += 1 if move_next
        res = deepen_plan #returns true if succeeds
        unless res
          @current_unresolved_step_idx -= 1 if move_next  
          restore_plan link, version, new_step
        end
        res
      end 
    end
      
    
    def satisfy_condition condition
      
      step = satisfy_with_existing_step(condition) 
      
      unless step.nil?
        puts "Satisified with an existing step:  #{condition} with #{step}"
        true
      else
        step = satisfy_partially_with_existing_step(condition)
        unless step.nil?
          puts "Satisified with an existing step partially:  #{condition} with #{step}"
          true
        else
          step = satisfy_with_new_step(condition)
          unless step.nil?
            puts "Satisified with a NEW step: #{condition} - #{step}"
            true
          else
            puts "Could not satisfy #{condition}"
            false
          end
        end
      end
    end
    
    def resolve_threats
      
      puts "Resolving threats..."
      #for each Sthreat that threatens a link Si-(c)->Sj in LlNKS(plan)
      @steps.each{|step|
          @links.each{|key, link|
            # resolved_threat? should be faster, so check it first
            unless link.resolved_threat? step
              if threatens? step, link
                
                puts "Resolving threat to #{link} by #{step}"
                  
                si, sj = link.initial, link.condition.step
                
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
                rescue OrderingException
                  if promotion
                      puts "Promotion failed, trying demotion"
                      promotion = false
                      retry
                  else
                      puts "Could not resolve threat to #{link} by #{step}"
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
    
    def threatens? step, link
      unless link.initial==step || link.condition.step==step
        step.effects? link.condition.inverse
      else
        false
      end
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