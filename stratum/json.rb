# -*- coding: utf-8 -*-

require 'json'

module Stratum
  module JSON
    def to_json(*args)
      opts = args.last.is_a?(Hash) ? args.pop : {}
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
      return h.to_json unless opts[:with_content]
      
      body = {}
      self.class.fields.each do |f|
        body[f] = self.send(f)
      end
      h[:content] = body
      h.to_json
    end
  end
end
