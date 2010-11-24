# -*- coding: utf-8 -*-

require 'json'

module Stratum
  module JSON
    def to_json(state=nil, depth=0)
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
      return h.to_json if depth > 2
      
      body = {}
      self.class.fields.select{|f| self.class.datatype(f) != :reserved}.each do |f|
        val = self.send(f)
        body[f] = if val == ""
                    nil
                  elsif val.is_a?(Stratum::Model)
                    s = val.to_s
                    s == "" ? nil : s
                  elsif val.is_a?(Array)
                    val.map(&:to_s)
                  else
                    val
                  end
      end
      h[:content] = body
      h.to_json(state, depth+1)
    end
  end
end
