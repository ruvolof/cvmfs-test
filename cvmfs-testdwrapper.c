#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

main( int argc, char ** argv ) {
	struct passwd *pwd;
	char user[] = "cvmfs-test";
	
	pwd = getpwnam(user);
	
    setuid(pwd->pw_uid);
    system(argv[1]);
}
