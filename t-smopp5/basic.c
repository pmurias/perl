#include <EXTERN.h>
#include <perl.h>
#include <smop-p5.h>

static PerlInterpreter *my_perl;

main (int argc, char **argv, char **env)
{
    STRLEN n_a;
    char *embedding[] = { "", "-e", "0" };


    PERL_SYS_INIT3(&argc,&argv,&env);
    my_perl = perl_alloc();
    perl_construct( my_perl );

    perl_parse(my_perl, NULL, 3, embedding, NULL);
    PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
    perl_run(my_perl);

    printf("1..3\n");
     
    eval_pv("printf(\"ok 1 # survived interpreter creation\n\")",TRUE);
    if (my_perl->RI == (SMOP__ResponderInterface*)SMOP__P5__interpreter__RI) {
        printf("ok 2 # interpreter RI is set\n");
    }
    eval_pv("$a = 3; $a **= 2", TRUE);
    if (get_sv("a", FALSE)->RI == (SMOP__ResponderInterface*)SMOP__P5__SV__RI) {
        printf("ok 3 # SV* RI is set\n");
    }

    perl_destruct(my_perl);
    perl_free(my_perl);
    PERL_SYS_TERM();
}

