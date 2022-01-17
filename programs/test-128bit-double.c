#include <stdio.h>
#include <float.h>
int main(int argc, char* argv[])
{
#if defined(__APPLE__)
	int x[1] = {LDBL_MANT_DIG};
	printf("%d\n", x[0]);
#else
	int x[-1] = {0};
#endif
	return x[0] != 0 ? 0 : 1;
}
