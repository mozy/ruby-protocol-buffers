class LimitedIO < Struct.new(:parent, :limit)

  def read(length = nil, buffer = nil)
    length = length || limit
    length = limit if length > limit
    self.limit -= length
    # seems silly to check for buffer, but some IO#read methods implemented in C
    # barf if you pass nil, rather than treat it as an argument that wasn't
    # passed at all.
    if buffer
      parent.read(length, buffer)
    else
      parent.read(length)
    end
  end

  def eof?
    limit == 0 || parent.eof?
  end

  def getbyte
    return nil if limit == 0
    self.limit -= 1
    parent.getbyte
  end

  def getc
    return nil if limit == 0
    self.limit -= 1
    parent.getc
  end

end
