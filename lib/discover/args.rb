require 'set'
require 'pp'
XMETHODS = Hash.new {|h,k| h[k] = Set.new}

class Class
  
  class_exec do
    alias_method :orig_define_method, :define_method
  
    def define_method(symbol, *args, &block)
      XMETHODS[self] << symbol
      
      orig_define_method(symbol, *args, &block)
    end
  end
end

module Discover
  module Args
    def self.trace(klass)
      klass.class_exec do
        include Discover::Args
      end

      at_exit do
        puts "Class: #{klass}"
        klass.__collector.each do |meth, param_sets|
          param_sets.each_pair do |args, klasses|
            ret = args.pop
            puts "\t:#{meth}\t(" + args.join(", ") + ") -> " + ret.to_s + "\t (" + klasses.to_a.join(", ") + ")"
          end
        end
      end
    end
    
    
    def self.included(base)
      pp [base, ::XMETHODS[base]]
      base.class_exec do
        
        def self.__collector
          if @__collector.nil?
            @__collector = Hash.new {|h,k| h[k] = Hash.new {|h,k| h[k] = Set.new }}
          end
          @__collector
        end
      end
      
      methods = base.instance_methods(true) - Class.instance_methods(true)
      
      short_name = base.name.downcase.gsub(/:/, '_')
      
      methods.each do |meth|
        next if meth =~ /^xxorig_/
        orig_meth = :"xxorig_#{short_name}_#{meth}"
        base.class_exec do
          alias_method orig_meth, meth.to_sym
          
          define_method(meth) do |*args, &block|
            ret = send(orig_meth, *args, &block)
            
            # if self.class.__tracing == true
              r = ret.class
              if ret.is_a? ::Array
                r = ret.map {|x| x.class}
              end
              self.class.__collector[meth][[args.map {|x| x.class}, r]] << self.class
            # end
            
            return ret
          end
        end
        
      end
      
    end
  end
end