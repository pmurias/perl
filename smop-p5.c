#include "smop-base.h"
#include "EXTERN.h"
#include "perl.h"
SMOP__Object* SMOP__P5__SV__RI;
SMOP__Object* SMOP__P5__interpreter__RI;
void smop_p5_init(void) {
    smop_interpreter_init();
}
void smop_p5_destr(void) {
    smop_interpreter_destr();
}


PP(pp_polymorphic_eval)
{
    dVAR;
    dSP;
    Perl_warn(aTHX_ "polymorphic eval\n");
    RETURN;
}
