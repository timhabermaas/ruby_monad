class Maybe
  def self.return(v)
    Some.new(v)
  end
end

class None < Maybe
  def bind
    self
  end

  def unwrap
    raise "nope"
  end

  def ==(other)
    other.is_a?(None)
  end
end

class Some < Maybe
  def initialize(v)
    @v = v
  end

  def unwrap
    @v
  end

  def bind
    yield @v
  end

  def ==(other)
    other.is_a?(Some) && other.unwrap == self.unwrap
  end
end
