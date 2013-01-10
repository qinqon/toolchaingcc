cxx_plugin do |cxx,bbs,log|

  require 'errorparser/gcc_compiler_error_parser'
  require 'errorparser/gcc_linker_error_parser'
  gccCompilerErrorParser = Cxxproject::GCCCompilerErrorParser.new

  prefix = ENV['USE_CCACHE'] ? 'ccache' : nil
  toolchain "gcc",
    :COMPILER =>
      {
        :CPP =>
          {
            :COMMAND => ([] << prefix << "g++").compact,
            :DEFINE_FLAG => "-D",
            :OBJECT_FILE_FLAG => "-o",
            :INCLUDE_PATH_FLAG => "-I",
            :COMPILE_FLAGS => "-c -Wall ",
            :DEP_FLAGS => "-MMD -MF ", # empty space at the end is important!
            :DEP_FLAGS_SPACE => true,
            :PREPRO_FLAGS => "-E -P",
            :ERROR_PARSER => gccCompilerErrorParser
          },
        :C =>
          {
            :BASED_ON => :CPP,
            :SOURCE_FILE_ENDINGS => [".c"],
            :COMMAND => ([] << prefix << "gcc").compact
          },
        :ASM =>
          {
            :BASED_ON => :C,
            :SOURCE_FILE_ENDINGS => [".asm", ".s", ".S"]
          }
      },
    :LINKER =>
      {
        :COMMAND => "g++",
        :SCRIPT => "-T",
        :USER_LIB_FLAG => "-l:",
        :EXE_FLAG => "-o",
        :LIB_FLAG => "-l",
        :LIB_PATH_FLAG => "-L",
        :ERROR_PARSER => Cxxproject::GCCLinkerErrorParser.new,
        :START_OF_WHOLE_ARCHIVE => {:UNIX => '-Wl,--whole-archive', :OSX => '-force_load', :WINDOWS => '-Wl,--whole-archive'},
        :END_OF_WHOLE_ARCHIVE => {:UNIX => '-Wl,--no-whole-archive', :OSX => '', :WINDOWS => '-Wl,--no-whole-archive'}
      },
    :ARCHIVER =>
      {
        :COMMAND => "ar",
        :ARCHIVE_FLAGS => "rc",
        :ERROR_PARSER => gccCompilerErrorParser
      }

end
