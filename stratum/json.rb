# -*- coding: utf-8 -*-

require 'json'

module Stratum
  module JSON
    def to_tree(depth=0)
      h = {
        :model => self.class.to_s,
        :oid => self.oid,
        :id => self.id,
        :last_modified => self.inserted_at.to_s,
        :updatable => self.updatable?,
        :head => self.head,
        :removed => self.removed,
        :display => self.to_s,
      }
      if self.respond_to?(:json_meta_fields)
        h.update(self.json_meta_fields) {|k,v1,v2| raise RuntimeError, "cannot update pre-defined meta fields"}
      end

      return h if depth > 2

      body = {}
      self.class.fields.each do |f|
        fdef = self.class.definition(f)
        next if fdef.nil? or fdef[:datatype] == :reserved

        val = self.send(f)
        body[f] = case fdef[:datatype]
                  when :ref
                    case fdef[:serialize]
                    when :oid
                      val && val.oid
                    when :meta
                      val && val.to_tree(depth+2)
                    when :full
                      val && val.to_tree(1)
                    else
                      s = val.to_s
                      s == "" ? nil : s
                    end
                  when :reflist
                    case fdef[:serialize]
                    when :oid
                      val.map(&:oid)
                    when :meta
                      val.map{|v| v.to_tree(depth+2)}
                    when :full
                      val.map{|v| v.to_tree(1)}
                    else
                      val.map(&:to_s)
                    end
                  else
                    val
                  end
      end
      h[:content] = body
      h
    end

    def to_json(state=nil)
      self.to_tree(0).to_json(state)
    end
  end
end
