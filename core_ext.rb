#!/usr/bin/env ruby
require 'facets/file/write'
require 'facets/enumerable/collect'
class Object
  def common_methods
    7.methods + "".methods + 7.class.methods + "".class.methods + ActiveRecord::Base.instance_methods
  end
  def uniq_methods
    (methods - common_methods).sort
  end
  def uniq_instance_methods(include_ar=true)
    (instance_methods - common_methods - superclass.instance_methods - uniq_modules.map { |x| x.instance_methods }.flatten + (include_ar ? ar_methods : [])).sort
  end
  def uniq_modules
    included_modules - superclass.included_modules
  end
  def ar_methods
    return [] unless inherits_from?(ActiveRecord::Base)
    columns.map { |x| x.name }.map { |x| [x,"#{x}="] }.flatten
  end
  def inherits_from?(x)
    return true if superclass == x
    return false unless superclass
    superclass.inherits_from?(x)
  end
end


class Object
  def tap
    yield(self)
    self
  end
end
class Hash
  def summary
    keys.sort_by { |x| x.to_s }.map { |k| "#{k}: #{self[k]}" }.join("\n")
  end
end


class Class
  def cond_accessor(*names)
    names.flatten.each do |name|
      define_method(name) do |*args|
        instance_variable_set("@#{name}",args.first) unless args.empty?
        instance_variable_get("@#{name}")
      end
    end
  end
end      

class Object
  def klass
    self.class
  end
end

def eat_exceptions
  yield
rescue
  return nil
end

class Object
  def from_hash(ops)
    ops.each { |k,v| send("#{k}=",v) unless (v == :UNSET_FIELD) }
    self
  end
end

class Class
  def from_hash(ops)
    new.from_hash(ops)
  end
end

class Object
  def lazy_method(sym,&b)
    send(:define_method,sym) do
      instance_variable_set("@#{sym}",instance_eval(&b)) if instance_variable_get("@#{sym}").nil?
      instance_variable_get("@#{sym}")
    end
  end
end

class Object
  #attr_accessor :system
end

def log(x)
  puts x
  File.append(File.dirname(__FILE__) + "/output.log",x.to_s+"\n")
end

def debug(x)
end

class WIN32OLE
  include Enumerable
  def first
    each { |x| return x }
  end
  def size
    self.Count
  end
  def pruned_methods
    ole_methods.map { |x| x.to_s.gsub(/\d/,"") }.uniq.sort
  end
end

module ForwardableExtension
  def delegate_to(object, new_method, *args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    args.each do |element|
      def_delegator object, element, new_method.to_sym
      if options[:writer]
        def_delegator object, :"#{element}=", :"#{new_method}="
      end
    end
  end
  
  protected
  def name_with_prefix(element, options)
    "#{options[:prefix] + "_" unless options[:prefix].nil? }#{element}"
  end
end

require 'forwardable'
Forwardable.send :include, ForwardableExtension

module Enumerable
  def propagate_to!(target)
    each { |x| x.propagate_to!(target) }
  end
end

def tm(str,num=1)
  t = Time.now
  res = nil
  num.times { res = yield }
  sec = Time.now - t
  puts "#{str} took #{sec} seconds (#{res})"
end

class Object
  def to_is
    self ? to_i.to_s : nil
  end
end

class Object
  def nvl(x)
    self || x
  end
end