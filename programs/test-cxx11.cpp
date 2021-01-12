#include <array>
int main(int argc, char* argv[])
{
    std::array<unsigned int, 4*1024> x;
    return x[0];
}
