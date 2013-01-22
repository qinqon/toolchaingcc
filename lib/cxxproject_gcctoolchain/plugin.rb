
class SharedLibsHelper
  def symlink_lib_to(link, bb)
   file = File.basename(bb.executable_name)
   puts "f: #{file}, l: #{link}"
   if file != link 
     cd "#{bb.output_dir}/libs" do
       symlink(file, link)
     end            
   end
  end
end

class OsxSharedLibs < SharedLibsHelper
  def calc(linker, bb)
    flags = ['-install_name', bb.get_output_name(linker)]
    if bb.compatibility != nil
      flags << '-compatibility_version'
      flags << bb.compatibility
    end
    if bb.minor != nil
      flags << '-current_version'
      flags << bb.minor
    end
    flags
  end
   
  # For :major=>A, minor=>1.0.1, compatibility=>1.0.0 basic is 'libfoo.A.so'
  def get_basic_name(linker, bb)
   prefix = bb.get_output_prefix(linker)
   name = bb.name
   dylib = bb.shared_suffix linker
   return "#{prefix}#{name}#{dylib}"
  end


  # Some symbolic links
  # ln -s foo.dylib foo.A.dylib
  def post_link_hook(linker, bb)
    basic_name = get_basic_name(linker, bb)
    symlink_lib_to(basic_name, bb)
  end

  def get_version_suffix(linker, bb)
    "#{(bb.major ? ".#{bb.major}" : '')}"
  end
end

class UnixSharedLibs < SharedLibsHelper
  
  # For :major=>1, minor=>2 fullname is '1.2.so'
  def get_version_suffix(linker, bb)
    "#{major_suffix bb}#{[bb.major, bb.minor].compact.join('.')}" 
  end

  def major_suffix(bb)
    "#{(bb.major ? ".#{bb.major}" : '')}"
  end

  # For :major=>1, minor=>2 soname is 'libfoo.1.so'
  #def get_major(linker)
  # prefix = get_output_prefix(linker)
  # return "#{prefix}#{name}#{major_suffix}#{shared_suffix linker}"
  #end

  def get_soname(linker, bb)
   prefix = bb.get_output_prefix(linker)
    "#{prefix}#{bb.name}#{major_suffix bb}#{bb.shared_suffix linker}"
  end

  def calc(linker, bb)
    return ["-Wl,-soname,#{get_soname(bb,linker)}"]
  end
   
  # For :major=>1, minor=>2 fullname is 'libfoo.so'
  def get_basic_name(linker, bb)
   prefix = bb.get_output_prefix(linker)
   return "#{prefix}#{bb.name}#{bb.shared_suffix(linker)}"
  end

  # Some symbolic links
  # ln -s libfoo.so libfoo.1.2.so
  # ln -s libfoo.1.so libfoo.1.2.so
  def post_link_hook(linker, bb)
      basic_name = get_basic_name(linker, bb)
      soname = get_soname(linker, bb)
      symlink_lib_to(basic_name, bb)
      symlink_lib_to(soname, bb)
  end
end

cxx_plugin do

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
            :SHARED_FLAGS => '-fPIC',
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
        :OUTPUT_FLAG => "-o",
        :SHARED_FLAG => "-shared",
        :SONAME_FLAG => "-Wl,-soname,",
        :LIB_FLAG => "-l",
        :LIB_PATH_FLAG => "-L",
        :ERROR_PARSER => Cxxproject::GCCLinkerErrorParser.new,
        :START_OF_WHOLE_ARCHIVE => {:UNIX => '-Wl,--whole-archive', :OSX => '-force_load', :WINDOWS => '-Wl,--whole-archive'},
        :END_OF_WHOLE_ARCHIVE => {:UNIX => '-Wl,--no-whole-archive', :OSX => '', :WINDOWS => '-Wl,--no-whole-archive'},
        :ADDITIONAL_COMMANDS => {:OSX => OsxSharedLibs.new, :UNIX => UnixSharedLibs.new},
        :OUTPUT_PREFIX => {:EXE => '', :SHARED_LIBRARY => {:UNIX => 'lib', :OSX => 'lib'}},
        :ADDITIONAL_OBJECT_FILE_FLAGS => {:OSX => [], :UNIX => ['-fPIC']}
      },
    :ARCHIVER =>
      {
        :COMMAND => "ar",
        :ARCHIVE_FLAGS => "rc",
        :ERROR_PARSER => gccCompilerErrorParser
      }

end
