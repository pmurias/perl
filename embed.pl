#!/usr/bin/perl -w

require 5.003;	# keep this compatible, an old perl is all we may have before
                # we build the new one

BEGIN {
    # Get function prototypes
    require 'regen.pl';
}

#
# See database of global and static function prototypes in embed.fnc
# This is used to generate prototype headers under various configurations,
# export symbols lists for different platforms, and macros to provide an
# implicit interpreter context argument.
#

sub do_not_edit ($)
{
    my $file = shift;
    my $warning = <<EOW;

   $file

   Copyright (c) 1997-2002, Larry Wall

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the README file.

!!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
This file is built by embed.pl from data in embed.fnc, embed.pl,
pp.sym, intrpvar.h, perlvars.h and thrdvar.h.
Any changes made here will be lost!

Edit those files and run 'make regen_headers' to effect changes.

EOW

    if ($file =~ m:\.[ch]$:) {
	$warning =~ s:^: * :gm;
	$warning =~ s: +$::gm;
	$warning =~ s: :/:;
	$warning =~ s:$:/:;
    }
    else {
	$warning =~ s:^:# :gm;
	$warning =~ s: +$::gm;
    }
    $warning;
} # do_not_edit

open IN, "embed.fnc" or die $!;

# walk table providing an array of components in each line to
# subroutine, printing the result
sub walk_table (&@) {
    my $function = shift;
    my $filename = shift || '-';
    my $leader = shift;
    defined $leader or $leader = do_not_edit ($filename);
    my $trailer = shift;
    my $F;
    local *F;
    if (ref $filename) {	# filehandle
	$F = $filename;
    }
    else {
	safer_unlink $filename;
	open F, ">$filename" or die "Can't open $filename: $!";
	$F = \*F;
    }
    print $F $leader if $leader;
    seek IN, 0, 0;		# so we may restart
    while (<IN>) {
	chomp;
	next if /^:/;
	while (s|\\$||) {
	    $_ .= <IN>;
	    chomp;
	}
	my @args;
	if (/^\s*(#|$)/) {
	    @args = $_;
	}
	else {
	    @args = split /\s*\|\s*/, $_;
	}
        my @outs = &{$function}(@args);
        print $F @outs; # $function->(@args) is not 5.003
    }
    print $F $trailer if $trailer;
    unless (ref $filename) {
	close $F or die "Error closing $filename: $!";
    }
}

sub munge_c_files () {
    my $functions = {};
    unless (@ARGV) {
        warn "\@ARGV empty, nothing to do\n";
	return;
    }
    walk_table {
	if (@_ > 1) {
	    $functions->{$_[2]} = \@_ if $_[@_-1] =~ /\.\.\./;
	}
    } '/dev/null', '';
    local $^I = '.bak';
    while (<>) {
#	if (/^#\s*include\s+"perl.h"/) {
#	    my $file = uc $ARGV;
#	    $file =~ s/\./_/g;
#	    print "#define PERL_IN_$file\n";
#	}
#	s{^(\w+)\s*\(}
#	 {
#	    my $f = $1;
#	    my $repl = "$f(";
#	    if (exists $functions->{$f}) {
#		my $flags = $functions->{$f}[0];
#		$repl = "Perl_$repl" if $flags =~ /p/;
#		unless ($flags =~ /n/) {
#		    $repl .= "pTHX";
#		    $repl .= "_ " if @{$functions->{$f}} > 3;
#		}
#		warn("$ARGV:$.:$repl\n");
#	    }
#	    $repl;
#	 }e;
	s{(\b(\w+)[ \t]*\([ \t]*(?!aTHX))}
	 {
	    my $repl = $1;
	    my $f = $2;
	    if (exists $functions->{$f}) {
		$repl .= "aTHX_ ";
		warn("$ARGV:$.:$`#$repl#$'");
	    }
	    $repl;
	 }eg;
	print;
	close ARGV if eof;	# restart $.
    }
    exit;
}

#munge_c_files();

# generate proto.h
my $wrote_protected = 0;

sub write_protos {
    my $ret = "";
    if (@_ == 1) {
	my $arg = shift;
	$ret .= "$arg\n";
    }
    else {
	my ($flags,$retval,$func,@args) = @_;
	$ret .= '/* ' if $flags =~ /m/;
	if ($flags =~ /s/) {
	    $retval = "STATIC $retval";
	    $func = "S_$func";
	}
	else {
	    $retval = "PERL_CALLCONV $retval";
	    if ($flags =~ /p/) {
		$func = "Perl_$func";
	    }
	}
	$ret .= "$retval\t$func(";
	unless ($flags =~ /n/) {
	    $ret .= "pTHX";
	    $ret .= "_ " if @args;
	}
	if (@args) {
	    $ret .= join ", ", @args;
	}
	else {
	    $ret .= "void" if $flags =~ /n/;
	}
	$ret .= ")";
	$ret .= " __attribute__((noreturn))" if $flags =~ /r/;
	if( $flags =~ /f/ ) {
	    my $prefix = $flags =~ /n/ ? '' : 'pTHX_';
	    my $args = scalar @args;
	    $ret .= "\n#ifdef CHECK_FORMAT\n";
	    $ret .= sprintf " __attribute__((format(printf,%s%d,%s%d)))",
				    $prefix, $args - 1, $prefix, $args;
	    $ret .= "\n#endif\n";
	}
	$ret .= ";";
	$ret .= ' */' if $flags =~ /m/;
	$ret .= "\n";
    }
    $ret;
}

# generates global.sym (API export list), and populates %global with global symbols
sub write_global_sym {
    my $ret = "";
    if (@_ > 1) {
	my ($flags,$retval,$func,@args) = @_;
	if ($flags =~ /A/ && $flags !~ /[xm]/) { # public API, so export
	    $func = "Perl_$func" if $flags =~ /p/;
	    $ret = "$func\n";
	}
    }
    $ret;
}

walk_table(\&write_protos,     "proto.h", undef);
walk_table(\&write_global_sym, "global.sym", undef);

# XXX others that may need adding
#       warnhook
#       hints
#       copline
my @extvars = qw(sv_undef sv_yes sv_no na dowarn
                 curcop compiling
                 tainting tainted stack_base stack_sp sv_arenaroot
		 no_modify
                 curstash DBsub DBsingle debstash
                 rsfp
                 stdingv
		 defgv
		 errgv
		 rsfp_filters
		 perldb
		 diehook
		 dirty
		 perl_destruct_level
		 ppaddr
                );

sub readsyms (\%$) {
    my ($syms, $file) = @_;
    local (*FILE, $_);
    open(FILE, "< $file")
	or die "embed.pl: Can't open $file: $!\n";
    while (<FILE>) {
	s/[ \t]*#.*//;		# Delete comments.
	if (/^\s*(\S+)\s*$/) {
	    my $sym = $1;
	    warn "duplicate symbol $sym while processing $file\n"
		if exists $$syms{$sym};
	    $$syms{$sym} = 1;
	}
    }
    close(FILE);
}

# Perl_pp_* and Perl_ck_* are in pp.sym
readsyms my %ppsym, 'pp.sym';

sub readvars(\%$$@) {
    my ($syms, $file,$pre,$keep_pre) = @_;
    local (*FILE, $_);
    open(FILE, "< $file")
	or die "embed.pl: Can't open $file: $!\n";
    while (<FILE>) {
	s/[ \t]*#.*//;		# Delete comments.
	if (/PERLVARA?I?C?\($pre(\w+)/) {
	    my $sym = $1;
	    $sym = $pre . $sym if $keep_pre;
	    warn "duplicate symbol $sym while processing $file\n"
		if exists $$syms{$sym};
	    $$syms{$sym} = $pre || 1;
	}
    }
    close(FILE);
}

my %intrp;
my %thread;

readvars %intrp,  'intrpvar.h','I';
readvars %thread, 'thrdvar.h','T';
readvars %globvar, 'perlvars.h','G';

my $sym;
foreach $sym (sort keys %thread) {
  warn "$sym in intrpvar.h as well as thrdvar.h\n" if exists $intrp{$sym};
}

sub undefine ($) {
    my ($sym) = @_;
    "#undef  $sym\n";
}

sub hide ($$) {
    my ($from, $to) = @_;
    my $t = int(length($from) / 8);
    "#define $from" . "\t" x ($t < 3 ? 3 - $t : 1) . "$to\n";
}

sub bincompat_var ($$) {
    my ($pfx, $sym) = @_;
    my $arg = ($pfx eq 'G' ? 'NULL' : 'aTHX');
    undefine("PL_$sym") . hide("PL_$sym", "(*Perl_${pfx}${sym}_ptr($arg))");
}

sub multon ($$$) {
    my ($sym,$pre,$ptr) = @_;
    hide("PL_$sym", "($ptr$pre$sym)");
}

sub multoff ($$) {
    my ($sym,$pre) = @_;
    return hide("PL_$pre$sym", "PL_$sym");
}

safer_unlink 'embed.h';
open(EM, '> embed.h') or die "Can't create embed.h: $!\n";

print EM do_not_edit ("embed.h"), <<'END';

/* (Doing namespace management portably in C is really gross.) */

/* NO_EMBED is no longer supported. i.e. EMBED is always active. */

/* Hide global symbols */

#if !defined(PERL_IMPLICIT_CONTEXT)

END

walk_table {
    my $ret = "";
    if (@_ == 1) {
	my $arg = shift;
	$ret .= "$arg\n" if $arg =~ /^#\s*(if|ifn?def|else|endif)\b/;
    }
    else {
	my ($flags,$retval,$func,@args) = @_;
	unless ($flags =~ /[om]/) {
	    if ($flags =~ /s/) {
		$ret .= hide($func,"S_$func");
	    }
	    elsif ($flags =~ /p/) {
		$ret .= hide($func,"Perl_$func");
	    }
	}
        unless ($flags =~ /A/) {
            $ret = "#ifdef PERL_CORE\n$ret#endif\n";
        }
    }
    $ret;
} \*EM, "";

for $sym (sort keys %ppsym) {
    $sym =~ s/^Perl_//;
    print EM hide($sym, "Perl_$sym");
}

print EM <<'END';

#else	/* PERL_IMPLICIT_CONTEXT */

END

my @az = ('a'..'z');

walk_table {
    my $ret = "";
    if (@_ == 1) {
	my $arg = shift;
	$ret .= "$arg\n" if $arg =~ /^#\s*(if|ifn?def|else|endif)\b/;
    }
    else {
	my ($flags,$retval,$func,@args) = @_;
	unless ($flags =~ /[om]/) {
	    my $args = scalar @args;
	    if ($args and $args[$args-1] =~ /\.\.\./) {
	        # we're out of luck for varargs functions under CPP
	    }
	    elsif ($flags =~ /n/) {
		if ($flags =~ /s/) {
		    $ret .= hide($func,"S_$func");
		}
		elsif ($flags =~ /p/) {
		    $ret .= hide($func,"Perl_$func");
		}
	    }
	    else {
		my $alist = join(",", @az[0..$args-1]);
		$ret = "#define $func($alist)";
		my $t = int(length($ret) / 8);
		$ret .=  "\t" x ($t < 4 ? 4 - $t : 1);
		if ($flags =~ /s/) {
		    $ret .= "S_$func(aTHX";
		}
		elsif ($flags =~ /p/) {
		    $ret .= "Perl_$func(aTHX";
		}
		$ret .= "_ " if $alist;
		$ret .= $alist . ")\n";
	    }
	}
        unless ($flags =~ /A/) {
            $ret = "#ifdef PERL_CORE\n$ret#endif\n";
        }
    }
    $ret;
} \*EM, "";

for $sym (sort keys %ppsym) {
    $sym =~ s/^Perl_//;
    if ($sym =~ /^ck_/) {
	print EM hide("$sym(a)", "Perl_$sym(aTHX_ a)");
    }
    elsif ($sym =~ /^pp_/) {
	print EM hide("$sym()", "Perl_$sym(aTHX)");
    }
    else {
	warn "Illegal symbol '$sym' in pp.sym";
    }
}

print EM <<'END';

#endif	/* PERL_IMPLICIT_CONTEXT */

END

print EM <<'END';

/* Compatibility stubs.  Compile extensions with -DPERL_NOCOMPAT to
   disable them.
 */

#if !defined(PERL_CORE)
#  define sv_setptrobj(rv,ptr,name)	sv_setref_iv(rv,name,PTR2IV(ptr))
#  define sv_setptrref(rv,ptr)		sv_setref_iv(rv,Nullch,PTR2IV(ptr))
#endif

#if !defined(PERL_CORE) && !defined(PERL_NOCOMPAT)

/* Compatibility for various misnamed functions.  All functions
   in the API that begin with "perl_" (not "Perl_") take an explicit
   interpreter context pointer.
   The following are not like that, but since they had a "perl_"
   prefix in previous versions, we provide compatibility macros.
 */
#  define perl_atexit(a,b)		call_atexit(a,b)
#  define perl_call_argv(a,b,c)		call_argv(a,b,c)
#  define perl_call_pv(a,b)		call_pv(a,b)
#  define perl_call_method(a,b)		call_method(a,b)
#  define perl_call_sv(a,b)		call_sv(a,b)
#  define perl_eval_sv(a,b)		eval_sv(a,b)
#  define perl_eval_pv(a,b)		eval_pv(a,b)
#  define perl_require_pv(a)		require_pv(a)
#  define perl_get_sv(a,b)		get_sv(a,b)
#  define perl_get_av(a,b)		get_av(a,b)
#  define perl_get_hv(a,b)		get_hv(a,b)
#  define perl_get_cv(a,b)		get_cv(a,b)
#  define perl_init_i18nl10n(a)		init_i18nl10n(a)
#  define perl_init_i18nl14n(a)		init_i18nl14n(a)
#  define perl_new_ctype(a)		new_ctype(a)
#  define perl_new_collate(a)		new_collate(a)
#  define perl_new_numeric(a)		new_numeric(a)

/* varargs functions can't be handled with CPP macros. :-(
   This provides a set of compatibility functions that don't take
   an extra argument but grab the context pointer using the macro
   dTHX.
 */
#if defined(PERL_IMPLICIT_CONTEXT)
#  define croak				Perl_croak_nocontext
#  define deb				Perl_deb_nocontext
#  define die				Perl_die_nocontext
#  define form				Perl_form_nocontext
#  define load_module			Perl_load_module_nocontext
#  define mess				Perl_mess_nocontext
#  define newSVpvf			Perl_newSVpvf_nocontext
#  define sv_catpvf			Perl_sv_catpvf_nocontext
#  define sv_setpvf			Perl_sv_setpvf_nocontext
#  define warn				Perl_warn_nocontext
#  define warner			Perl_warner_nocontext
#  define sv_catpvf_mg			Perl_sv_catpvf_mg_nocontext
#  define sv_setpvf_mg			Perl_sv_setpvf_mg_nocontext
#endif

#endif /* !defined(PERL_CORE) && !defined(PERL_NOCOMPAT) */

#if !defined(PERL_IMPLICIT_CONTEXT)
/* undefined symbols, point them back at the usual ones */
#  define Perl_croak_nocontext		Perl_croak
#  define Perl_die_nocontext		Perl_die
#  define Perl_deb_nocontext		Perl_deb
#  define Perl_form_nocontext		Perl_form
#  define Perl_load_module_nocontext	Perl_load_module
#  define Perl_mess_nocontext		Perl_mess
#  define Perl_newSVpvf_nocontext	Perl_newSVpvf
#  define Perl_sv_catpvf_nocontext	Perl_sv_catpvf
#  define Perl_sv_setpvf_nocontext	Perl_sv_setpvf
#  define Perl_warn_nocontext		Perl_warn
#  define Perl_warner_nocontext		Perl_warner
#  define Perl_sv_catpvf_mg_nocontext	Perl_sv_catpvf_mg
#  define Perl_sv_setpvf_mg_nocontext	Perl_sv_setpvf_mg
#endif

END

close(EM) or die "Error closing EM: $!";

safer_unlink 'embedvar.h';
open(EM, '> embedvar.h')
    or die "Can't create embedvar.h: $!\n";

print EM do_not_edit ("embedvar.h"), <<'END';

/* (Doing namespace management portably in C is really gross.) */

/*
   The following combinations of MULTIPLICITY, USE_5005THREADS
   and PERL_IMPLICIT_CONTEXT are supported:
     1) none
     2) MULTIPLICITY	# supported for compatibility
     3) MULTIPLICITY && PERL_IMPLICIT_CONTEXT
     4) USE_5005THREADS && PERL_IMPLICIT_CONTEXT
     5) MULTIPLICITY && USE_5005THREADS && PERL_IMPLICIT_CONTEXT

   All other combinations of these flags are errors.

   #3, #4, #5, and #6 are supported directly, while #2 is a special
   case of #3 (supported by redefining vTHX appropriately).
*/

#if defined(MULTIPLICITY)
/* cases 2, 3 and 5 above */

#  if defined(PERL_IMPLICIT_CONTEXT)
#    define vTHX	aTHX
#  else
#    define vTHX	PERL_GET_INTERP
#  endif

END

for $sym (sort keys %thread) {
    print EM multon($sym,'T','vTHX->');
}

print EM <<'END';

#  if defined(USE_5005THREADS)
/* case 5 above */

END

for $sym (sort keys %intrp) {
    print EM multon($sym,'I','PERL_GET_INTERP->');
}

print EM <<'END';

#  else		/* !USE_5005THREADS */
/* cases 2 and 3 above */

END

for $sym (sort keys %intrp) {
    print EM multon($sym,'I','vTHX->');
}

print EM <<'END';

#  endif	/* USE_5005THREADS */

#else	/* !MULTIPLICITY */

/* cases 1 and 4 above */

END

for $sym (sort keys %intrp) {
    print EM multoff($sym,'I');
}

print EM <<'END';

#  if defined(USE_5005THREADS)
/* case 4 above */

END

for $sym (sort keys %thread) {
    print EM multon($sym,'T','aTHX->');
}

print EM <<'END';

#  else	/* !USE_5005THREADS */
/* case 1 above */

END

for $sym (sort keys %thread) {
    print EM multoff($sym,'T');
}

print EM <<'END';

#  endif	/* USE_5005THREADS */
#endif	/* MULTIPLICITY */

#if defined(PERL_GLOBAL_STRUCT)

END

for $sym (sort keys %globvar) {
    print EM multon($sym,'G','PL_Vars.');
}

print EM <<'END';

#else /* !PERL_GLOBAL_STRUCT */

END

for $sym (sort keys %globvar) {
    print EM multoff($sym,'G');
}

print EM <<'END';

#endif /* PERL_GLOBAL_STRUCT */

#ifdef PERL_POLLUTE		/* disabled by default in 5.6.0 */

END

for $sym (sort @extvars) {
    print EM hide($sym,"PL_$sym");
}

print EM <<'END';

#endif /* PERL_POLLUTE */
END

close(EM) or die "Error closing EM: $!";

safer_unlink 'perlapi.h';
safer_unlink 'perlapi.c';
open(CAPI, '> perlapi.c') or die "Can't create perlapi.c: $!\n";
open(CAPIH, '> perlapi.h') or die "Can't create perlapi.h: $!\n";

print CAPIH do_not_edit ("perlapi.h"), <<'EOT';

/* declare accessor functions for Perl variables */
#ifndef __perlapi_h__
#define __perlapi_h__

#if defined (MULTIPLICITY)

START_EXTERN_C

#undef PERLVAR
#undef PERLVARA
#undef PERLVARI
#undef PERLVARIC
#define PERLVAR(v,t)	EXTERN_C t* Perl_##v##_ptr(pTHX);
#define PERLVARA(v,n,t)	typedef t PL_##v##_t[n];			\
			EXTERN_C PL_##v##_t* Perl_##v##_ptr(pTHX);
#define PERLVARI(v,t,i)	PERLVAR(v,t)
#define PERLVARIC(v,t,i) PERLVAR(v, const t)

#include "thrdvar.h"
#include "intrpvar.h"
#include "perlvars.h"

#undef PERLVAR
#undef PERLVARA
#undef PERLVARI
#undef PERLVARIC

END_EXTERN_C

#if defined(PERL_CORE)

/* accessor functions for Perl variables (provide binary compatibility) */

/* these need to be mentioned here, or most linkers won't put them in
   the perl executable */

#ifndef PERL_NO_FORCE_LINK

START_EXTERN_C

#ifndef DOINIT
EXT void *PL_force_link_funcs[];
#else
EXT void *PL_force_link_funcs[] = {
#undef PERLVAR
#undef PERLVARA
#undef PERLVARI
#undef PERLVARIC
#define PERLVAR(v,t)	(void*)Perl_##v##_ptr,
#define PERLVARA(v,n,t)	PERLVAR(v,t)
#define PERLVARI(v,t,i)	PERLVAR(v,t)
#define PERLVARIC(v,t,i) PERLVAR(v,t)

#include "thrdvar.h"
#include "intrpvar.h"
#include "perlvars.h"

#undef PERLVAR
#undef PERLVARA
#undef PERLVARI
#undef PERLVARIC
};
#endif	/* DOINIT */

END_EXTERN_C

#endif	/* PERL_NO_FORCE_LINK */

#else	/* !PERL_CORE */

EOT

foreach $sym (sort keys %intrp) {
    print CAPIH bincompat_var('I',$sym);
}

foreach $sym (sort keys %thread) {
    print CAPIH bincompat_var('T',$sym);
}

foreach $sym (sort keys %globvar) {
    print CAPIH bincompat_var('G',$sym);
}

print CAPIH <<'EOT';

#endif /* !PERL_CORE */
#endif /* MULTIPLICITY */

#endif /* __perlapi_h__ */

EOT
close CAPIH or die "Error closing CAPIH: $!";

print CAPI do_not_edit ("perlapi.c"), <<'EOT';

#include "EXTERN.h"
#include "perl.h"
#include "perlapi.h"

#if defined (MULTIPLICITY)

/* accessor functions for Perl variables (provides binary compatibility) */
START_EXTERN_C

#undef PERLVAR
#undef PERLVARA
#undef PERLVARI
#undef PERLVARIC

#define PERLVAR(v,t)	t* Perl_##v##_ptr(pTHX)				\
			{ return &(aTHX->v); }
#define PERLVARA(v,n,t)	PL_##v##_t* Perl_##v##_ptr(pTHX)		\
			{ return &(aTHX->v); }

#define PERLVARI(v,t,i)	PERLVAR(v,t)
#define PERLVARIC(v,t,i) PERLVAR(v, const t)

#include "thrdvar.h"
#include "intrpvar.h"

#undef PERLVAR
#undef PERLVARA
#define PERLVAR(v,t)	t* Perl_##v##_ptr(pTHX)				\
			{ return &(PL_##v); }
#define PERLVARA(v,n,t)	PL_##v##_t* Perl_##v##_ptr(pTHX)		\
			{ return &(PL_##v); }
#undef PERLVARIC
#define PERLVARIC(v,t,i)	const t* Perl_##v##_ptr(pTHX)		\
			{ return (const t *)&(PL_##v); }
#include "perlvars.h"

#undef PERLVAR
#undef PERLVARA
#undef PERLVARI
#undef PERLVARIC

END_EXTERN_C

#endif /* MULTIPLICITY */
EOT

close(CAPI) or die "Error closing CAPI: $!";

# functions that take va_list* for implementing vararg functions
# NOTE: makedef.pl must be updated if you add symbols to %vfuncs
# XXX %vfuncs currently unused
my %vfuncs = qw(
    Perl_croak			Perl_vcroak
    Perl_warn			Perl_vwarn
    Perl_warner			Perl_vwarner
    Perl_die			Perl_vdie
    Perl_form			Perl_vform
    Perl_load_module		Perl_vload_module
    Perl_mess			Perl_vmess
    Perl_deb			Perl_vdeb
    Perl_newSVpvf		Perl_vnewSVpvf
    Perl_sv_setpvf		Perl_sv_vsetpvf
    Perl_sv_setpvf_mg		Perl_sv_vsetpvf_mg
    Perl_sv_catpvf		Perl_sv_vcatpvf
    Perl_sv_catpvf_mg		Perl_sv_vcatpvf_mg
    Perl_dump_indent		Perl_dump_vindent
    Perl_default_protect	Perl_vdefault_protect
);
