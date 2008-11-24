
require File.join(File.dirname(__FILE__),'../planning')

parser = Planning::Parser.new
#planner = parser.parse_task "task01.xml"
planner = parser.parse_task "task02.xml"

planner.find_plan 

