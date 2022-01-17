// Written and placed in public domain by Jeffrey Walton

// This program cleans up fodder in *.pc files. After
// cleaning Libs: and Libs.private: will only have
// libraries, and not runpaths and shared objects.

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cstdlib>
#include <cctype>

void usage_exit();
void process_stream(std::istream&);
std::string fix_options(std::string);
std::string trim_trailing(std::string);
std::string fold_path(std::string);
bool read_continued_line(std::istream&, std::string&);

std::string get_prefix(const std::vector<std::string>&);
void fold_prefix(const std::string&, std::vector<std::string>&);

inline char last_char(const std::string& str)
{
    if (str.empty()) {
        return '\0';
    }

    return *(str.end()-1);
}

inline std::string rm_last_char(const std::string& str)
{
    if (str.empty())
        return str;

    return std::string(str.begin(), str.end()-1);
}

// do we want to handle Solaris here? Solaris uses
// /usr/local/lib/32 and /usr/local/lib/64. The 32 and 64
// are links to an arch, like i386, amd64 and sparcv9.
inline std::string fold_path(std::string str)
{
    std::string::size_type pos = 0;
    while ((pos = str.find("lib/../lib", pos)) != std::string::npos)
    {
        str.replace(pos, 10, "lib");
        pos += 3;
    }

    pos = 0;
    while ((pos = str.find("lib32/../lib32", pos)) != std::string::npos)
    {
        str.replace(pos, 14, "lib32");
        pos += 5;
    }

    pos = 0;
    while ((pos = str.find("lib64/../lib64", pos)) != std::string::npos)
    {
        str.replace(pos, 14, "lib64");
        pos += 5;
    }

    return str;
}

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
    std::string line, prefix;
    std::vector<std::string> accum;

    while (read_continued_line(stream, line))
    {
        accum.push_back(line);
        line.erase();
    }

    // Later we will replace an expanded prefix with ${prefix}.
    prefix = get_prefix(accum);

    // fold use of expanded ${prefix}
    fold_prefix(prefix, accum);

    // now fix the options
    for (size_t i=0; i<accum.size(); ++i)
    {
        accum[i] = fold_path(accum[i]);
        accum[i] = fix_options(accum[i]);
    }

    // output the stream
    for (size_t i=0; i<accum.size(); ++i)
        std::cout << accum[i] << std::endl;
}

// tail recursive for continued lines
bool read_continued_line(std::istream& stream, std::string& line)
{
    std::string temp;
    if (! std::getline(stream, temp))
        return false;

    temp = trim_trailing(temp);
    if (last_char(temp) == '\\')
    {
        temp = rm_last_char(temp);

        std::string next;
        if (read_continued_line(stream, next))
            temp += next;
    }

    line += temp;
    line = trim_trailing(line);

    return true;
}

std::string get_prefix(const std::vector<std::string>& accum)
{
    for (size_t i=0; i<accum.size(); ++i)
    {
        if (accum[i].substr(0, 7) == "prefix=")
        {
            return accum[i].substr(7);
        }
    }

    return "";
}

void fold_prefix(const std::string& prefix, std::vector<std::string>& accum)
{
    if (prefix.empty())
        return;

    const std::string new_prefix = "${prefix}";
    for (size_t i=0; i<accum.size(); ++i)
    {
        if (accum[i].substr(0, 7) == "prefix=")
            continue;

        std::string::size_type pos = 0;
        while ((pos = accum[i].find(prefix, pos)) != std::string::npos)
        {
            accum[i].replace(pos, prefix.length(), new_prefix);
            pos += new_prefix.length();
        }
    }

    // Remove ${prefix}/${prefix}. This shows up in a couple of *.pc files.
    for (size_t i=0; i<accum.size(); ++i)
    {
        const std::string two_prefix = "${prefix}/${prefix}";
        std::string::size_type pos = 0;

        while ((pos = accum[i].find(two_prefix, pos)) != std::string::npos)
        {
            accum[i].replace(pos, two_prefix.length(), new_prefix);
            pos += new_prefix.length();
        }
    }
}

std::string fix_options(std::string line)
{
    std::string new_line;

    if (line.substr(0, 5) == "Libs:")
        new_line = "Libs:";
    else if (line.substr(0, 13) == "Libs.private:")
        new_line = "Libs.private:";
    else
        return line;

    std::string t;
    std::istringstream stream(line);

    while (std::getline(stream, t, ' '))
    {
        if (t.empty())
            continue;

        if (t.substr(0,2) == "-l")
            new_line += std::string(" ") + t;
        else if (t.substr(0,2) == "-L")
            new_line += std::string(" ") + t;
    }

    return new_line;
}

// Guile uses continuation characters
std::string trim_trailing(std::string str)
{
    while (! str.empty() && std::isspace(last_char(str)))
    {
        str.erase(str.end()-1);
    }

    return str;
}

void usage_exit()
{
    std::cerr << "Usage: fix-pkgconfig <pc_file>" << std::endl;
    std::cerr << "   or: cat <pc_file> | fix-pkgconfig" << std::endl;
    std::exit(1);
}
