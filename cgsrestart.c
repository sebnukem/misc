// compile on the target system (linux) with gcc -o cgsrestart cgsrestart.c
// Usage:
//   cgsrestart [SERVICENAME [COMMAND]]
// defaults:
//   cgsrestart cgs-batch restart

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
	char cmd[99];
	if (argc > 2) snprintf(cmd, 99, "/sbin/service %s %s", argv[1], argv[2]);
	else if (argc > 1) snprintf(cmd, 99, "/sbin/service %s restart", argv[1]);
	else snprintf(cmd, 99, "/sbin/service cgs-batch restart");
	setuid(0);
	system(cmd);
	return 0;
}
