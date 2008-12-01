
require 'hpricot'
#require File.join(File.dirname(__FILE__),'operator.rb')
#require File.join(File.dirname(__FILE__),'step.rb')
#require File.join(File.dirname(__FILE__),'planner.rb')

module Planning
  
class Parser

  def initialize 
  end
  
  
  def parse_arguments args
    unless args.nil?
      args.split(',')
    else
      []      
    end
  end
  
  def parse_predicate_or_fact elem
    vars = parse_arguments elem[:arguments]
    positive = !(elem[:positive]=='false')
    name = elem[:name]
    if name.nil?
      raise "An predicate/fact must have @name"
    end
    [name, vars, positive]
  end
  
  def parse_predicate elem
    Predicate.new *(parse_predicate_or_fact(elem))
  end

  def parse_notexists elem
      args = parse_arguments elem[:vars]
      pred = parse_predicate((elem/"predicate")[0])
      ExistentialConstraint.new pred, args
  end
  
  def parse_effect elem
    parse_predicate elem
  end
    
  def parse_initial_fact elem, step
    step.add_effect *(parse_predicate_or_fact(elem))
  end
  
  def parse_goal_fact elem, step
    step.add_precondition *(parse_predicate_or_fact(elem))
  end
  
  
  def parse_operators filename
    operators = []
    doc = Hpricot.parse(File.read(filename))
    (doc/:operator).each do |xml_op|
      
      preconds_node = xml_op/:preconditions
      effects_node = xml_op/:effects

      preconds = (preconds_node/"predicate").collect{|n| parse_predicate n}
      preconds.push(*( (preconds_node/"not-exists").collect{|n| parse_notexists n}))
      effects = (effects_node/"predicate").collect{|n| parse_predicate n}
      args = parse_arguments xml_op[:arguments]
      name = xml_op[:name]
      
      if name.nil?
        raise "An operator must have @name"
      end
      
      operators << Operator.new(name, args, preconds, effects)

    end

    operators
  end
  
  
  def parse_state name, node, initial
    step = Step.new(Operator.new(name, [], [], []), (initial ? nil : 9999))   
    (node/"fact").each do |n|
      if initial
        parse_initial_fact n, step
      else
        parse_goal_fact n, step
      end  
    end
    step
  end
  
  def parse_task filename
    operators = []
    doc = Hpricot.parse(File.read(filename))
    (doc/:operators).each do |node|
      operators.push(* parse_operators(node[:file]))
    end
    
    initial = (doc/:initial).first
    goal = (doc/:goal).first
    
    start = parse_state "Initial", initial, true
    finish = parse_state "Goal", goal, false
    
    Planner.new(operators, start, finish)
  end
  
  
  
=begin
Sample operator definition:

[]+ === ()*   --- 0 or more
[] === (){0,1}  --- 0 or 1
()+           --- 1 or more


Operator ::= <NameWithArgs> ':'
( 'conditions:' ( <Predicate> )+ ){0,1}
( 'effects:' ( <Predicate> )+ ){0,1}
'end'

Predicate ::= (['NOT' | '!' ]){0,1} <NameWithArgs>
NameWithArgs ::= <Name> '(' <ArgList> ')' 
ArgList ::= (<Name> (','<Name>...)* ){0,1}

Name ::= Char CharNum*
Char ::= ['A'..'Z','a'..'z','_']
CharNum ::= ['A'..'Z','a'..'z','_','0'..'9']
 

=end
  

#  def parse filename
#    File.foreach(filename) do |line|
#      
#      next if line =~ /^#/  
#      parse(line) unless line =~ /^$/
#      
#      
#    end
#  end
#  
#  
#  
#  def parse_operator string
#    
#  end
  
end


end

