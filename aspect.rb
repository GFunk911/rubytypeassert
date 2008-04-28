#!/usr/bin/env ruby
require 'ostruct'

class MethodRuns
  attr_accessor :method_name, :method_class
  def initialize(c,n)
    @method_name = n.to_s
    @method_class = c.to_s
  end 
  #:return: => Object
  def runs
    @runs ||= []
  end 
  def log_run!(r)
    raise 'wrong' unless method_name == r.method_name.to_s and method_class = r.method_class.to_s
    runs << r
  end 
  #:return: => Object
  def arg_classes
    runs.map { |r| r.args.map { |x| x.class } }.uniq
  end 
  def return_classes
    runs.map { |r| r.return.class }.uniq
  end 
  #:return: => Object
  def to_s
    "#{method_class} / #{method_name}"
  end 
  #:return: => Object
  def summary
    "#{method_class}##{method_name}, returns: #{return_classes.inspect}, args: #{arg_classes.inspect}"
  end 
  #:return: => Object
  def self.run_hash
    @run_hash ||= Hash.new { |h,k| h[k] = new(*k) }
  end 
  #:return: => Object
  def self.runs
    run_hash.values
  end 
  #:return: => Object
  def self.log_run!(r)
    run_hash[[r.method_class.to_s,r.method_name.to_s]].log_run!(r)
  end 
  #:return: => Object
  def self.get(c,n)
    run_hash[[c.to_s,n.to_s]]
  end 
end
  
def add_advice!(*advised_classes)
  require 'aquarium'
  advised_classes.flatten.each do |cls|
    Aquarium::Aspects::Aspect.new :around, :calls_to => cls.uniq_instance_methods, :on_types => cls do |jp, object, *args|
      #p "Entering: #{join_point.target_type.name}##{join_point.method_name} for object #{object}"
      result = jp.proceed
      #p "Leaving: #{join_point.target_type.name}##{join_point.method_name} for object #{object}"
      MethodRuns.log_run! OpenStruct.new(:method_class => jp.target_type.name, :method_name => jp.method_name, :args => args, :return => result)
      result  # block needs to return the result of the "proceed"!
    end
  end
end

at_exit do 
  File.create("method_runs.txt",MethodRuns.runs.map { |x| x.summary }.join("\n"))
end
  