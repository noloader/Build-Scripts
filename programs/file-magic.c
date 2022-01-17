/* Written and placed in public domain by Jeffrey Walton */
/* This program prints the first four bytes of a file.   */
/* The program avoids shell portability problems by      */
/* padding short reads with 0. The program always writes */
/* four bytes to stdout. ELF is 7F454C46.                */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int main(int argc, char* argv[])
{
    int fd = -1, ret = -1;
    unsigned char vals[4];

    if (argc == 1 || (argc == 2 && argv[1][0] == '-' && argv[1][1] == '\0'))
    {
        fd = STDIN_FILENO;
    }
    else if (argc == 2)
    {
        fd = open(argv[1], O_RDONLY);
        if (fd == -1)
        {
            ret = errno;
            goto done;
        }
    }
    else
    {
        fprintf(stderr, "file-magic <fdname>\n");
        ret = EBADF;
        goto done;
    }

    vals[0] = vals[1] = vals[2] = vals[3] = 0;
    ret = read(fd, vals, 4);

    fprintf(stdout, "%02X%02X%02X%02X\n",
        vals[0], vals[1], vals[2], vals[3]);

    ret = 0;

done:

    if (fd != -1)
        close (fd);

    return ret;
}