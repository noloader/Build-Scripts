#include <atomic>
struct A
{
    A() : x(0) {}
    std::atomic<int> x;
};

int main(int argc, char* argv[])
{
    A a;
    a.x++; a.x--;

    return a.x;
}
