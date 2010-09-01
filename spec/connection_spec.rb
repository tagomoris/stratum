# -*- coding: utf-8 -*-

require_relative '../stratum/connection'
require_relative '../spec/testdatabase'

module Stratum
  class Connection
    def self.dump_internals
      return $STRATUM_CONNECTION_POOL, $STRATUM_CONNECTION_DBPARAMS, $STRATUM_CONNECTION_TXS
    end
  end
end

SERVERNAME = 'localhost'
USERNAME = 'root'
PASSWORD = nil
DATABASE = 'testdb'

describe Stratum::Connection, "が使われる前" do
  before do
    $STRATUM_CONNECTION_DBPARAMS = []
    $STRATUM_CONNECTION_POOL = []
    $STRATUM_CONNECTION_TXS = {}
  end

  after do
    $STRATUM_CONNECTION_DBPARAMS = []
    $STRATUM_CONNECTION_POOL = []
    $STRATUM_CONNECTION_TXS = {}
  end

  it "に初期化されずに #new されたら失敗すること" do
    lambda {conn = Stratum::Connection.new(); conn.close}.should raise_exception(Stratum::DatabaseError)
  end
  
  it "には .setup で初期化されること" do
    host = 'hostnam'
    user = 'username'
    pass = 'password'
    db = 'database'
    port = Integer(1)
    sock = '/a/socket/pass'
    flag = Object.new

    Stratum::Connection.setupped?.should be_false

    Stratum::Connection.setup(host, user, pass, db, port, sock, flag)
    conn, params, txs = Stratum::Connection.dump_internals()

    Stratum::Connection.setupped?.should be_true

    conn.should have(0).items
    txs.should have(0).items
    params.should have(7).items
    params[0].should equal(host)
    params[1].should equal(user)
    params[2].should equal(pass)
    params[3].should equal(db)
    params[4].should equal(port)
    params[5].should equal(sock)
    params[6].should equal(flag)
  end

  it "に .setup で初期化されたら .new してOKであること" do
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
    lambda {conn = Stratum::Connection.new(); conn.close}.should_not raise_exception(Stratum::DatabaseError)
  end
  
end

describe Stratum::Connection, "がtxなしで使われるとき" do
  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
  end

  before do
    @conn = Stratum::Connection.new()
  end

  after do
    @conn.close()
  end

  it "に、宣言されていないメソッドは Mysql のインスタンスに送られていること" do
    begin
      @conn.hogemogepos()
    rescue NoMethodError => e
      e.message.should match(/#<Mysql:0x[0-9a-f]+>\Z/)
    end
  end

  it "に .new したらDBに接続済みのインスタンスが返ること" do
    @conn.host_info.should_not be_nil
    lambda {@conn.ping()}.should_not raise_exception(NoMethodError)
    @conn.close()
    lambda {@conn.ping()}.should raise_exception(NoMethodError)
  end

  it "に、新しいインスタンスは #owned? が true であること、追加でholdできないこと" do
    @conn.owned?.should be_true
    @conn.hold().should be_nil
  end

  it "に #release してもDB接続は保たれているが #owned? がfalseとなること" do
    lambda {@conn.ping()}.should_not raise_exception(NoMethodError)
    @conn.owned?.should be_true
    @conn.release()
    lambda {@conn.ping()}.should_not raise_exception(NoMethodError)
    @conn.owned?.should be_false
  end

  it "に #release されたあとで hold されると #owned? がtrueとなること" do
    @conn.owned?.should be_true
    @conn.release()
    @conn.owned?.should be_false
    @conn.hold().should_not be_nil
    @conn.owned?.should be_true
  end

  it "に #commit #rollback #autocommit がすべて使用できないこと" do
    lambda {@conn.commit()}.should raise_exception(Stratum::TransactionOperationError)
    lambda {@conn.rollback()}.should raise_exception(Stratum::TransactionOperationError)
    lambda {@conn.autocommit(true)}.should raise_exception(Stratum::TransactionOperationError)
  end

  after(:all) do
    TestDatabase.drop()
  end
end

describe Stratum::Connection, "でtxを使ったとき" do
  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
  end

  before do
    @conn = Stratum::Connection.new()
  end

  after do
    @conn.close()
  end

  it "に、トランザクションで使用しているかどうかの状態が正常にset/releaseされること" do
    @conn.in_tx?.should be_false
    @conn.set_tx()
    @conn.in_tx?.should be_true
    @conn.release_tx()
    @conn.in_tx?.should be_false

    @conn.run_in_transaction do |c|
      c.in_tx?.should be_true
    end
  end
  
  it "に、tx処理中で更にtxを開始しても同じコネクションが割り当たること" do
    @conn.run_in_transaction do |c1|
      c1.run_in_transaction do |c2|
        c1.object_id.should equal(c2.object_id)
      end
    end
  end

  it "に、tx処理が正常に行えること" do
    conn2 = Stratum::Connection.new()
    num = @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
    conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)
    @conn.run_in_transaction do |c|
      c.query("INSERT INTO testex1 SET oid=1,name='tagomoris',operated_by=0")

      c.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)
      conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)
    end
    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)
    conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)

    conn2.close()
  end

  it "に、tx処理のブロック中でreturnしてもcommitされること" do 
    conn2 = Stratum::Connection.new()
    num = conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)

    def self.dummyfunc1(conn, num, val1, val2)
      conn.run_in_transaction do |c|
        c.query("INSERT INTO testex1 SET oid=1,name='tagomoris',operated_by=0")
        count = c.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
        count.should eql(num + 1)
        return val1 if count == num + 1
        val2
      end
    end

    ret = dummyfunc1(@conn, num, 'pre', 'post')
    ret.should eql('pre')
    
    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)
    conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)

    conn2.close()
  end

  it "に、tx処理中で例外発生時にはrollbackされること" do 
    conn2 = Stratum::Connection.new()
    num = conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)

    def self.dummyfunc2(conn, num)
      conn.run_in_transaction do |c|
        c.query("INSERT INTO testex1 SET oid=1,name='tagomoris',operated_by=0")
        count = c.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
        count.should eql(num + 1)
        raise StandardError
        true
      end
    end

    begin
      ret = dummyfunc2(@conn, num)
    rescue StandardError
      true.should be_true
    else
      false.should be_true # this block not be run in any case
    end
    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)
    conn2.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)

    conn2.close()
  end

  it "に、tx処理中で #release されても何も起きないこと" do
    num = @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
    @conn.run_in_transaction do |c|
      conn = Stratum.conn()
      conn.query("INSERT INTO testex1 SET oid=1,name='tagomoris',operated_by=0")
      conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)
      conn.release()

      c.owned?.should be_true
      c.in_tx?.should be_true
    end
    @conn.owned?.should be_true
    @conn.in_tx?.should be_false

    # query with un-owned connection (DANGER!)
    lambda {@conn.ping()}.should_not raise_exception(NoMethodError)
    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)
  end

  it "に、tx処理中で #close されたら例外が発生しrollbackされること" do
    num = @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i
    lambda {
      @conn.run_in_transaction do |c|
        c.query("INSERT INTO testex1 SET oid=1,name='tagomoris',operated_by=0")
        c.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num + 1)
        c.close()
      end
    }.should raise_exception(Stratum::TransactionOperationError)
    @conn.owned?.should be_true
    @conn.in_tx?.should be_false

    @conn.query("SELECT count(*) FROM testex1").fetch_hash['count(*)'].to_i.should eql(num)
    lambda {@conn.ping()}.should_not raise_exception(NoMethodError)
  end

  after (:all) do
    TestDatabase.drop()
  end
end

describe Stratum::Connection, "からプール経由でコネクションを取得したとき" do 
  before(:all) do
    TestDatabase.prepare()
    Stratum::Connection.setup(SERVERNAME, USERNAME, PASSWORD, DATABASE)
  end

  it "に、取るたびに異なる接続が開かれること" do
    conn1 = Stratum::Connection.conn()
    conn2 = Stratum::Connection.conn()
    conn3 = Stratum::Connection.conn()

    conn1.object_id.should_not equal(conn2.object_id)
    conn1.object_id.should_not equal(conn3.object_id)
    conn2.object_id.should_not equal(conn3.object_id)
    
    conn1.close()
    conn2.close()
    conn3.close()
  end
  
  it "に #release したあとで再度要求したら同じものが渡されること" do
    conn1 = Stratum::Connection.conn()
    obj_id1 = conn1.object_id
    conn1.release()

    conn2 = Stratum::Connection.conn()
    lambda {conn2.ping()}.should_not raise_exception(NoMethodError)
    conn2.object_id.should equal(obj_id1)

    conn2.close()
  end

  it "に、tx処理中は同じ接続が渡されること" do
    conn1 = Stratum::Connection.conn()
    conn1.run_in_transaction do |c1|
      conn = Stratum::Connection.conn()
      conn.object_id.should equal(c1.object_id)
    end
    conn1.close()
  end
  
  it "に、プール中の接続がすべて使用中の場合は新しく開かれた接続が渡されること" do 
    $STRATUM_CONNECTION_POOL.size.should eql(0)

    conn1 = Stratum::Connection.conn()
    conn2 = Stratum::Connection.conn()
    conn3 = Stratum::Connection.conn()
    conn2.release()
    conn2.owned?.should be_false
    
    conn4 = Stratum::Connection.conn()
    $STRATUM_CONNECTION_POOL.size.should eql(3)
    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(3)

    conn1.release()
    $STRATUM_CONNECTION_POOL.size.should eql(3)
    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(2)

    conn5 = Stratum::Connection.conn()

    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(3)

    obj_ids = $STRATUM_CONNECTION_POOL.map{|c| c.object_id}
    conn6 = Stratum::Connection.conn()

    obj_ids.should_not include(conn6.object_id)

    conn3.close()
    conn4.close()
    conn5.close()
    conn6.close()
  end

  it "に #close した接続はプールから削除されること" do
    conn1 = Stratum::Connection.conn()
    conn2 = Stratum::Connection.conn()

    $STRATUM_CONNECTION_POOL.size.should eql(2)
    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(2)
    conn2.close()
    $STRATUM_CONNECTION_POOL.size.should eql(1)
    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(1)
    conn1.close()
  end

  it "に Stratum.run_in_transaction はプールから接続を取って動作し #release して終わること" do
    $STRATUM_CONNECTION_POOL.size.should eql(0)
    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(0)

    Stratum.transaction do |conn|
      $STRATUM_CONNECTION_POOL.size.should eql(1)
      $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(1)
    end

    $STRATUM_CONNECTION_POOL.size.should eql(1)
    $STRATUM_CONNECTION_POOL.select{|c| c.owned?}.size.should eql(0)

    Stratum::Connection.conn().close()
  end

  after (:all) do
    TestDatabase.drop()
  end
end
