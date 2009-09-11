#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include "smop-base.h"
/*#include <smop/capture.h>*/
#include "smop-s0native.h"
#include "smop-util.h"
#include "smop-p5.h"

static SMOP__Object* SMOP__ID__new;
static SMOP__Object* SMOP__ID__goto;
static SMOP__Object* SMOP__ID__continuation;
static SMOP__Object* SMOP__ID__eval;
static SMOP__Object* SMOP__ID__loop;
static SMOP__Object* SMOP__ID__loop;
static SMOP__Object* SMOP__ID__FETCH;




/*
 * This is the deault interpreter instance. It's important to realise
 * that this is pluggable, but there's no much thing to be different
 * right here. As this object is already delegates much of its
 * features to the "current continuation" object.
 */


/*
static void DESTROYALL(SMOP__Object* interpreter,
                              SMOP__Object* value) {
    smop_nagc_wrlock((SMOP__NAGC__Object*)value);
    SMOP__Object* cont = ((interpreter_struct*)value)->continuation;
    smop_nagc_unlock((SMOP__NAGC__Object*)value);
    if (cont) {
      SMOP_RELEASE(interpreter,cont);
    }
}
*/

/*
SMOP__Object* smop_shortcut_interpreter_goto(SMOP__Object* interpreter,SMOP__Object* invocant,SMOP__Object* continuation) {
    SMOP__Object* cont = ((interpreter_struct*)invocant)->continuation;
    if (continuation == SMOP__NATIVE__bool_false) {
      continuation = NULL;
    }
    ((interpreter_struct*)invocant)->continuation = continuation;
    if (cont) SMOP_RELEASE(interpreter,cont);
    return SMOP__NATIVE__bool_false;
}
*/
static SMOP__Object* interpreter_message(SMOP__Object* interpreter,
                                     SMOP__ResponderInterface* self,
                                     SMOP__Object* identifier,
                                     SMOP__Object* capture) {

  SMOP__Object* ret = SMOP__NATIVE__bool_false;
/*  SMOP__Object* invocant = SMOP__NATIVE__capture_positional(interpreter,capture,0);*/

  printf("calling method on p5 interpreter\n");
  if (identifier == SMOP__ID__new) {
    abort();
  } else if (identifier == SMOP__ID__goto) {
    /* goto $interpreter: $target;
     * 
     * This set the continuation of the invocant interpreter to the
     * given target. If there is a current target, it will be
     * released.
     */
    /*
    SMOP__Object* continuation = SMOP__NATIVE__capture_positional(interpreter,capture,1);
    if (continuation == SMOP__NATIVE__bool_false) {
      continuation = NULL;
    }

    smop_nagc_wrlock((SMOP__NAGC__Object*)invocant);
    SMOP__Object* cont = ((interpreter_struct*)invocant)->continuation;
    ((interpreter_struct*)invocant)->continuation = continuation;
    smop_nagc_unlock((SMOP__NAGC__Object*)invocant);
    
    if (cont) SMOP_RELEASE(interpreter,cont);
    */


  } else if (identifier == SMOP__ID__continuation) {
    /* continuation $interpreter: ;
     *
     * returns the current continuation (if there is one).
     */
    /*
    smop_nagc_rdlock((SMOP__NAGC__Object*)invocant);
    SMOP__Object* cont = ((interpreter_struct*)invocant)->continuation;
    smop_nagc_unlock((SMOP__NAGC__Object*)invocant);

    if (cont)
      ret = SMOP_REFERENCE(interpreter,cont);
    */


  } else if (identifier == SMOP__ID__loop) {
    /* loop $interpreter: ;
     *
     * Goes through the continuation while has_next.
     */

    /*
    smop_nagc_rdlock((SMOP__NAGC__Object*)invocant);
    SMOP__Object* cont = ((interpreter_struct*)invocant)->continuation;
    smop_nagc_unlock((SMOP__NAGC__Object*)invocant);

    while (cont && SMOP_DISPATCH(invocant, SMOP_RI(cont), SMOP__ID__eval,SMOP__NATIVE__capture_create(invocant,(SMOP__Object*[]) {SMOP_REFERENCE(invocant,cont), NULL}, (SMOP__Object*[]) {NULL})) == SMOP__NATIVE__bool_true) {
      smop_nagc_rdlock((SMOP__NAGC__Object*)invocant);
      if (cont != ((interpreter_struct*)invocant)->continuation) {
      }
      cont = ((interpreter_struct*)invocant)->continuation;
      smop_nagc_unlock((SMOP__NAGC__Object*)invocant);
    }
    */
  } else if (identifier == SMOP__ID__FETCH) {
    /*
    ___VALUE_FETCH___;
    */
  } else {
    /*
    ___UNKNOWN_METHOD___;
    */
  }
  /*
  SMOP_RELEASE(interpreter, invocant);
  SMOP_RELEASE(interpreter, capture);
  */
  return ret;
}


/*SMOP__Object* SMOP_interpreter_create(SMOP__Object* interpreter) {
  interpreter_struct* ret = (interpreter_struct*) smop_nagc_alloc(sizeof(interpreter_struct));
  ret->continuation = NULL;
  ret->RI = (SMOP__ResponderInterface*)RI;
  return (SMOP__Object*) ret;
}*/

void smop_interpreter_init() {

  SMOP__P5__interpreter__RI = (SMOP__ResponderInterface*) malloc(sizeof(SMOP__ResponderInterface));
  ((SMOP__ResponderInterface*)SMOP__P5__interpreter__RI)->MESSAGE = interpreter_message;
  ((SMOP__ResponderInterface*)SMOP__P5__interpreter__RI)->REFERENCE = smop_noop_reference;
  ((SMOP__ResponderInterface*)SMOP__P5__interpreter__RI)->RELEASE = smop_noop_release;
  ((SMOP__ResponderInterface*)SMOP__P5__interpreter__RI)->WEAKREF = smop_noop_weakref;
  /*
  */
  ((SMOP__ResponderInterface*)SMOP__P5__interpreter__RI)->id = "Interpreter";
  /*RI->DESTROYALL = DESTROYALL;*/

  SMOP__ID__new = SMOP__NATIVE__idconst_create("new");
  SMOP__ID__goto = SMOP__NATIVE__idconst_create("goto");
  SMOP__ID__continuation = SMOP__NATIVE__idconst_create("continuation");
  SMOP__ID__eval = SMOP__NATIVE__idconst_create("eval");
  SMOP__ID__loop = SMOP__NATIVE__idconst_create("loop");
  SMOP__ID__FETCH = SMOP__NATIVE__idconst_create("FETCH");
}

void smop_interpreter_destr() {
  free(SMOP__P5__interpreter__RI);
}
