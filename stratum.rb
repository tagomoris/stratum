# -*- coding:utf-8 -*-

require 'stratum/model'
require 'stratum/connection'

class InvalidOperator < StandardError ; end

module Stratum
  $STRATUM_OPERATOR_MODEL = NilClass
  $STRATUM_OPERATOR = nil

  def self.operator_model(cls)
    unless cls.ancestors.include?(Stratum::Model)
      raise InvalidOperator, "invalid class for Stratum operator #{cls.name}"
    end
    $STRATUM_OPERATOR_MODEL = cls
  end

  def self.current_operator(obj=nil)
    return $STRATUM_OPERATOR if obj.nil?

    if $STRATUM_OPERATOR_MODEL.nil?
      raise InvalidOperator, "operator_model is not specified yet."
    end
    unless obj.is_a?($STRATUM_OPERATOR_MODEL)
      raise InvalidOperator, "specified object is not an instance of #{$STRATUM_OPERATOR_MODEL.name}"
    end
    unless obj.saved? and obj.oid
      raise InvalidOperator, "specified object is not saved yet or doesn't have oid"
    end
    $STRATUM_OPERATOR = obj
  end
  
  def self.get_operator(oid)
    $STRATUM_OPERATOR_MODEL.get(oid.to_i)
  end

  OPERATOR_ROOT_OID = 0 # fix as your root user oid

  def self.allocate_oid(conn=nil)
    c = conn
    unless c
      c = Stratum.conn()
    end
    c.query("UPDATE oids SET id=LAST_INSERT_ID(id+1)")
    newid = c.insert_id()
    if conn.nil?
      c.release
    end
    newid
  end
end
