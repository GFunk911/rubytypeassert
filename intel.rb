#!/usr/bin/env ruby
class Object
  def lazy_method(sym,&b)
    send(:define_method,sym) do
      instance_variable_set("@#{sym}",instance_eval(&b)) if instance_variable_get("@#{sym}").nil?
      instance_variable_get("@#{sym}")
    end
  end
end

class OS
  def each(&b)
    ObjectSpace.each_object(&b)
  end
  include Enumerable
  def self.method_missing(sym,*args,&b)
    new.send(sym,*args,&b)
  end
end

def current_classes
  OS.select { |x| x.is_a?(Class) }.uniq
end

def local_class_names
  $local_class_names ||= Dir["**/*.rb"].map do |filename|
    File.new(filename).read.scan(/^\s*class (\S+)(?: |$)/).flatten
  end.flatten.map { |x| x.split(":")[-1] }.sort
end

def init_classes
  $init_classes ||= current_classes
end

def generate_local_class_defs!(req_file)
  init_classes
  load req_file
  str = local_class_defs.map { |x| x.class_str }.join("\n")
  File.create("local_class_defs.rb",str)
end 

def local_class_defs
  $local_class_defs ||= (current_classes - init_classes).select { |x| local_class_names.include?(x.to_s.split(":")[-1]) }.map { |x| ClassDef.new(x) }
end 

class String
  def prefix_each_line(pre)
    pre + self[0..-2].gsub(/\n/,"\n#{pre}") + self[-1..-1]
  end
end

module DefModule
  def modules
    cls.to_s.split(":")[0..-2].select { |x| x != '' }
  end
  def class_spaces
    " "*2*modules.size  
  end
end

class ClassDef
  include DefModule
  attr_accessor :cls
  def initialize(c)
    @cls = c
  end
  def bare_cls
    cls.to_s.split(':')[-1]
  end
  def class_str
    str = ''
    modules.each_with_index { |x,i| str << " "*i*2 + "module #{x}\n" }
    str << class_spaces + "class #{bare_cls}"
    str << " < #{cls.superclass}" unless [Object,nil].include?(cls.superclass)
    str << "\n"
    cls.uniq_modules.each { |x| str << "#{class_spaces}  include #{x}\n" }
    str << methods_str
    str << class_spaces + "end\n"
    modules.each_with_index { |x,i| str << " "*i*2 + "end\n" }
    str
  end
  lazy_method(:methods) do
    cls.uniq_instance_methods.map { |x| MethodDef.new(cls,x) }
  end
  def methods_str
    methods.map { |x| x.method_str }.join("")
  end
end

class MethodDef
  include DefModule
  attr_accessor :cls, :name
  def initialize(c,n)
    @cls = c
    @name = n.to_s.downcase
  end
  def method_obj
    eat_exceptions { cls.instance_method(m) }
  end
  def arity
    method_obj ? method_obj.arity : 0
  end
  def arg_str
    (0...arity).map { |x| ("a"[0]+x).chr }.join(",")
  end
  def manual_method_str
    str =  "#{class_spaces}  # manual meth def\n"
    str << "#{class_spaces}  def #{name}(#{arg_str})\n"
    str << "#{class_spaces}  end\n"
    str
  end
  def runs
    MethodRuns.get(cls,name)
  end
  def return_type
    runs.return_classes.flatten.first || Object
  end
  def type_comments
    "#{class_spaces}  #:return: => #{return_type}\n"
  end
  lazy_method(:method_body) do
    eat_exceptions { RubyToRuby.translate(cls,name).prefix_each_line(class_spaces+"  ") + "\n" } || manual_method_str
  end
  def arg_names 
    return [] if method_body.strip =~ /^attr_/
    arg_str = method_body.scan(/def.*#{name}(.*)$/).flatten.first
    raise "no arg_str for #{cls} #{name} /def.*#{name}(.*)$/" unless arg_str
    return [] if arg_str.strip == '' or arg_str.strip == '()'
    arg_str[1..-2].split(",")
  end
  def arg_type(i)
    (runs.arg_classes[i]||[]).first || Object
  end
  def arg_comments
    arg_names.map_with_index do |arg,i| 
      "#{class_spaces}  #:arg: #{arg} => #{arg_type(i)}\n" 
    end.join("")
  end
  def method_str
    type_comments + arg_comments + method_body
  end
end

def rta_run!(req_file)
  require 'ruby2ruby'
  generate_local_class_defs!(req_file)
  add_advice!(ActiveRecord::Base)
  generate_local_class_defs!(req_file)
end