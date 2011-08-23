# -*- coding: utf-8 -*-

require 'thread'
require 'mysql'
require_relative './model'

module Stratum
  class DatabaseError < StandardError ; end
  class TransactionOperationError < StandardError ; end
end

module Stratum
  def self.parse_caller(at)
    # copy & paste from
    # http://www.ruby-lang.org/ja/man/html/_C1C8A4DFB9FEA4DFB4D8BFF4.html#caller
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file = $1
      line = $2.to_i
      method = $3
      [file, line, method]
    end
  end

  def self.conn(&blk)
    unless blk
      return Stratum::Connection.conn()
    end

    conn = Stratum::Connection.conn()
    begin
      ret = yield conn
    ensure
      conn.release()
    end
    ret
  end

  def self.is_in_transaction
    # caller(0)[0] is here, and caller(1)[0] is caller of this method
    for c in caller(2)
      f, l, m = parse_caller(c)
      return true if f == __FILE__ and m == 'run_in_transaction'
    end
    return false
  end

  def self.transaction(&blk)
    conn = Stratum::Connection.conn
    begin
      conn.run_in_transaction(&blk)
    ensure
      conn.release()
    end
  end

  class Connection
    $STRATUM_CONNECTION_DBPARAMS = []
    $STRATUM_CONNECTION_POOL = []
    $STRATUM_CONNECTION_TXS = {}

    def self.setupped?
      not $STRATUM_CONNECTION_DBPARAMS[0].nil?
    end

    def self.setup(host=nil, user=nil, passwd=nil, db=nil, port=nil, sock=nil, flag=nil)
      $STRATUM_CONNECTION_DBPARAMS = [host, user, passwd, db, port, sock, flag]
    end

    def self.conn
      unless self.setupped?
        raise DatabaseError, "not setupped"
      end

      if Stratum.is_in_transaction
        return $STRATUM_CONNECTION_TXS[Thread.current]
      end

      for c in $STRATUM_CONNECTION_POOL
        if c.hold
          return c
        end
      end

      new_connection = self.new()
      $STRATUM_CONNECTION_POOL.push(new_connection)
      return new_connection
    end

    def self.destruct(conn)
      $STRATUM_CONNECTION_POOL.delete(conn)
    end

    def initialize
      unless self.class.setupped?
        raise DatabaseError, "not setupped"
      end

      @handler = Mysql.connect(*$STRATUM_CONNECTION_DBPARAMS)
      @handler.charset = 'utf8'
      @owned = true
      @mutex = Mutex.new
      self
    end

    def set_tx
      $STRATUM_CONNECTION_TXS[Thread.current] = self
    end

    def in_tx?
      $STRATUM_CONNECTION_TXS.has_value?(self)
    end

    def release_tx
      $STRATUM_CONNECTION_TXS.delete(Thread.current)
    end

    def owned?
      @owned
    end

    def hold
      @mutex.synchronize do
        if @owned
          return nil
        end
        @owned = true
      end
      true
    end

    def release
      if Stratum.is_in_transaction()
        return true
      end

      begin
        @owned = false
        if self.in_tx?
          @handler.rollback()
          @handler.autocommit(true)
        end
      ensure
        self.release_tx()
      end
      true
    end

    def close
      if self.in_tx?
        raise Stratum::TransactionOperationError, "don't close connection in transaction!"
      end

      begin
        self.release()
        @handler.close()
        @handler = nil
      ensure
        self.class.destruct(self)
      end
      true
    end

    def commit
      raise Stratum::TransactionOperationError, "don't use this directly. use run_in_transaction instead."
    end

    def rollback
      raise Stratum::TransactionOperationError, "don't use this directly. use run_in_transaction instead."
    end

    def autocommit(val)
      raise Stratum::TransactionOperationError, "don't use this directly. use run_in_transaction instead."
    end

    def run_in_transaction(&blk)
      if Stratum.is_in_transaction()
        return yield self
      end

      begin
        self.set_tx()
        @handler.autocommit(false)

        yield self
      rescue
        @handler.rollback()
        Stratum::ModelCache.flush()
        raise
      ensure
        unless $! # reach ensure without any exceptions
          @handler.commit()
        end
        @handler.autocommit(true)
        self.release_tx()
      end
    end

    def method_missing(name, *args)
      @handler.send(name, *args)
    end
  end
end
