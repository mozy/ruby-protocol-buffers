%%{

  machine proto_file;

  action mark {
    mark = p
  }

  action output_mark {
    output(data[mark ... p])
  }

  action outputS_mark {
    outputS(data[mark ... p])
  }

  action dot_to_module {
    output(dot_to_module(data[mark ... p]))
  }

  # WS includes comments too
  WS = ( ("//" (any - "\n")* "\n") | [ \t\r\n]+ )+ ;

  # only used by strLit
  # TODO: I'm fairly certain these escapes all translate correctly to ruby, but
  # I may be wrong.
  quote = ["'] ;
  hexEscape = "\\" [Xx] [A-Fa-f0-9]{1,2} ;
  octEscape = "\\" "0"? [0-7]{1,3} ;
  charEscape = "\\" [abfnrtv\\\?'"] ;
  strLit = ( quote
            ( hexEscape | octEscape | charEscape | any - [\\\0\n] - quote )*
           quote )
         >mark %output_mark ;

  decInt = ([1-9] digit*) >mark %output_mark ;
  hexInt = ("0" [xX] [A-Fa-f0-9]+) >mark %output_mark ;
  octInt = ("0" [0-7]*) >mark %output_mark ;
  intLit = decInt | hexInt - "0" | octInt ;

  # note that floatLit is a superset of decInt
  floatLit = ( [1-9] digit+ ("." digit+)? ([Ee] [\-+]? digit+)? ) >mark %output_mark ;
  numLit = floatLit | hexInt | octInt ;

  boolLit = ( "true" | "false" ) >mark %output_mark ;

  ident = ( [A-Za-z_] [A-Za-z0-9_]* )
        >{ istart = p } %{ lastIdent = data[istart ... p] }
        @err{ expected["identifier"] };
  constant = boolLit | ident | numLit | strLit ;

  package = "package" WS ident ("." ident)* WS? ";"
          @{ outputS("module #{capfirst(lastIdent)}\n"); @has_package = true };

  reqType = ( "required" | "optional" | "repeated" )
          >mark %outputS_mark %{ output " " }
          @err{ expected["required|optional|repeated"] };

  definedType = ( "double" | "float" | "int32" | "int64" | "uint32" | "uint64" | "sint32" | "sint64" | "fixed32" | "fixed64" | "sfixed32" | "sfixed64" | "bool" | "string" | "bytes" ) >mark %{ output ":" } %output_mark ;
  userType = ( "."? ( ident - definedType ) ( "." ident )* )
           >mark %dot_to_module ;
  fieldType = ( definedType | userType )
            %{ output ", " } ;

  fieldOption = ( "default" %{ output ", :default => " } ) WS? "=" WS? constant ;
  field = reqType WS fieldType WS ( ident %{ output ":#{lastIdent}, " } ) WS? "=" WS? intLit WS? ( "[" WS?  fieldOption WS? "]" )? ";" @{ output "\n" };

  message = "message" WS ident WS? "{" @{ outputS("class #{capfirst(lastIdent)} < ::Protobuf::Message\n"); @depth += 1; outputS("defined_in __FILE__\n"); fgoto messageBody; } ;

  enumField = ( ident %{ outputS(capfirst(lastIdent)) } ) WS? ( "=" %{ output " = " } ) WS? intLit WS? ";" %{ output "\n" } ;

  enum = ( "enum" WS ident WS?
    "{" @{ outputS("class #{capfirst(lastIdent)} < ::Protobuf::Enum\n"); @depth += 1; outputS("defined_in __FILE__\n"); }
    WS? ( ( enumField | ";" ) WS? )*
    "}" ) @{ @depth -= 1; outputS("end\n"); } ;

  messageBody := ( WS? ( ( field | message | enum ) WS? )* "}" )
              @{ @depth -= 1;
                 outputS("end\n");
                 if @depth > 0 then fgoto messageBody ;
                 else fgoto main;
                 end; } ;

  main := WS? ( ( package | message | enum ) WS? )* ;

}%%

class ProtoFileParser
  class ParserError < RuntimeError
  end

  attr_reader :input_name, :io

  def initialize(input_name = nil, io = $stdout)
    @input_name = input_name
    @io = io
  end

  def output(str)
    io.write str
  end

  def dot_to_module(str)
    str.gsub(".", "::")
  end

  def capfirst(str)
    str[0,1].capitalize + str[1..-1]
  end

  def outputS(str)
    io.write "  " if @has_package
    io.write "  " * @depth
    io.write str
  end

  def run_machine(data)
    %%write data;

    %%write init;
    @depth = 0
    @has_package = false
    istart = 0
    mark = 0
    eof = -1

    expected = proc do |desc|
      lines = data.split("\n")
      lp = p
      line = 0
      (lp -= lines[line].length + 1; line += 1) while lines[line].length < lp
      if desc
        str = "\n#{line}:error: expected #{desc}\n#{lines[line]}\n"
      else
        str = "\n#{line}:error: parse error\n#{lines[line]}\n"
      end
      str += " " * lp
      str += "^\n"
      raise ParserError, str
    end

    io.puts "# Generated file. Do not edit."
    if input_name
      io.puts "# <#{input_name}>"
    end
    io.puts
    io.puts "require 'protobuf/message/message'"
    io.puts "require 'protobuf/message/enum'"
    io.puts

    %%write exec;

    if cs < %%write first_final;
      expected[nil]
    end

    output "end\n" if @has_package
  end

end
