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
      self.class.fields.each do |f|
        fdef = self.class.definition(f)
        next if fdef.nil? or fdef[:datatype] == :reserved
        val = self.send(f)
        body[f] = case fdef[:datatype]
                  when :ref
                    if fdef[:serialize_as_id]
                      val ? val.oid : nil
                    else
                      s = val.to_s
                      s == "" ? nil : s
                    end
                  when :reflist
                    if fdef[:serialize_as_id]
                      val.map(&:oid)
                    else
                      val.map(&:to_s)
                    end
                  else
                    val
                  end
      end
      h[:content] = body
      h.to_json(state, depth+1)
    end
  end
end
