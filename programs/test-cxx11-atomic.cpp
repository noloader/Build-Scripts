#include <atomic>
struct A
{
    A() : x(0) {}
    std::atomic<int> x;
};

int main(int argc, char* argv[])
{
    std::atomic_flag lock = ATOMIC_FLAG_INIT;

    A a;

    while (lock.test_and_set()) {}

    a.x++; a.x--;

    lock.clear();

    return a.x;
}
