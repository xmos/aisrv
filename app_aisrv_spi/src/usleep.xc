#include <xs1.h>

void usleep(int x) {
    timer tmr; int t;
    tmr :> t;
    tmr when timerafter(t+x*100) :> void;
}
