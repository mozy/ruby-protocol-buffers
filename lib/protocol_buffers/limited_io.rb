class LimitedIO < Struct.new(:parent, :limit)

  def read(length = nil, buffer = nil)
    length = length || limit
    length = limit if length > limit
    self.limit -= length
    parent.read(length, buffer)
  end

  def eof?
    limit == 0 || parent.eof?
  end

  def getbyte
    return nil if limit == 0
    self.limit -= 1
    parent.getbyte
  end

end
