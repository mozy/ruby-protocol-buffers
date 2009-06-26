if IO.instance_methods.grep(/^getbyte$/).empty?
  class IO
    alias_method :getbyte, :getc
  end
end
