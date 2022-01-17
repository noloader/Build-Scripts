// Written and placed in public domain by Jeffrey Walton

// This program cleans up fodder in configure and
// configure.ac files. It attempts to place our $libdir
// first in the linker search path. It also understands
// Red Hat based systems, which use /lib64 and /usr/lib64.

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <cstdlib>

void usage_exit();
void process_stream(std::istream&);

std::string fix_core(std::string);
std::string fix_dlsearch_path(std::string);

int main(int argc, char* argv[])
{
    if (argc > 2)
        usage_exit();

    if (argc == 1)
    {
        process_stream(std::cin);
    }
    else
    {
        std::ifstream infile (argv[1]);
        process_stream(infile);
    }

    return 0;
}

void process_stream(std::istream& stream)
{
    std::string line;
    while (std::getline(stream, line))
    {
        line = fix_core(line);
        line = fix_dlsearch_path(line);

        std::cout << line << std::endl;
    }
}

std::string fix_core(std::string line)
{
    std::string old_val, new_val;
    std::string::size_type pos;

    old_val = "rm -f core";
    new_val = "rm -rf core";
    while ((pos = line.find(old_val)) != std::string::npos)
    {
        line.replace(pos, old_val.length(), new_val);
        pos += new_val.length();
    }

    return line;
}

std::string fix_dlsearch_path(std::string line)
{
    std::string old_val, new_val;
    std::string::size_type pos;

    old_val = "sys_lib_dlsearch_path_spec=\"/lib /usr/lib\"";
    new_val = "sys_lib_dlsearch_path_spec=\"%{_libdir} /lib /usr/lib\"";
    while ((pos = line.find(old_val)) != std::string::npos)
    {
        line.replace(pos, old_val.length(), new_val);
        pos += new_val.length();
    }

    old_val = "sys_lib_dlsearch_path_spec=\"/lib64 /usr/lib64\"";
    new_val = "sys_lib_dlsearch_path_spec=\"%{_libdir} /lib64 /usr/lib64\"";
    while ((pos = line.find(old_val)) != std::string::npos)
    {
        line.replace(pos, old_val.length(), new_val);
        pos += new_val.length();
    }

    return line;
}

void usage_exit()
{
    std::cerr << "Usage: fix-configure <pc_file>" << std::endl;
    std::cerr << "   or: cat <configure_file> | fix-configure" << std::endl;
    std::exit(1);
}
