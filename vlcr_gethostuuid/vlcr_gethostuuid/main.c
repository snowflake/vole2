#include <stdio.h>
#include <unistd.h>
#include <uuid/uuid.h>
#include <stdlib.h>

int gethostuuid(uuid_t id, const struct timespec *wait);

int main (int argc, const char * argv[]) {
    // insert code here...
    struct timespec wait;
	char buff[37];
	char *p = buff;
	wait.tv_sec=3;
	wait.tv_nsec=0;
	uuid_t id;
	int result = gethostuuid( id , &wait);
	if(result!=0) {
		perror("vlcr_gethostuuid");
		exit(1);
	}
	uuid_unparse_upper( id, p);
	printf("%s\n",  p);
	
	
    return 0;
}
