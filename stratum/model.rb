# -*- coding: utf-8 -*-

require 'mysql'

class Mysql
  class Time
    def addseconds(sec)
      t = ::Time.local(self.year, self.month, self.day, self.hour, self.minute, self.second)
      x = t + sec
      return Mysql::Time.new(x.year, x.month, x.day, x.hour, x.min, x.sec)
    end

    def +(sec)
      self.addseconds(sec)
    end
    def -(sec)
      self.addseconds(-1 * sec)
    end
    def <=>(other)
      self.to_i <=> other.to_i
    end
    def ==(other)
      (self <=> other) == 0
    end
    def >(other)
      (self <=> other) > 0
    end
    def >=(other)
      (self <=> other) >= 0
    end
    def <(other)
      (self <=> other) < 0
    end
    def <=(other)
      (self <=> other) <= 0
    end
  end
end

module Stratum
  class NotUniqueResultError < StandardError ; end
  class ConcurrentUpdateError < StandardError ; end

  class InvalidFieldName < StandardError ; end
  class InvalidFieldType < ArgumentError ; end
  class InvalidFieldDefinition < ArgumentError ; end

  class TooManyResultError < StandardError ; end

  class InvalidUpdateError < StandardError ; end

  class FieldValidationError < ArgumentError
    def initialize(msg, model=nil, field=nil)
      @model = model
      @field = field
      super(msg)
    end

    def model
      @model
    end
    def field
      @field
    end
  end
end

module Stratum
  def self.preload(models, cls)
    cls_oid_list = {}
    cls.fields.each do |f|
      fdef = cls.definition(f)
      next unless fdef
      next unless fdef[:datatype] == :ref or fdef[:datatype] == :reflist

      fcls = eval(cls.definition(f)[:model])
      unless cls_oid_list[fcls]
        cls_oid_list[fcls] = []
      end
      targets = []

      if fdef[:datatype] == :ref
        models.each do |m|
          oid = m.send(f.to_s + '_by_id')
          if oid
            targets.push(oid)
          end
        end
      else
        models.each do |m|
          oids = m.send(f.to_s + '_by_id')
          if oids.size > 0
            targets += oids
          end
        end
      end

      cls_oid_list[fcls] += targets
    end

    cls_oid_list.keys.each do |c|
      c.get(cls_oid_list[c])
    end
  end

  module ModelCache
    # DON'T USE THIS CACHE DIRECTLY FROM OUT OF THIS MODULE

    $STRATUM_MODEL_CACHE_BOX = {}
    
    EXPIRE_SECONDS = 15

    def self.get(oid)
      val = $STRATUM_MODEL_CACHE_BOX[oid]
      return nil if val.nil?

      if Time.now > val[1]
        $STRATUM_MODEL_CACHE_BOX.delete(oid)
        return nil
      end

      val[0]
    end

    def self.set(model)
      $STRATUM_MODEL_CACHE_BOX[model.oid] = [model, Time.now + EXPIRE_SECONDS]
    end

    def self.flush
      $STRATUM_MODEL_CACHE_BOX = {}
    end
  end
end

module Stratum
  class Model
    $STRATUM_MODEL_TABLENAMES = Hash.new
    $STRATUM_MODEL_FIELDS = Hash.new

    RESERVED_FIELDS_HEAD = [:id, :oid].freeze
    RESERVED_FIELDS_TAIL = [:inserted_at, :operated_by, :head, :removed].freeze
    RESERVED_FIELDS = (RESERVED_FIELDS_HEAD + RESERVED_FIELDS_TAIL).freeze

    FIELD_TYPES = [:bool, :string, :stringlist, :taglist, :ref, :reflist, :reserved].freeze
    BOOL_TRUE = '1'
    BOOL_FALSE = '0'
    REFLIST_SEPARATOR = ','

    TAG_SEPARATOR = ' ' # from MySQL Fulltext search index separator

    def self.tablename
      $STRATUM_MODEL_TABLENAMES[self]
    end

    def self.fields
      $STRATUM_MODEL_FIELDS[self][:fields].keys
    end

    def self.columns
      $STRATUM_MODEL_FIELDS[self][:fields].values
    end

    def self.exs
      return {} unless $STRATUM_MODEL_FIELDS[self][:exs]
      $STRATUM_MODEL_FIELDS[self][:exs]
    end

    def self.ex(fname)
      return nil unless $STRATUM_MODEL_FIELDS[self][:exs]
      $STRATUM_MODEL_FIELDS[self][:exs][fname.to_sym]
    end

    def self.field_by(column)
      result = $STRATUM_MODEL_FIELDS[self][:fields].key(column.to_s)
      raise InvalidFieldName, "unknown column: #{column.to_s} for class #{self.name}" unless result
      result
    end

    def self.column_by(field)
      result = $STRATUM_MODEL_FIELDS[self][:fields][field.to_sym]
      raise InvalidFieldName, "unknown field: #{field.to_s} for class #{self.name}" unless result
      result
    end

    def self.definition(field)
      if RESERVED_FIELDS.include?(field.to_sym)
        return nil
      end

      result = $STRATUM_MODEL_FIELDS[self][:defs][field.to_sym]
      raise InvalidFieldName, "undefined field: #{field.to_s} for class #{self.name}" unless result
      result
    end

    def self.datatype(field)
      if RESERVED_FIELDS.include?(field.to_sym)
        return :reserved
      end

      result = self.definition(field)[:datatype]
      raise InvalidFieldName, "datatype not defined: #{field.to_s} for class #{self.name}" unless result
      result
    end

    def self.ref_fields_of(cls)
      self.fields.select do |f|
        (self.datatype(f) == :ref or self.datatype(f) == :reflist) and
          eval(self.definition(f)[:model]) == cls
      end
    end

    def self.table(sym)
      $STRATUM_MODEL_TABLENAMES[self] = sym.to_s
      nil
    end

    def self.prepare_field_definition_stores
      if $STRATUM_MODEL_FIELDS[self].nil?
        $STRATUM_MODEL_FIELDS[self] = {}
      end
      if $STRATUM_MODEL_FIELDS[self][:fields].nil?
        $STRATUM_MODEL_FIELDS[self][:fields] = Hash[*(RESERVED_FIELDS.map{|f| [f, f.to_s]}.flatten)]
      end
      if $STRATUM_MODEL_FIELDS[self][:defs].nil?
        $STRATUM_MODEL_FIELDS[self][:defs] = {}
      end
      if $STRATUM_MODEL_FIELDS[self][:exs].nil?
        $STRATUM_MODEL_FIELDS[self][:exs] = {}
      end
    end

    def self.fieldex(fname, ex_s)
      self.prepare_field_definition_stores()
      $STRATUM_MODEL_FIELDS[self][:exs][fname.to_sym] = ex_s
    end

    def self.field(fname, type, opts={})
      self.prepare_field_definition_stores()

      if RESERVED_FIELDS.include?(fname.to_sym)
        raise InvalidFieldDefinition, "field #{fname.to_s} reverved by Stratum::Model"
      end
      raise InvalidFieldType, type.to_s unless FIELD_TYPES.include?(type)
      
      fdef = {:datatype => type}.merge(opts)
      if fdef[:column]
        $STRATUM_MODEL_FIELDS[self][:fields][fname.to_sym] = fdef.delete(:column).to_s
      else
        $STRATUM_MODEL_FIELDS[self][:fields][fname.to_sym] = fname.to_s
      end
      
      if fdef.has_key?(:empty)
        unless fdef[:empty] == :allowed or fdef[:empty] == :ok
          raise InvalidFieldDefinition, ":allowed or :ok only valid in field definition :empty"
        end
        fdef[:empty] = true
      end

      $STRATUM_MODEL_FIELDS[self][:defs][fname.to_sym] = fdef.freeze

      case type
      when :bool
        if fdef.has_key?(:empty)
          raise InvalidFieldDefinition, "not allowed option :empty with :bool field #{fname}"
        end
        unless fdef.has_key?(:default)
          raise InvalidFieldDefinition, "missing :default for :bool field #{fname}"
        end
        unknowns = fdef.keys - [:datatype, :default]
        if unknowns.size > 0
          raise InvalidFieldDefinition, "Unknown field options #{unknowns.join(',')}"
        end

      when :string
        unless fdef[:selector] or fdef[:length] or fdef[:validator]
          raise InvalidFieldDefinition, "missing :selector, :length or :validator for :string field #{fname}"
        end
        if fdef[:selector] and fdef[:selector].size < 1
          raise InvalidFieldDefinition, ":selector needs 1 or more elements for #{fname}"
        end
        if fdef[:length] and fdef[:length] < 1
          raise InvalidFieldDefinition, ":length needs integer larger than zero for #{fname}"
        end
        unknowns = fdef.keys - [:datatype, :normalizer, :selector, :length, :validator, :empty, :default]
        if unknowns.size > 0
          raise InvalidFieldDefinition, "Unknown field options #{unknowns.join(',')}"
        end

      when :stringlist
        unless fdef[:separator] and fdef[:length]
          raise InvalidFieldDefinition, "missing one or both of :separator and :length for :stringlist field #{fname}"
        end
        if fdef[:separator].length < 1
          raise InvalidFieldDefinition, ":separator needs 1 or more characters for #{fname}"
        end
        if fdef[:length] and fdef[:length] < 1
          raise InvalidFieldDefinition, ":length needs integer larger than zero for #{fname}"
        end
        unknowns = fdef.keys - [:datatype, :separator, :length, :empty, :default]
        if unknowns.size > 0
          raise InvalidFieldDefinition, "Unknown field options #{unknowns.join(',')}"
        end

      when :taglist
        unknowns = fdef.keys - [:datatype, :empty, :default]
        if unknowns.size > 0
          raise InvalidFieldDefinition, "Unknown field options #{unknowns.join(',')}"
        end

      when :ref, :reflist
        unless fdef[:model]
          raise InvalidFieldDefinition, "missing one or both of :column and :model for :ref/:reflist field #{fname}"
        end
        unknowns = fdef.keys - [:datatype, :model, :manualmaint, :empty] # ref don't have default
        if unknowns.size > 0
          raise InvalidFieldDefinition, "Unknown field options #{unknowns.join(',')}"
        end
      else
        raise InvalidFieldType, type.to_s
      end

      class_eval(self.generate_read_field_method_def(fname), __FILE__, __LINE__)
      class_eval(self.generate_write_field_method_def(fname), __FILE__, __LINE__)
      if type == :bool
        class_eval(self.generate_question_field_method_def(fname), __FILE__, __LINE__)
      end
      if type == :ref or type == :reflist
        class_eval(self.generate_read_field_by_id_method_def(fname), __FILE__, __LINE__)
        class_eval(self.generate_write_field_by_id_method_def(fname), __FILE__, __LINE__)
      end

      nil
    end

    def self.generate_read_field_method_def(sym)
      <<-EOV
        def #{sym.to_s}; read_field(:#{sym.to_s}); end
      EOV
    end

    def self.generate_question_field_method_def(sym)
      <<-EOV
        def #{sym.to_s}?; read_field(:#{sym.to_s}); end
      EOV
    end

    def self.generate_read_field_by_id_method_def(sym)
      <<-EOV
        def #{sym.to_s}_by_id; read_field_by_id(:#{sym.to_s}); end
      EOV
    end

    def self.generate_write_field_method_def(sym)
      <<-EOV
        def #{sym.to_s}=(new_value); write_field(:#{sym.to_s}, new_value); end
      EOV
    end

    def self.generate_write_field_by_id_method_def(sym)
      <<-EOV
        def #{sym.to_s}_by_id=(new_value); write_field_by_id(:#{sym.to_s}, new_value); end
      EOV
    end

    def prepare_to_update
      unless @updatable
        raise InvalidUpdateError, "un-updatable object to update"
      end

      unless @saved
        return
      end

      @pre_update_id = @values['id']

      newvalues = {}
      for k in @values.keys
        begin
          newvalues[k] = @values[k].dup
        rescue TypeError
          newvalues[k] = @values[k]
        end
      end
      newvalues.delete('id')
      newvalues.delete('inserted_at')
      newvalues.delete('operated_by')
      newvalues.delete('head')
      newvalues.delete('removed')
      
      @values = newvalues
      @saved = false
      self
    end

    def check_valid_field(fname)
      unless self.class.fields.include?(fname.to_sym)
        raise InvalidFieldName, fname.to_s
      end
    end

    def read_field(fname)
      self.check_valid_field(fname)

      ftype = self.class.datatype(fname)
      self.send("read_field_#{ftype}", fname)
    end

    def read_field_by_id(fname)
      self.check_valid_field(fname)

      ftype = self.class.datatype(fname)
      unless ftype == :ref or ftype == :reflist
        raise InvalidFieldType, "read_by_id is usable about only ref/reflist"
      end
      self.send("read_field_#{ftype}_by_id", fname)
    end

    def write_field(fname, value)
      self.check_valid_field(fname)

      unless @updatable
        raise InvalidUpdateError, "update operation for un-updatable object"
      end
      ftype = self.class.datatype(fname)
      self.send("write_field_#{ftype}", fname, value)
      value
    end

    def write_field_by_id(fname, value)
      self.check_valid_field(fname)

      unless @updatable
        raise InvalidUpdateError, "update operation for un-updatable object"
      end
      ftype = self.class.datatype(fname)
      unless ftype == :ref or ftype == :reflist
        raise InvalidFieldType, "write_by_id is usable about only ref/reflist"
      end
      self.send("write_field_#{ftype}_by_id", fname, value)
    end

    def read_field_bool(fname)
      raw = @values[self.class.column_by(fname)]
      unless raw == BOOL_TRUE or raw == BOOL_FALSE
        raise RuntimeError, "invalid value as bool in field #{fname}"
      end
      raw == BOOL_TRUE
    end

    def write_field_bool(fname, value)
      # about :bool, nil is evaluated as false.
      raw = if value
              BOOL_TRUE
            else
              BOOL_FALSE
            end
      self.prepare_to_update
      @values[self.class.column_by(fname)] = raw
      value
    end

    def read_field_string(fname)
      @values[self.class.column_by(fname)]
    end

    def write_field_string(fname, value)
      fdef = self.class.definition(fname)

      raw = value
      if value.nil? or value == ''
        raise FieldValidationError.new("field #{fname} cannot be empty", self.class, fname) unless fdef[:empty]
        raw = ''
      else
        unless value.is_a?(String)
          raise FieldValidationError.new("field type string accepts only String, but #{value.class.name}", self.class, fname)
        end

        raw = value.encode('utf-8')
        if fdef[:normalizer]
          raw = self.class.send(fdef[:normalizer], raw)
        end
        
        if fdef[:selector]
          raise FieldValidationError.new("field #{fname} value not included in selector, #{value}", self.class, fname) unless fdef[:selector].include?(raw)
        elsif fdef[:validator]
          raise FieldValidationError.new("field #{fname} validator function returns false", self.class, fname) unless self.send(fdef[:validator], raw)
        elsif fdef[:length]
          raise FieldValidationError.new("field #{fname} length limit overrun", self.class, fname) unless raw.length <= fdef[:length]
        end
      end

      self.prepare_to_update
      @values[self.class.column_by(fname)] = raw
      value
    end

    def read_field_stringlist(fname)
      @values[self.class.column_by(fname)] or []
    end

    def write_field_stringlist(fname, value)
      fdef = self.class.definition(fname)
      sep = fdef[:separator]

      ary = value
      if value.nil? or (value.is_a?(Array) and value.size == 0) or value == ''
        raise FieldValidationError.new("field #{fname}", self.class, fname) unless fdef[:empty]
        ary = []
      else
        unless value.is_a?(Array) or value.is_a?(String)
          raise FieldValidationError.new("stringlist accepts only Array or String(splitted by separator), but #{value.class.name}", self.class, fname)
        end
        ary = value.split(sep) if value.is_a?(String)
        ary = ary.map{|s| s.to_s.encode('utf-8')}
        
        raise FieldValidationError.new("value too long", self.class, fname) unless ary.join(sep).length <= fdef[:length]
      end

      self.prepare_to_update
      @values[self.class.column_by(fname)] = ary
      value
    end

    def read_field_taglist(fname)
      @values[self.class.column_by(fname)] or []
    end

    def write_field_taglist(fname, value)
      fdef = self.class.definition(fname)
      
      ary = [value].flatten
      if value.nil? or (value.is_a?(Array) and value.size == 0) or value == ''
        raise FieldValidationError.new("field #{fname} cannot be empty", self.class, fname) unless fdef[:empty]
        ary = []
      end
      self.prepare_to_update
      @values[self.class.column_by(fname)] = ary.map{|e| e.to_s.encode('utf-8')}
      value
    end

    def read_field_ref_by_id(fname)
      @values[self.class.column_by(fname)]
    end

    def read_field_ref(fname)
      id = self.read_field_ref_by_id(fname)
      return nil if id.nil?

      cls = eval(self.class.definition(fname)[:model])
      cls.get(id, :before => @timeslice)
    end

    def write_field_ref_by_id(fname, value)
      fdef = self.class.definition(fname)
      id = value.to_i
      if value.nil?
        raise FieldValidationError.new("field #{fname} cannot be empty", self.class, fname) unless fdef[:empty]
        id = nil
      else
        unless value.is_a?(Integer) or (value.is_a?(String) and value.to_i.to_s == value)
          raise FieldValidationError.new("field #{fname} accepts ref_oid(Integer) but #{value.class.name}", self.class, fname)
        end
      end
      
      self.prepare_to_update
      @values[self.class.column_by(fname)] = id
      value
    end

    def write_field_ref(fname, value)
      fdef = self.class.definition(fname)
      
      pre_oid = self.read_field_ref_by_id(fname)

      id = if value.is_a?(eval(fdef[:model]))
             value.oid
           elsif value.nil?
             nil
           else
             raise FieldValidationError.new("field #{fname} accepts model object #{fdef[:model]} or its oid, but #{value.class.name}", self.class, fname)
           end

      pre_value = if pre_oid and pre_oid != id
                    self.read_field_ref(fname)
                  else
                    nil
                  end

      self.write_field_ref_by_id(fname, id)

      if pre_oid != id
        pre_value.released(self) if pre_value
        value.retained(self) if value
      end

      value
    end

    def read_field_reflist_by_id(fname)
      @values[self.class.column_by(fname)] or []
    end

    def read_field_reflist(fname)
      ids = self.read_field_reflist_by_id(fname)
      return [] if ids.size < 1

      cls = eval(self.class.definition(fname)[:model])
      set = cls.get(ids, :before => @timeslice)
      ret = Array.new(ids.size)
      ids.each_index do |i|
        ret[i] = set.select{|o| o.oid == ids[i]}.first
      end
      ret.compact
    end

    def write_field_reflist_by_id(fname, value)
      fdef = self.class.definition(fname)

      if value.nil? or (value.is_a?(Array) and value.size == 0)
        raise FieldValidationError.new("field #{fname} cannot be empty", self.class, fname) unless fdef[:empty]
        self.prepare_to_update
        @values[self.class.column_by(fname)] = []
        return value
      end

      values = value
      unless value.is_a?(Array)
        values = [value]
      end
      ids = []
      for v in values
        id = if v.is_a?(Integer)
               v
             elsif v.is_a?(String) and v.to_i.to_s == v
               v.to_i
             else
               raise FieldValidationError.new("field #{fname} accepts ref_oid(Integer) list, but #{v.class.name}", self.class, fname)
             end
        ids.push(id)
      end

      self.prepare_to_update
      @values[self.class.column_by(fname)] = ids
      values
    end

    def write_field_reflist(fname, value)
      fdef = self.class.definition(fname)
      cls = eval(fdef[:model])
      
      unless value.is_a?(Array) or value.is_a?(cls)
        if value.nil? and fdef[:empty]
          pre_values = self.read_field_reflist(fname)
          self.write_field_reflist_by_id(fname, value)
          pre_values.each {|v| v.released(self)}
          return value
        end
        raise FieldValidationError.new("field #{fname} accepts list of model (or nil, if :empty => :ok), but #{value.class.name}", self.class, fname)
      end

      pre_ids = self.read_field_reflist_by_id(fname)
      pre_values = self.read_field_reflist(fname)
      values = if value.is_a?(Array)
                 value
               else
                 [value]
               end
      ids = []
      released_objs = pre_values
      retained_objs = []

      for v in values
        raise FieldValidationError.new("field #{fname} accepts list of #{fdef[:model]}, but #{v.class.name}", self.class, fname) unless v.is_a?(cls)
        ids.push(v.oid)
        if pre_ids.include?(v.oid)
          released_objs.delete_if {|x| x.oid == v.oid}
        else
          retained_objs.push(v)
        end
      end

      self.write_field_reflist_by_id(fname, ids)

      released_objs.each {|v| v.released(self)}
      retained_objs.each {|v| v.retained(self)}

      value
    end

    def self.get(*key)
      # return single object for single argument
      # else, as array
      # :before => time options returns result with condition 'inserted_at < time'
      # :force_all => true option returns result with removed=true

      opts = if key[-1].is_a?(Hash)
               key.delete_at(-1)
             else
               {}
             end
      ret_single = (key.size == 1 and not key[0].is_a?(Array))

      key_oids = key.flatten
      if opts[:before] and not ret_single
        return key_oids.map{|k| self.get(k, opts)}.select{|i| not i.nil?}
      end

      keys = key_oids.dup
      models = {}

      unless opts[:before]
        keys.dup.each do |oid|
          m = ModelCache.get(oid)
          next if m.nil? or m.class != self

          models[oid] = m
          keys.delete(oid)
        end
      end

      if keys.size > 0
        oidunit = 'oid=?'
        cond = oidunit.dup
        i = 1
        while i < keys.length
          cond += (' OR ' + oidunit)
          i += 1
        end
        fieldnames = self.columns.join(',')

        head_cond = opts[:before] ? "" : " AND head=?"
        removed_cond = opts[:force_all] ? "" : " AND removed=?"
        before_cond = opts[:before] ? " AND inserted_at <= ? ORDER BY id DESC LIMIT 1" : ""
        sql = "SELECT #{fieldnames} FROM #{self.tablename} WHERE (#{cond})#{head_cond}#{removed_cond}#{before_cond}"

        keys.push(BOOL_TRUE) unless opts[:before]
        keys.push(BOOL_FALSE) unless opts[:force_all]
        keys.push(opts[:before]) if opts[:before]

        Stratum.conn do |conn|
          st = conn.prepare(sql)
          st.execute(*keys)
          while pairs = st.fetch_hash
            obj = self.new(pairs, :before => opts[:before])
            models[obj.oid] = obj
            if obj and not opts[:before]
              ModelCache.set(obj)
            end
          end
          st.free_result
        end
      end

      return models[key_oids.first] if ret_single
      ary = key_oids.map{|i| models[i]}
      ary.delete(nil)
      ary
    end

    def self.retrospect(oid)
      fieldnames = self.columns.join(',')
      sql = "SELECT #{fieldnames} FROM #{self.tablename} WHERE oid=? ORDER BY id DESC"

      result = []
      Stratum.conn do |conn|
        st = conn.prepare(sql)
        st.execute(oid.to_i)

        while pairs = st.fetch_hash
          result.push(self.new(pairs, :before => pairs['inserted_at'].addseconds(2)))
        end
        st.free_result
      end
      
      return nil if result.size < 1
      result
    end

    def self.regex_match(opts={})
      oidonly = opts.delete(:oidonly)

      raise ArgumentError, "regex_match accepts only one field=>regex pair" if opts.size != 1

      fname = (opts.keys)[0]
      column = self.column_by(fname)
      regex = opts[fname]

      raise ArgumentError, "regex_match accepts only string fields for search" if self.datatype(fname) != :string

      result = nil
      Stratum.conn do |conn|
        st = conn.prepare("SELECT oid,#{column} FROM #{self.tablename} WHERE head=? AND removed=?")
        st.execute(BOOL_TRUE, BOOL_FALSE)
        oids = []
        while pair = st.fetch
          if regex.match(pair[1])
            oids.push(pair[0])
          end
        end
        result = oidonly ? oids : self.get(oids)
      end
      result
    end

    def self.all(opts={})
      opts[:sorted] ||= false
      
      fieldnames = self.columns.join(',')
      sql = "SELECT #{fieldnames} FROM #{self.tablename} WHERE head=? AND removed=?"

      result = []
      Stratum.conn do |conn|
        st = conn.prepare(sql)
        st.execute(BOOL_TRUE, BOOL_FALSE)
        while pairs = st.fetch_hash
          result.push(self.new(pairs))
        end
        st.free_result
      end
      if opts[:sorted]
        result.sort!
      end
      result
    end

    def self.getlist(key_field)
      unless key_field.is_a?(Symbol) or key_field.is_a?(String)
        raise ArgumentError, "invalid argument type #{key_field.class}"
      end
      unless self.datatype(key_field)
        raise ArgumentError, "unknown field name #{key_field} for model #{self.class.name}"
      end
      unless self.datatype(key_field) == :string
        raise ArgumentError, "invalid type of field #{key_field} for getlist key field, needed :string"
      end

      self.regex_match(key_field => /./).sort{|a,b| a.send(key_field) <=> b.send(key_field)}
    end
    
    def self.query(opts={})
      # :unique => true option should be specified when queried condition and oid are connected 1-on-1
      # :force_all => true option returns result with removed=true
      #TODO :before needed?

      unique = opts.delete(:unique)
      force_all = opts.delete(:force_all)
      count = opts.delete(:count)
      oidonly = opts.delete(:oidonly)
      if count
        raise ArgumentError, 'invalid option specification both :count and :unique' if unique
        raise ArgumentError, 'invalid option specification both :count and :oidonly' if oidonly
      end
      selector = opts.delete(:select)
      if selector
        raise ArgumentError, ':selector option accepts only :first/:last' unless [:first,:last].include?(selector)
        raise ArgumentError, 'invalid option specification both :unique and :select' if unique
        raise ArgumentError, 'invalid option specification both :count and :select' if count
        force_all = true
      end

      fieldnames = self.columns.join(',')
      conds = []
      vals = []
      opts.each do |k,v|
        colname = self.column_by(k)
        ftype = self.datatype(k)
        value = case ftype
                when :bool
                  v ? BOOL_TRUE : BOOL_FALSE
                when :string
                  if v.nil?
                    nil
                  elsif self.definition(k)[:normalizer]
                    self.send(self.definition(k)[:normalizer], v.encode('utf-8'))
                  else
                    v.encode('utf-8')
                  end
                when :stringlist
                  if v.nil?
                    nil
                  else
                    [v].flatten.join(self.definition(k)[:separator])
                  end
                when :taglist
                  if v.instance_of?(Array)
                    v.map{|s| '+' + s}.join(' ')
                  elsif v.nil?
                    nil
                  else
                    v.to_s
                  end
                when :ref
                  if v.nil?
                    nil
                  else
                    v.is_a?(Stratum::Model) ? v.oid : v.to_i
                  end
                when :reflist
                  if v.nil?
                    nil
                  else
                    [v].flatten.map{|e| e.is_a?(Stratum::Model) ? e.oid.to_s : e.to_i.to_s}.join(REFLIST_SEPARATOR)
                  end
                when :reserved
                  nil
                end
        if ftype == :taglist
          if value.nil?
            conds.push("(#{colname} IS NULL OR #{colname}='')")
          else
            conds.push("MATCH(#{colname}) AGAINST(? IN BOOLEAN MODE)")
            vals.push(value)
          end
        else
          if value.nil?
            conds.push("(#{colname} IS NULL OR #{colname}='')")
          else
            conds.push("#{colname}=?")
            vals.push(value)
          end
        end
      end
      cond = conds.join(' AND ')

      head_cond = selector ? "" : "AND head=?"
      removed_cond = force_all ? "" : "AND removed=?" # if selector setted, force_all is always true
      sql = if count
              "SELECT count(*) FROM #{self.tablename} WHERE (#{cond}) #{head_cond} #{removed_cond}"
            else
              if oidonly
                "SELECT oid FROM #{self.tablename} WHERE (#{cond}) #{head_cond} #{removed_cond}"
              else
                "SELECT #{fieldnames} FROM #{self.tablename} WHERE (#{cond}) #{head_cond} #{removed_cond}"
              end
            end

      vals.push(BOOL_TRUE) unless selector
      vals.push(BOOL_FALSE) unless force_all

      result = []
      if count
        Stratum.conn do |conn|
          st = conn.prepare(sql)
          st.execute(*vals)
          result = st.fetch.first
          st.free_result
        end
      elsif selector
        result_set = {}
        Stratum.conn do |conn|
          st = conn.prepare(sql)
          st.execute(*vals)

          while pairs = st.fetch_hash
            obj = oidonly ? pairs['oid'].to_i : self.new(pairs)
            if result_set[obj.oid]
              if (selector == :first and result_set[obj.oid].id > obj.id) or (selector == :last and result_set[obj.oid].id < obj.id)
                result_set[obj.oid] = obj
              end
            else
              result_set[obj.oid] = obj
            end
          end
          st.free_result
        end
        result = result_set.values
      else
        Stratum.conn do |conn|
          st = conn.prepare(sql)
          st.execute(*vals)

          if oidonly
            while vals = st.fetch
              result.push(vals.first.to_i)
            end
          else
            while pairs = st.fetch_hash
              result.push(self.new(pairs))
            end
          end
          st.free_result
        end

        if unique
          raise NotUniqueResultError, "unique expected query returned results: #{result.size.to_s}" if result.size > 1
          return result[0]
        end
      end
      result
    end

    def self.query_or_create(opts={})
      # return single object. if multi line result for select, raise exception
      # this method implicitly expect result is :unique

      Stratum.transaction do |c|
        result = self.query(opts.merge({:unique => true}))
        return result if result

        obj = self.new
        for k in opts.keys
          obj.write_field(k, opts[k])
        end
        return obj.save
      end
    end
    
    def self.update_unheadnize(id)
      Stratum.conn do |conn|
        conn.query("UPDATE #{self.tablename} SET head='#{BOOL_FALSE}' WHERE id=#{id}")
      end
      nil
    end

    def insert(opts={})
      removed = (opts.has_key?(:removed) and opts[:removed]) ? BOOL_TRUE : BOOL_FALSE

      pairs = {}
      for col in @values.keys
        fname = self.class.field_by(col)
        ftype = self.class.datatype(fname)

        next if ftype == :reserved
        pairs[col] = self.sqlvalue(fname)
      end
      pairs['operated_by'] = Stratum.current_operator.oid
      pairs['head'] = BOOL_TRUE
      pairs['removed'] = removed

      unless @values['oid']
        raise FieldValidationError.new("missing oid, illegal status. tell to developler", self.class, :oid)
      end
      pairs['oid'] = @values['oid']

      columns = pairs.keys
      setpairs = columns.map{|c| "#{c}=?"}.join(',')
      values = columns.map{|c| pairs[c]}
      sql = "INSERT INTO #{self.class.tablename} SET #{setpairs}"

      conn = Stratum.conn
      st = conn.prepare(sql)
      st.execute(*values)
      st.free_result
      conn.release

      self.overwrite(self.class.get(oid, :force_all => true))
      self
    end

    def save
      ###
      # 1. check @unsaved_oid.
      # 2. (if false, start transaction)
      # 3.   (update for non-head update)
      # 4. insert head record
      # 5. (commit transaction)
      raise InvalidUpdateError, "un-updatable object" unless self.updatable?
      return self if self.saved?

      ModelCache.flush()

      if @unsaved_oid
        @unsaved_oid = false
        return self.insert()
      end

      Stratum.transaction do |c|
        prehead = self.class.get(oid)
        ModelCache.flush()
        
        unless prehead
          raise InvalidUpdateError, "specified object to save has invalid oid, without any records"
        end
        if prehead and @pre_update_id and prehead.id != @pre_update_id
          raise ConcurrentUpdateError, "Concurrent update occured about oid #{self.oid}, model #{self.class.name}"
        end

        self.class.update_unheadnize(prehead.id)
        self.insert()
      end
      @unsaved_oid = false
      self
    end

    def remove
      unless self.saved? and self.updatable? and not self.oid.nil?
        raise InvalidUpdateError, "you can remove only updatable and not updated object"
      end

      ModelCache.flush()

      Stratum.transaction do |c|
        prehead = self.class.get(self.oid)
        ModelCache.flush()

        unless prehead
          raise InvalidUpdateError, "specified object to save has invalid oid, without any records"
        end
        unless self.id == prehead.id
          raise ConcurrentUpdateError, "Concurrent remove occured about oid #{self.oid}, model #{self.class.name}"
        end
        
        self.class.update_unheadnize(prehead.id)
        self.insert(:removed => true)
      end
      ModelCache.flush()
      @unsaved_oid = false
      self
    end

    def retained(obj)
      state_saved = self.saved?
      self.class.ref_fields_of(obj.class).each do |f|
        next if self.class.definition(f)[:manualmaint]

        f_by_id = f.to_s + '_by_id'
        getter = f_by_id.to_sym
        setter = (f_by_id + '=').to_sym

        unless [self.send(getter)].flatten.include?(obj.oid)
          if self.send(getter).is_a?(Array)
            self.send(setter, self.send(getter) + [obj.oid])
          else
            self.send(setter, obj.oid)
          end
        end
      end
      # if none of update-field is done, Stratum::Model#save doesn't perform to save actually.
      self.save if state_saved
      self
    end

    def released(obj)
      state_saved = self.saved?
      self.class.ref_fields_of(obj.class).each do |f|
        next if self.class.definition(f)[:manualmaint]

        f_by_id = f.to_s + '_by_id'
        getter = f_by_id.to_sym
        setter = (f_by_id + '=').to_sym

        if [self.send(getter)].flatten.include?(obj.oid)
          if self.send(getter).is_a?(Array)
            self.send(setter, self.send(getter).select{|v| v != obj.oid})
          else
            self.send(setter, nil)
          end
        end
      end
      self.save if state_saved
      self
    end

    def initialize(fetched={}, opts={})
      @unsaved_oid = true
      @values = {}
      @saved = false
      @updatable = true
      @pre_update_id = nil
      @timeslice = nil

      for f in self.class.fields
        next if RESERVED_FIELDS.include?(f)
        fdef = self.class.definition(f)
        if fdef.has_key?(:default)
          self.write_field(f, fdef[:default])
        end
      end

#      return self if fetched.size < 1
      if fetched.size < 1
        @values['oid'] = Stratum.allocate_oid
        return self
      end

      fetched.each_pair do |col, val|
        fname = self.class.field_by(col)
        ftype = self.class.datatype(fname)
        fdef = self.class.definition(fname)

        @values[col] = self.class.rawvalue(ftype, fdef, val)
      end
      @unsaved_oid = false
      @saved = true
      if self.removed or not self.head
        @updatable = false
      end
      if opts[:before]
        @timeslice = opts[:before]
      end
      
      self
    end

    def self.sqlvalue(ftype, fdef, rawvalue)
      case ftype
      when :bool, :string, :reserved
        rawvalue
      when :stringlist
        rawvalue.join(fdef[:separator])
      when :taglist
        rawvalue.join(TAG_SEPARATOR)
      when :ref
        rawvalue
      when :reflist
        rawvalue.map{|v| v.to_s}.join(REFLIST_SEPARATOR)
      end
    end

    def self.rawvalue(ftype, fdef, sqlvalue)
      case ftype
      when :bool, :string, :reserved
        sqlvalue
      when :stringlist
        if sqlvalue.nil? or sqlvalue == ''
          []
        else
          sqlvalue.split(fdef[:separator])
        end
      when :taglist
        if sqlvalue.nil? or sqlvalue == ''
          []
        else
          sqlvalue.split(TAG_SEPARATOR)
        end
      when :ref
        sqlvalue
      when :reflist
        if sqlvalue.nil? or sqlvalue == ''
          []
        else
          sqlvalue.split(REFLIST_SEPARATOR).map{|v| v.to_i}
        end
      else
        raise RuntimeError, "unknown type #{ftype}"
      end
    end

    def sqlvalue(fname)
      fdef = self.class.definition(fname)
      ftype = self.class.datatype(fname)
      self.class.sqlvalue(ftype, fdef, @values[self.class.column_by(fname)])
    end

    def raw_values
      # hash of key:column_string, value:object_internal_expression
      # object_internal_exp: result of self.class.rawvalue(ftype, fdef, sqlvalue)
      @values
    end

    def overwrite(data)
      # method for internal use
      # data MUST be instance of self.class, or hash(Mysql::Result.fetch_hash())
      if data.class == self.class
        @values = data.raw_values
        @saved = data.saved?
        @updatable = data.updatable?
        @pre_update_id = nil
        return self
      end
      @values = data
      @saved = true
      if self.removed or not self.head
        @updatable = false
      end
      @pre_update_id = nil
      self
    end

    def id
      return nil unless @values['id']
      @values['id'].to_i
    end

    def oid
      return nil unless @values['oid']
      @values['oid'].to_i
    end

    def inserted_at
      return nil unless @values['inserted_at']
      @values['inserted_at']
    end

    def operated_by
      return nil unless @values['operated_by']
      Stratum.get_operator(@values['operated_by'])
    end

    def operated_by_oid
      return nil unless @values['operated_by']
      @values['operated_by'].to_i
    end

    def head
      self.read_field_bool(:head)
    end

    def removed
      self.read_field_bool(:removed)
    end

    def updatable?
      @updatable
    end

    def saved?
      @saved
    end

    def ==(other)
      self.class == other.class and
        self.saved? and other.saved? and
        self.oid == other.oid and
        self.id == other.id
    end
  end
end
