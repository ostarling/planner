







f1 = Fact.new(:on, :A, :B)

kb = KnowledgeBase.new

kb.add(f1)
kb.define :on, :C, :D
kb.define :clear, :D

a = Autodef.new(kb)
a.on :F, :T

kb.print


