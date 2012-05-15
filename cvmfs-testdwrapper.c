#include <unistd.h>

main( int argc, char ** argv ) {
    setuid(geteuid());
    system(argv[1]);
}
