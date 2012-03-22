# -*- coding: utf-8 -*-

require 'thread'
require 'mysql2'
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
    $STRATUM_CONNECTION_DBPARAMS = nil
    $STRATUM_CONNECTION_POOL = []
    $STRATUM_CONNECTION_TXS = {}

    def self.setupped?
      not $STRATUM_CONNECTION_DBPARAMS.nil? and $STRATUM_CONNECTION_DBPARAMS[:host]
    end

# :host - Defaults to "localhost".
# :port - Defaults to 3306.
# :socket - Defaults to "/tmp/mysql.sock".
# :username - Defaults to "root"
# :password - Defaults to nothing.
# :database - The name of the database. No default, must be provided.
# :encoding - (Optional) Sets the client encoding by executing "SET NAMES <encoding>" after connection.
# :reconnect - Defaults to false (See MySQL documentation: dev.mysql.com/doc/refman/5.0/en/auto-reconnect.html).
# :sslca - Necessary to use MySQL with an SSL connection.
# :sslkey - Necessary to use MySQL with an SSL connection.
# :sslcert - Necessary to use MySQL with an SSL connection.
# :sslcapath - Necessary to use MySQL with an SSL connection.
# :sslcipher - Necessary to use MySQL with an SSL connection.
    def self.setup(host=nil, user=nil, passwd=nil, db=nil, port=nil, sock=nil, flag=nil)
      $STRATUM_CONNECTION_DBPARAMS = {
        :host => host, :port => port, :socket => sock,
        :username => user, :password => passwd, :database => db,
      }
    end

    # client.methods
    # :close, :query, :escape,
    # :info, :server_info, :encoding,
    # :last_id, :affected_rows, 
    # :socket, :async_result, :thread_id, :ping, :query_options,
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

      @handler = Mysql2::Client.new($STRATUM_CONNECTION_DBPARAMS)
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
          @handler.query('ROLLBACK');
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

    def pseudo_bind(sql, values)
      sql = sql.dup

      placeholders = []
      search_pos = 0
      while pos = sql.index('?', search_pos)
        placeholders.push(pos)
        search_pos = pos + 1
      end
      raise ArgumentError, "mismatch between placeholders number and values arguments" if placeholders.length != values.length

      while pos = placeholders.pop()
        rawvalue = values.pop()
        if rawvalue.nil?
          sql[pos] = 'NULL'
        elsif rawvalue.is_a?(Time)
          val = rawvalue.strftime('%Y-%m-%d %H:%M:%S')
          sql[pos] = "'" + val + "'"
        else
          val = @handler.escape(rawvalue.to_s)
          sql[pos] = "'" + val + "'"
        end
      end
      sql
    end

    def query(sql, *values)
      values = values.flatten
      # pseudo prepared statements
      return @handler.query(sql) if values.length < 1
      @handler.query(self.pseudo_bind(sql, values))
    end

    def run_in_transaction(&blk)
      if Stratum.is_in_transaction()
        return yield self
      end

      begin
        self.set_tx()
        @handler.query('BEGIN');

        yield self
      rescue
        @handler.query('ROLLBACK');
        Stratum::ModelCache.flush()
        raise
      ensure
        unless $! # reach ensure without any exceptions
          @handler.query('COMMIT');
        end
        self.release_tx()
      end
    end

    # h.methods
    # :close, :query, :escape, :info, :server_info, :socket, :async_result,
    # :last_id, :affected_rows, :thread_id, :ping, :encoding, :query_options,
    # and Default Object/ObjectClass methods
    def method_missing(name, *args)
      @handler.send(name, *args)
    end
  end
end
