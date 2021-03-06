require "spec_helper"

describe "The softbin allocator" do

  before :each do
    TestIds.send(:reset)
    FileUtils.rm(f) if File.exist?(f)
  end

  def f
    "#{Origen.root}/tmp/store.json"
  end

  def a(name, options = {})
    TestIds.allocator.allocate(name, options)
    options
  end

  it "is alive" do
    TestIds.configure do |config|
      config.softbins.include << 3
      config.repo = nil
    end
    a(:t1)[:softbin].should == 3
  end

  it "softbin numbers increment" do
    TestIds.configure do |config|
      config.softbins.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t3)[:softbin].should == 3
  end

  it "duplicate tests pick up the same softbin number" do
    TestIds.configure do |config|
      config.softbins.include << (1..3)
      config.repo = nil
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t1)[:softbin].should == 1
    a(:t3)[:softbin].should == 3
  end

  it "caller can override softbin number" do
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.repo = nil
    end
    a(:t1)[:softbin].should == 1
    a(:t2, softbin: 3)[:softbin].should == 3
  end

  it "manually assigned softbins are reserved" do
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.repo = nil
    end
    a(:t1)[:softbin].should == 1
    a(:t2, softbin: 3)[:softbin].should == 3
    a(:t3)[:softbin].should == 2
    a(:t4)[:softbin].should == 4
  end

  it "excluded softbins are not used" do
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.softbins.exclude << 3
      config.repo = nil
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t3)[:softbin].should == 4
  end

  it "the system can be saved to a file and resumed" do
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.repo = f
    end
    a(:t1)[:softbin].should == 1
    a(:t2, softbin: 3)[:softbin].should == 3
    
    TestIds.allocator.save
    TestIds.send(:reset)
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.repo = f
    end
    a(:t3)[:softbin].should == 2
    a(:t4)[:softbin].should == 4
  end

  it "previously assigned manual softbins are reclaimed next time" do
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.repo = f
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t3, softbin: 2)[:softbin].should == 2
    
    TestIds.allocator.save
    TestIds.send(:reset)
    TestIds.configure do |config|
      config.softbins.include << (1..4)
      config.repo = f
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 3
    a(:t3, softbin: 2)[:softbin].should == 2
  end

  it "when all softbins are used they will be re-used oldest first" do
    TestIds.configure do |config|
      config.softbins.include << (1..3)
      config.repo = f
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t3)[:softbin].should == 3
    a(:t4)[:softbin].should == 1
    a(:t4)[:softbin].should == 1
    a(:t5)[:softbin].should == 2

    TestIds.send(:reset)
    TestIds.configure do |config|
      config.softbins.include << (1..3)
      config.repo = f
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t3)[:softbin].should == 3
    a(:t1)[:softbin].should == 1  # More recent reference makes 2 the oldest
    a(:t4)[:softbin].should == 2

    TestIds.allocator.save
    TestIds.send(:reset)
    TestIds.configure do |config|
      config.softbins.include << (1..3)
      config.repo = f
    end
    a(:t1)[:softbin].should == 1
    a(:t2)[:softbin].should == 2
    a(:t3)[:softbin].should == 3
    a(:t1)[:softbin].should == 1  # More recent reference makes 2 the oldest
    a(:t4)[:softbin].should == 2
    a(:t5)[:softbin].should == 3
  end

  it "the softbins can be generated from an algorithm" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.softbins.algorithm = :bbb000
    end
    t = a(:t1)
    t[:bin].should == 1
    t[:softbin].should == 1000
    t = a(:t2)
    t[:bin].should == 2
    t[:softbin].should == 2000
    t = a(:t3)
    t[:bin].should == 3
    t[:softbin].should == 3000
  end

  it "algorithm based softbins can include an increment counter" do
    TestIds.configure do |config|
      config.bins.include << 3
      config.softbins.algorithm = :bx
    end
    a(:t0)[:softbin].should == 30
    a(:t1)[:softbin].should == 31
    a(:t2)[:softbin].should == 32
    a(:t3)[:softbin].should == 33
    a(:t4)[:softbin].should == 34
    a(:t5)[:softbin].should == 35
    a(:t6)[:softbin].should == 36
    a(:t7)[:softbin].should == 37
    a(:t8)[:softbin].should == 38
    a(:t9)[:softbin].should == 39
    # Bump these up the reference table
    a(:t0)[:softbin].should == 30
    a(:t1)[:softbin].should == 31
    a(:t2)[:softbin].should == 32
    # The first duplicate
    a(:t10)[:softbin].should == 33
  end

  it "the softbins can be generated from a callback" do
    TestIds.configure do |config|
      config.bins.include << (1..3)
      config.softbins.callback do |bin|
        bin * 3
      end
    end
    t = a(:t1)
    t[:bin].should == 1
    t[:softbin].should == 3
    t = a(:t2)
    t[:bin].should == 2
    t[:softbin].should == 6
    t = a(:t3)
    t[:bin].should == 3
    t[:softbin].should == 9
  end
end
