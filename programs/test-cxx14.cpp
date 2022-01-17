#include <string>
int main(int argc, char* argv[])
{
#if __cplusplus >= 201300
  int x[1] = {0};
#else
  int x[-1];
fi

  return x[0];
}
