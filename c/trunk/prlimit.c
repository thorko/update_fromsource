#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/resource.h>

#define errExit(msg)     do { perror(msg); exit(EXIT_FAILURE); \
                        } while (0)

int
main(int argc, char *argv[])
{
    struct rlimit old, new;
    struct rlimit *newp;
    pid_t pid;
    int resource = 6;

    if (!(argc == 3 || argc == 4)) {
        fprintf(stderr, "Usage: %s <pid> <resource_limit RLIMIT_NPROC> [<new-soft-limit> "
                "<new-hard-limit>]\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    pid = atoi(argv[1]);        /* PID of target process */
    
    if(strcmp("nproc", argv[2]) == 0)
	resource = 6;
    else if (strcmp("core", argv[2]) == 0)
	resource = 4;
    else if (strcmp("fsize", argv[2]) == 0)
	resource = 1;
    else if (strcmp("nofile", argv[2]) == 0)
	resource = 7;
    else if (strcmp("nice", argv[2]) == 0)
	resource = 13;
    else if (strcmp("rss", argv[2]) == 0)
	resource = 5;
    else if (strcmp("locks", argv[2]) == 0)
	resource = 10;

    newp = NULL;
    if (argc == 4) {
        new.rlim_cur = atoi(argv[3]);
        new.rlim_max = atoi(argv[4]);
        newp = &new;
    }

    /* Set CPU time limit of target process; retrieve and display
       previous limit */

    if (prlimit(pid, resource,  newp, &old) == -1)
        errExit("prlimit-1");
    printf("Previous limits: soft=%lld; hard=%lld\n",
            (long long) old.rlim_cur, (long long) old.rlim_max);

    /* Retrieve and display new CPU time limit */

    if (prlimit(pid, resource, NULL, &old) == -1)
        errExit("prlimit-2");
    printf("New limits: soft=%lld; hard=%lld\n",
            (long long) old.rlim_cur, (long long) old.rlim_max);

    exit(EXIT_FAILURE);
}
