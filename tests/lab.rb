

class Lab
  attr_accessor :val
  def initialize val
    @val=val
  end  
end

class Lab2 < Lab
    def initialize val1, val2
        super val1
        @val2 = val2      
    end  
end




a = [ Lab.new('a')]

b = Lab2.new 'a', 'b'
  
p b

p a

s = 'sd'

p( [s] * 5 )

p( [nil] * 5 )

p ([1,2,3] + [4,5])

ar1 = [1,2,3]

ar1 << [nil] * 3

p ar1

p a.type

p "asd".class
 
p "asd".class==String
 
#def check_types map
#    map.each do |argument, type |
#      unless argument.nil?
#        if argument.class!=type
#         raise "Invalid type, expected type: #{type}, received instance #{argument.inspect}" 
#        end        
#      end
#    end    
#end


#check_types "sf"=>String
#check_types nil=>String
#check_types Lab.new(34)=>String

