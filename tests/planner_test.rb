
require File.join(File.dirname(__FILE__),'../planning')

parser = Planning::Parser.new
#planner = parser.parse_task "task01.xml"
planner = parser.parse_task "task02.xml"

planner.operators.each{|o| p o.dump }

#planner.find_plan 

