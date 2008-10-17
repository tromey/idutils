# -*-Makefile-*-
# This Makefile fragment tries to be general-purpose enough to be
# used by at least coreutils, idutils, CPPI, Bison, and Autoconf.

## Copyright (C) 2001-2008 Free Software Foundation, Inc.
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This is reported not to work with make-3.79.1
# ME := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
ME := maint.mk

# Do not save the original name or timestamp in the .tar.gz file.
# Use --rsyncable if available.
gzip_rsyncable := \
  $(shell gzip --help 2>/dev/null|grep rsyncable >/dev/null && echo --rsyncable)
GZIP_ENV = '--no-name --best $(gzip_rsyncable)'

GIT = git
VC = $(GIT)
VC-tag = git tag -s -m '$(VERSION)'

VC_LIST = $(srcdir)/build-aux/vc-list-files

VC_LIST_EXCEPT = \
  $(VC_LIST) | if test -f .x-$@; then grep -vEf .x-$@; else grep -v ChangeLog; fi

ifeq ($(origin prev_version_file), undefined)
  prev_version_file = $(srcdir)/.prev-version
endif

PREV_VERSION := $(shell cat $(prev_version_file))
VERSION_REGEXP = $(subst .,\.,$(VERSION))
PREV_VERSION_REGEXP = $(subst .,\.,$(PREV_VERSION))

ifeq ($(VC),$(GIT))
this-vc-tag = v$(VERSION)
this-vc-tag-regexp = v$(VERSION_REGEXP)
else
tag-package = $(shell echo "$(PACKAGE)" | tr '[:lower:]' '[:upper:]')
tag-this-version = $(subst .,_,$(VERSION))
this-vc-tag = $(tag-package)-$(tag-this-version)
this-vc-tag-regexp = $(this-vc-tag)
endif
my_distdir = $(PACKAGE)-$(VERSION)

# Old releases are stored here.
release_archive_dir ?= ../release

# Prevent programs like 'sort' from considering distinct strings to be equal.
# Doing it here saves us from having to set LC_ALL elsewhere in this file.
export LC_ALL = C



## --------------- ##
## Sanity checks.  ##
## --------------- ##

# Collect the names of rules starting with `sc_'.
syntax-check-rules := $(shell sed -n 's/^\(sc_[a-zA-Z0-9_-]*\):.*/\1/p' \
                        $(srcdir)/$(ME))
.PHONY: $(syntax-check-rules)

local-checks-available = \
  po-check copyright-check m4-check author_mark_check \
  patch-check strftime-check $(syntax-check-rules) \
  makefile_path_separator_check \
  makefile-check check-AUTHORS
.PHONY: $(local-checks-available)

local-check := $(filter-out $(local-checks-to-skip), $(local-checks-available))

syntax-check: $(local-check)
#	@grep -nE '#  *include <(limits|std(def|arg|bool))\.h>'		\
#	    $$(find -type f -name '*.[chly]') &&			\
#	  { echo '$(ME): found conditional include' 1>&2;		\
#	    exit 1; } || :

#	grep -nE '^#  *include <(string|stdlib)\.h>'			\
#	    $(srcdir)/{lib,src}/*.[chy] &&				\
#	  { echo '$(ME): FIXME' 1>&2;					\
#	    exit 1; } || :
# FIXME: don't allow `#include .strings\.h' anywhere

sc_avoid_if_before_free:
	@$(srcdir)/build-aux/useless-if-before-free			\
		$(useless_free_options)					\
	    $$($(VC_LIST_EXCEPT)) &&					\
	  { echo '$(ME): found useless "if" before "free" above' 1>&2;	\
	    exit 1; } || :

sc_cast_of_argument_to_free:
	@grep -nE '\<free *\( *\(' $$($(VC_LIST_EXCEPT)) &&		\
	  { echo '$(ME): don'\''t cast free argument' 1>&2;		\
	    exit 1; } || :

sc_cast_of_x_alloc_return_value:
	@grep -nE '\*\) *x(m|c|re)alloc\>' $$($(VC_LIST_EXCEPT)) &&	\
	  { echo '$(ME): don'\''t cast x*alloc return value' 1>&2;	\
	    exit 1; } || :

sc_cast_of_alloca_return_value:
	@grep -nE '\*\) *alloca\>' $$($(VC_LIST_EXCEPT)) &&		\
	  { echo '$(ME): don'\''t cast alloca return value' 1>&2;	\
	    exit 1; } || :

sc_space_tab:
	@grep -n '[ ]	' $$($(VC_LIST_EXCEPT)) &&			\
	  { echo '$(ME): found SPACE-TAB sequence; remove the SPACE'	\
		1>&2; exit 1; } || :

# Don't use *scanf or the old ato* functions in `real' code.
# They provide no error checking mechanism.
# Instead, use strto* functions.
sc_prohibit_atoi_atof:
	@grep -nE '\<([fs]?scanf|ato([filq]|ll))\>' $$($(VC_LIST_EXCEPT)) && \
	  { echo '$(ME): do not use *scan''f, ato''f, ato''i, ato''l, ato''ll, ato''q, or ss''canf'	\
		1>&2; exit 1; } || :

# Use STREQ rather than comparing strcmp == 0, or != 0.
sc_prohibit_strcmp:
	@grep -nE '! *str''cmp *\(|\<str''cmp *\([^)]+\) *=='		\
	    $$($(VC_LIST_EXCEPT)) &&					\
	  { echo '$(ME): use STREQ in place of the above uses of str''cmp' \
		1>&2; exit 1; } || :

# Using EXIT_SUCCESS as the first argument to error is misleading,
# since when that parameter is 0, error does not exit.  Use `0' instead.
sc_error_exit_success:
	@grep -nF 'error (EXIT_SUCCESS,'				\
	    $$(find -type f -name '*.[chly]') &&			\
	  { echo '$(ME): found error (EXIT_SUCCESS' 1>&2;		\
	    exit 1; } || :

# `FATAL:' should be fully upper-cased in error messages
# `WARNING:' should be fully upper-cased, or fully lower-cased
sc_error_message_warn_fatal:
	@grep -nEA2 '[^rp]error \(' $$($(VC_LIST_EXCEPT))		\
	    | grep -E '"Warning|"Fatal|"fatal' &&			\
	  { echo '$(ME): use FATAL, WARNING or warning'	1>&2;		\
	    exit 1; } || :

# Error messages should not start with a capital letter
sc_error_message_uppercase:
	@grep -nEA2 '[^rp]error \(' $$($(VC_LIST_EXCEPT))		\
	    | grep -E '"[A-Z]'						\
	    | grep -vE '"FATAL|"WARNING|"Java|"C#|PRIuMAX' &&		\
	  { echo '$(ME): found capitalized error message' 1>&2;		\
	    exit 1; } || :

# Error messages should not end with a period
sc_error_message_period:
	@grep -nEA2 '[^rp]error \(' $$($(VC_LIST_EXCEPT))		\
	    | grep -E '[^."]\."' &&					\
	  { echo '$(ME): found error message ending in period' 1>&2;	\
	    exit 1; } || :

sc_file_system:
	@grep -ni 'file''system' $$($(VC_LIST_EXCEPT)) &&		\
	  { echo '$(ME): found use of "file''system";'			\
	    'rewrite to use "file system"' 1>&2;			\
	    exit 1; } || :

# Don't use cpp tests of this symbol.  All code assumes config.h is included.
sc_no_have_config_h:
	@grep -n '^# *if.*HAVE''_CONFIG_H' $$($(VC_LIST_EXCEPT)) &&	\
	  { echo '$(ME): found use of HAVE''_CONFIG_H; remove'		\
		1>&2; exit 1; } || :

# Nearly all .c files must include <config.h>.
sc_require_config_h:
	@if $(VC_LIST_EXCEPT) | grep '\.c$$' > /dev/null; then		\
	  grep -L '^# *include <config\.h>'				\
		$$($(VC_LIST_EXCEPT) | grep '\.c$$')			\
	      | grep . &&						\
	  { echo '$(ME): the above files do not include <config.h>'	\
		1>&2; exit 1; } || :;					\
	else :;								\
	fi

# To use this "command" macro, you must first define two shell variables:
# h: the header, enclosed in <> or ""
# re: a regular expression that matches IFF something provided by $h is used.
define _header_without_use
  h_esc=`echo "$$h"|sed 's/\./\\./'`;					\
  if $(VC_LIST_EXCEPT) | grep '\.c$$' > /dev/null; then			\
    files=$$(grep -l '^# *include '"$$h_esc"				\
	     $$($(VC_LIST_EXCEPT) | grep '\.c$$')) &&			\
    grep -LE "$$re" $$files | grep . &&					\
      { echo "$(ME): the above files include $$h but don't use it"	\
	1>&2; exit 1; } || :;						\
  else :;								\
  fi
endef

# Prohibit the inclusion of assert.h without an actual use of assert.
sc_prohibit_assert_without_use:
	@h='<assert.h>' re='\<assert *\(' $(_header_without_use)

# Prohibit the inclusion of getopt.h without an actual use.
sc_prohibit_getopt_without_use:
	@h='<getopt.h>' re='\<getopt(_long)? *\(' $(_header_without_use)

# Don't include quotearg.h unless you use one of its functions.
sc_prohibit_quotearg_without_use:
	@h='"quotearg.h"' re='\<quotearg(_[^ ]+)? *\(' $(_header_without_use)

# Don't include quote.h unless you use one of its functions.
sc_prohibit_quote_without_use:
	@h='"quote.h"' re='\<quote(_n)? *\(' $(_header_without_use)

# Don't include this header unless you use one of its functions.
sc_prohibit_long_options_without_use:
	@h='"long-options.h"' re='\<parse_long_options *\(' \
	  $(_header_without_use)

# Don't include this header unless you use one of its functions.
sc_prohibit_inttostr_without_use:
	@h='"inttostr.h"' re='\<(off|[iu]max|uint)tostr *\(' \
	  $(_header_without_use)

# Don't include this header unless you use one of its functions.
sc_prohibit_error_without_use:
	@h='"error.h"' \
	re='\<error(_at_line|_print_progname|_one_per_line|_message_count)? *\('\
	  $(_header_without_use)

sc_prohibit_safe_read_without_use:
	@h='"safe-read.h"' re='(\<SAFE_READ_ERROR\>|\<safe_read *\()' \
	  $(_header_without_use)

sc_prohibit_argmatch_without_use:
	@h='"argmatch.h"' \
	re='(\<(ARRAY_CARDINALITY|X?ARGMATCH(|_TO_ARGUMENT|_VERIFY))\>|\<argmatch(_exit_fn|_(in)?valid) *\()' \
	  $(_header_without_use)

sc_prohibit_root_dev_ino_without_use:
	@h='"root-dev-ino.h"' \
	re='(\<ROOT_DEV_INO_(CHECK|WARN)\>|\<get_root_dev_ino *\()' \
	  $(_header_without_use)

sc_obsolete_symbols:
	@grep -nE '\<(HAVE''_FCNTL_H|O''_NDELAY)\>'			\
	     $$($(VC_LIST_EXCEPT)) &&					\
	  { echo '$(ME): do not use HAVE''_FCNTL_H or O''_NDELAY'	\
		1>&2; exit 1; } || :

# FIXME: warn about definitions of EXIT_FAILURE, EXIT_SUCCESS, STREQ

# Each nonempty line must start with a year number, or a TAB.
sc_changelog:
	@grep -n '^[^12	]' $$(find . -maxdepth 2 -name ChangeLog) &&	\
	  { echo '$(ME): found unexpected prefix in a ChangeLog' 1>&2;	\
	    exit 1; } || :

# Ensure that dd's definition of LONGEST_SYMBOL stays in sync
# with the strings from the two affected variables.
dd_c = $(srcdir)/src/dd.c
sc_dd_max_sym_length:
ifneq ($(wildcard $(dd_c)),)
	@len=$$( (sed -n '/conversions\[\] =$$/,/^};/p' $(dd_c);\
		 sed -n '/flags\[\] =$$/,/^};/p' $(dd_c) )	\
		|sed -n '/"/s/^[^"]*"\([^"]*\)".*/\1/p'		\
	      | wc --max-line-length);				\
	max=$$(sed -n '/^#define LONGEST_SYMBOL /s///p' $(dd_c)	\
	      |tr -d '"' | wc --max-line-length);		\
	if test "$$len" = "$$max"; then :; else			\
	  echo 'dd.c: LONGEST_SYMBOL is not longest' 1>&2;	\
	  exit 1;						\
	fi
endif

# Many m4 macros names once began with `jm_'.
# On 2004-04-13, they were all changed to start with gl_ instead.
# Make sure that none are inadvertently reintroduced.
sc_prohibit_jm_in_m4:
	@grep -nE 'jm_[A-Z]'						\
		$$($(VC_LIST) m4 |grep '\.m4$$'; echo /dev/null) &&	\
	    { echo '$(ME): do not use jm_ in m4 macro names'		\
	      1>&2; exit 1; } || :

# Ensure that each root-requiring test is run via the "check-root" rule.
sc_root_tests:
	@if test -d tests \
	      && grep check-root tests/Makefile.am>/dev/null 2>&1; then \
	t1=sc-root.expected; t2=sc-root.actual;				\
	grep -nl '^require_root_$$'					\
	  $$($(VC_LIST) tests) |sed s,tests/,, |sort > $$t1;		\
	sed -n '/^root_tests =[	 ]*\\$$/,/[^\]$$/p'			\
	  $(srcdir)/tests/Makefile.am					\
	    | sed 's/^  *//;/^root_tests =/d'				\
	    | tr -s '\012\\' '  ' | fmt -1 | sort > $$t2;		\
	diff -u $$t1 $$t2 || diff=1;					\
	rm -f $$t1 $$t2;						\
	test "$$diff"							\
	  && { echo 'tests/Makefile.am: missing check-root action'>&2;	\
	       exit 1; } || :;						\
	fi

headers_with_interesting_macro_defs = \
  exit.h	\
  fcntl_.h	\
  fnmatch_.h	\
  intprops.h	\
  inttypes_.h	\
  lchown.h	\
  openat.h	\
  stat-macros.h	\
  stdint_.h

# Create a list of regular expressions matching the names
# of macros that are guaranteed by parts of gnulib to be defined.
.re-defmac:
	@(cd $(srcdir)/lib;						\
	  for f in $(headers_with_interesting_macro_defs); do		\
	    test -f $$f &&						\
	      sed -n '/^# *define \([^_ (][^ (]*\)[ (].*/s//\1/p' $$f;	\
	   done;							\
	 ) | sort -u							\
	   | grep -Ev 'ATTRIBUTE_NORETURN|SIZE_MAX'			\
	   | sed 's/^/^# *define /'					\
	  > $@-t
	@mv $@-t $@

# Don't define macros that we already get from gnulib header files.
sc_always_defined_macros: .re-defmac
	@if test -f $(srcdir)/src/system.h; then			\
	  trap 'rc=$$?; rm -f .re-defmac; exit $$rc' 0 1 2 3 15;	\
	  grep -f .re-defmac $$($(VC_LIST))				\
	    && { echo '$(ME): define the above via some gnulib .h file'	\
		  1>&2;  exit 1; } || :;				\
	fi

# Create a list of regular expressions matching the names
# of files included from system.h.  Exclude a couple.
.re-list:
	@sed -n '/^# *include /s///p' $(srcdir)/src/system.h \
	  | grep -Ev 'sys/(param|file)\.h' \
	  | sed 's/ .*//;;s/^["<]/^# *include [<"]/;s/\.h[">]$$/\\.h[">]/' \
	  > $@-t
	@mv $@-t $@

# Files in src/ should not include directly any of
# the headers already included via system.h.
sc_system_h_headers: .re-list
	@if test -f $(srcdir)/src/system.h; then			\
	  trap 'rc=$$?; rm -f .re-list; exit $$rc' 0 1 2 3 15;		\
	  grep -nE -f .re-list						\
	      $$($(VC_LIST) src |					\
		 grep -Ev '((copy|system)\.h|parse-gram\.c)$$')		\
	    && { echo '$(ME): the above are already included via system.h'\
		  1>&2;  exit 1; } || :;				\
	fi

# Ensure that each .c file containing a "main" function also
# calls set_program_name.
sc_program_name:
	@if $(VC_LIST_EXCEPT) | grep '\.c$$' > /dev/null; then		\
	  files=$$(grep -l '^main *(' $$($(VC_LIST_EXCEPT) | grep '\.c$$')); \
	  grep -LE 'set_program_name *\(m?argv\[0\]\);' $$files		\
	      | grep . &&						\
	  { echo '$(ME): the above files do not call set_program_name'	\
		1>&2; exit 1; } || :;					\
	else :;								\
	fi

# Require that the final line of each test-lib.sh-using test be this one:
# Exit $fail
# Note: this test requires GNU grep's --label= option.
sc_require_test_exit_idiom:
	@if test -f $(srcdir)/tests/test-lib.sh; then			\
	  die=0;							\
	  for i in $$(grep -l -F /../test-lib.sh $$($(VC_LIST) tests)); do \
	    tail -n1 $$i | grep '^Exit \$$fail$$' > /dev/null \
	      && : || { die=1; echo $$i; }				\
	  done;								\
	  test $$die = 1 &&						\
	    { echo 1>&2 '$(ME): the final line in each of the above is not:'; \
	      echo 1>&2 'Exit $$fail';			\
	      exit 1; } || :;						\
	fi

sc_sun_os_names:
	@grep -nEi \
	    'solaris[^[:alnum:]]*2\.(7|8|9|[1-9][0-9])|sunos[^[:alnum:]][6-9]' \
	    $$($(VC_LIST_EXCEPT)) &&					\
	  { echo '$(ME): found misuse of Sun OS version numbers' 1>&2;	\
	    exit 1; } || :

sc_the_the:
	@grep -ni '\<the ''the\>' $$($(VC_LIST_EXCEPT)) &&		\
	  { echo '$(ME): found use of "the ''the";' 1>&2;		\
	    exit 1; } || :

sc_tight_scope:
	$(MAKE) -C src $@

sc_trailing_blank:
	@grep -n '[	 ]$$' $$($(VC_LIST_EXCEPT)) &&			\
	  { echo '$(ME): found trailing blank(s)'			\
		1>&2; exit 1; } || :

# Match lines like the following, but where there is only one space
# between the options and the description:
#   -D, --all-repeated[=delimit-method]  print all duplicate lines\n
longopt_re = --[a-z][0-9A-Za-z-]*(\[?=[0-9A-Za-z-]*\]?)?
sc_two_space_separator_in_usage:
	@grep -nE '^   *(-[A-Za-z],)? $(longopt_re) [^ ].*\\$$'		\
	    $$($(VC_LIST_EXCEPT)) &&					\
	  { echo "$(ME): help2man requires at least two spaces between"; \
	    echo "$(ME): an option and its description"; \
		1>&2; exit 1; } || :

# Look for diagnostics that aren't marked for translation.
# This won't find any for which error's format string is on a separate line.
sc_unmarked_diagnostics:
	@grep -nE							\
	    '\<error \([^"]*"[^"]*[a-z]{3}' $$($(VC_LIST_EXCEPT))	\
	  | grep -v '_''(' &&						\
	  { echo '$(ME): found unmarked diagnostic(s)' 1>&2;		\
	    exit 1; } || :

# Avoid useless parentheses like those in this example:
# #if defined (SYMBOL) || defined (SYM2)
sc_useless_cpp_parens:
	@grep -n '^# *if .*defined *(' $$($(VC_LIST_EXCEPT)) &&		\
	  { echo '$(ME): found useless parentheses in cpp directive'	\
		1>&2; exit 1; } || :

# Require the latest GPL.
sc_GPL_version:
	@grep -n 'either ''version [^3]' $$($(VC_LIST_EXCEPT)) &&	\
	  { echo '$(ME): GPL vN, N!=3' 1>&2; exit 1; } || :

# Perl-based tests used to exec perl from a #!/bin/sh script.
# Now they all start with #!/usr/bin/perl and the portability
# infrastructure is in tests/Makefile.am.  Make sure no old-style
# script sneaks back in.
sc_no_exec_perl_coreutils:
	@if test -f $(srcdir)/tests/Coreutils.pm; then			\
	  grep '^exec  *\$$PERL.*MCoreutils' $$($(VC_LIST) tests) &&	\
	    { echo 1>&2 '$(ME): found anachronistic Perl-based tests';	\
	      exit 1; } || :;						\
	fi

# Make sure we don't use st_blocks.  Use ST_NBLOCKS instead.
# This is a bit of a kludge, since it prevents use of the string
# even in comments, but for now it does the job with no false positives.
sc_prohibit_stat_st_blocks:
	@grep -nE '[.>]st_blocks' $$($(VC_LIST_EXCEPT)) && \
	  { echo '$(ME): do not use st_blocks; use ST_NBLOCKS'		\
		1>&2; exit 1; } || :

# Make sure we don't define any S_IS* macros in src/*.c files.
# They're already defined via gnulib's sys/stat.h replacement.
sc_prohibit_S_IS_definition:
	@grep -nE '^ *# *define  *S_IS' $$($(VC_LIST_EXCEPT)) &&	\
	  { echo '$(ME): do not define S_IS* macros; include <sys/stat.h>' \
		1>&2; exit 1; } || :

NEWS_hash = \
  $$(sed -n '/^\*.* $(PREV_VERSION_REGEXP) ([0-9-]*)/,$$p' \
     $(srcdir)/NEWS | md5sum -)

# Ensure that we don't accidentally insert an entry into an old NEWS block.
sc_immutable_NEWS:
	@if test -f $(srcdir)/NEWS; then				\
	  test "$(NEWS_hash)" = '$(old_NEWS_hash)' && : ||		\
	    { echo '$(ME): you have modified old NEWS' 1>&2; exit 1; };	\
	fi

# Each program that uses proper_name_utf8 must link with
# one of the ICONV libraries.
sc_proper_name_utf8_requires_ICONV:
	@progs=$$(grep -l 'proper_name_utf8 ''("' $$($(VC_LIST_EXCEPT)));\
	if test "x$$progs" != x; then					\
	  fail=0;							\
	  for p in $$progs; do						\
	    dir=$$(dirname "$$p");					\
	    base=$$(basename "$$p" .c);					\
	    grep "$${base}_LDADD.*ICONV)" $$dir/Makefile.am > /dev/null	\
	      || { fail=1; echo 1>&2 "$(ME): $$p uses proper_name_utf8"; }; \
	  done;								\
	  test $$fail = 1 &&						\
	    { echo 1>&2 '$(ME): the above do not link with any ICONV library'; \
	      exit 1; } || :;						\
	fi

# Warn about "c0nst struct Foo const foo[]",
# but not about "char const *const foo" or "#define const const".
sc_redundant_const:
	@grep -E '\bconst\b[[:space:][:alnum:]]{2,}\bconst\b'		\
		$$($(VC_LIST_EXCEPT)) &&				\
	    { echo 1>&2 '$(ME): redundant "const" in declarations';	\
	      exit 1; } || :

sc_const_long_option:
	@grep '^ *static.*struct option ' $$($(VC_LIST_EXCEPT))		\
	  | grep -Ev 'const struct option|struct option const' && {	\
	      echo 1>&2 '$(ME): add "const" to the above declarations'; \
	      exit 1; } || :

# Update the hash stored above.  Do this after each release and
# for any corrections to old entries.
update-NEWS-hash: NEWS
	perl -pi -e 's/^(old_NEWS_hash = ).*/$${1}'"$(NEWS_hash)/" \
	  $(srcdir)/cfg.mk

epoch_date = 1970-01-01 00:00:00.000000000 +0000
# Ensure that the c99-to-c89 patch applies cleanly.
patch-check:
	rm -rf src-c89 $@.1 $@.2
	cp -a $(srcdir)/src src-c89
	if test "x$(srcdir)" != x.; then \
	  cp -a src/* src-c89; \
	  dotfiles=`ls src/.[!.]* 2>/dev/null`; \
	  test -z "$$dotfiles" || cp -a src/.[!.]* src-c89; \
	fi
	(cd src-c89; patch -p1 -V never --fuzz=0) < $(srcdir)/src/c99-to-c89.diff \
	  > $@.1 2>&1
	if test "$(REGEN_PATCH)" = yes; then			\
	  diff -upr $(srcdir)/src src-c89 | sed 's,$(srcdir)/src-c89/,src/,'	\
	    | grep -vE '^(Only in|File )'			\
	    | perl -pe 's/^((?:\+\+\+|---) \S+\t).*/$${1}$(epoch_date)/;' \
	       -e 's/^ $$//'					\
	    > new-diff || : ; fi
	grep -v '^patching file ' $@.1 > $@.2 || :
	msg=ok; test -s $@.2 && msg='fuzzy patch' || : ;	\
	rm -f src-c89/*.o || msg='rm failed';			\
	$(MAKE) -C src-c89 CFLAGS='-Wdeclaration-after-statement -Werror' \
	  || msg='compile failure with extra options';		\
	test "$$msg" = ok && rm -rf src-c89 $@.1 $@.2 || echo "$$msg" 1>&2; \
	test "$$msg" = ok

# Ensure that date's --help output stays in sync with the info
# documentation for GNU strftime.  The only exception is %N,
# which date accepts but GNU strftime does not.
extract_char = sed 's/^[^%][^%]*%\(.\).*/\1/'
strftime-check:
	if test -f $(srcdir)/src/date.c; then				\
	  grep '^  %.  ' $(srcdir)/src/date.c | sort			\
	    | $(extract_char) > $@-src;					\
	  { echo N;							\
	    info libc date calendar format | grep '^    `%.'\'		\
	      | $(extract_char); } | sort > $@-info;			\
	  diff -u $@-src $@-info || exit 1;				\
	  rm -f $@-src $@-info;						\
	fi

check-AUTHORS:
	$(MAKE) -C src $@

# Ensure that we use only the standard $(VAR) notation,
# not @...@ in Makefile.am, now that we can rely on automake
# to emit a definition for each substituted variable.
# We use perl rather than "grep -nE ..." to exempt a single
# use of an @...@-delimited variable name in src/Makefile.am.
makefile-check:
	@perl -ne '/\@[A-Z_0-9]+\@/ && !/^cu_install_program =/'	\
	  -e 'and (print "$$ARGV:$$.: $$_"), $$m=1; END {exit !$$m}'	\
	    $$($(VC_LIST_EXCEPT) | grep -E '(^|/)Makefile\.am$$')	\
	  && { echo '$(ME): use $$(...), not @...@' 1>&2; exit 1; } || :

news-date-check: NEWS
	today=`date +%Y-%m-%d`;						\
	if head NEWS | grep '^\*.* $(VERSION_REGEXP) ('$$today')'	\
	    >/dev/null; then						\
	  :;								\
	else								\
	  echo "version or today's date is not in NEWS" 1>&2;		\
	  exit 1;							\
	fi

changelog-check:
	if head ChangeLog | grep 'Version $(VERSION_REGEXP)\.$$'	\
	    >/dev/null; then						\
	  :;								\
	else								\
	  echo "$(VERSION) not in ChangeLog" 1>&2;			\
	  exit 1;							\
	fi

m4-check:
	@grep -n 'AC_DEFUN([^[]' m4/*.m4 \
	  && { echo '$(ME): quote the first arg to AC_DEFUN' 1>&2; \
	       exit 1; } || :

fix_po_file_diag = \
'you have changed the set of files with translatable diagnostics;\n\
apply the above patch\n'

# Verify that all source files using _() are listed in po/POTFILES.in.
po_file = po/POTFILES.in
po-check:
	@if test -f $(po_file); then					\
	  grep -E -v '^(#|$$)' $(po_file)				\
	    | grep -v '^src/false\.c$$' | sort > $@-1;			\
	  files=;							\
	  for file in $$($(VC_LIST_EXCEPT)) lib/*.[ch]; do		\
	    case $$file in						\
	      *.?|*.??) ;;						\
	      *) continue;;						\
	    esac;							\
	    case $$file in						\
	    *.[ch])							\
	      base=`expr " $$file" : ' \(.*\)\..'`;			\
	      { test -f $$base.l || test -f $$base.y; } && continue;;	\
	    esac;							\
	    files="$$files $$file";					\
	  done;								\
	  grep -E -l '\b(N?_|gettext *)\([^)"]*("|$$)' $$files		\
	    | sort -u > $@-2;						\
	  diff -u -L $(po_file) -L $(po_file) $@-1 $@-2			\
	    || { printf '$(ME): '$(fix_po_file_diag) 1>&2; exit 1; };	\
	  rm -f $@-1 $@-2;						\
	fi

# In a definition of #define AUTHORS "... and ..." where the RHS contains
# the English word `and', the string must be marked with `N_ (...)' so that
# gettext recognizes it as a string requiring translation.
author_mark_check:
	@grep -n '^# *define AUTHORS "[^"]* and ' src/*.c |grep -v ' N_ (' && \
	  { echo '$(ME): enclose the above strings in N_ (...)' 1>&2; \
	    exit 1; } || :

# Sometimes it is useful to change the PATH environment variable
# in Makefiles.  When doing so, it's better not to use the Unix-centric
# path separator of `:', but rather the automake-provided `@PATH_SEPARATOR@'.
# It'd be better to use `find -print0 ...|xargs -0 ...', but less portable,
# and there probably aren't many projects with so many Makefile.am files
# that we'd have to worry about limits on command line length.
msg = '$(ME): Do not use `:'\'' above; use @PATH_SEPARATOR@ instead'
makefile_path_separator_check:
	@grep -n 'PATH=.*:' `find $(srcdir) -name Makefile.am` \
	  && { echo $(msg) 1>&2; exit 1; } || :

# Check that `make alpha' will not fail at the end of the process.
writable-files:
	if test -d $(release_archive_dir); then :; else			\
	  for file in $(distdir).tar.gz					\
	              $(release_archive_dir)/$(distdir).tar.gz; do	\
	    test -e $$file || continue;					\
	    test -w $$file						\
	      || { echo ERROR: $$file is not writable; fail=1; };	\
	  done;								\
	  test "$$fail" && exit 1 || : ;				\
	fi

v_etc_file = lib/version-etc.c
sample-test = tests/sample-test
texi = doc/$(PACKAGE).texi
# Make sure that the copyright date in $(v_etc_file) is up to date.
# Do the same for the $(sample-test) and the main doc/.texi file.
copyright-check:
	@if test -f $(v_etc_file); then \
	  grep 'enum { COPYRIGHT_YEAR = '$$(date +%Y)' };' $(v_etc_file) \
	    >/dev/null \
	  || { echo 'out of date copyright in $(v_etc_file); update it' 1>&2; \
	       exit 1; }; \
	fi
	@if test -f $(sample-test); then \
	  grep '# Copyright (C) '$$(date +%Y)' Free' $(sample-test) \
	    >/dev/null \
	  || { echo 'out of date copyright in $(sample-test); update it' 1>&2; \
	       exit 1; }; \
	fi
	@if test -f $(texi); then \
	  grep 'Copyright @copyright{} .*'$$(date +%Y)' Free' $(texi) \
	    >/dev/null \
	  || { echo 'out of date copyright in $(texi); update it' 1>&2; \
	       exit 1; }; \
	fi

vc-diff-check:
	$(VC) diff > vc-diffs || :
	if test -s vc-diffs; then				\
	  cat vc-diffs;						\
	  echo "Some files are locally modified:" 1>&2;		\
	  exit 1;						\
	else							\
	  rm vc-diffs;						\
	fi

cvs-check: vc-diff-check

maintainer-distcheck:
	$(MAKE) distcheck
	$(MAKE) my-distcheck


# Don't make a distribution if checks fail.
# Also, make sure the NEWS file is up-to-date.
vc-dist: $(local-check) cvs-check maintainer-distcheck
	$(MAKE) dist

# Use this to make sure we don't run these programs when building
# from a virgin tgz file, below.
null_AM_MAKEFLAGS = \
  ACLOCAL=false \
  AUTOCONF=false \
  AUTOMAKE=false \
  AUTOHEADER=false \
  MAKEINFO=false

built_programs = \
  $$(cd src && echo '_spy:;@echo $$(bin_PROGRAMS)' \
     | MAKEFLAGS= $(MAKE) -s make -f Makefile -f - _spy)

warn_cflags = -Dlint -O -Werror -Wall -Wformat -Wshadow -Wpointer-arith
bin=bin-$$$$

write_loser = printf '\#!%s\necho $$0: bad path 1>&2; exit 1\n' '$(SHELL)'

TMPDIR ?= /tmp
t=$(TMPDIR)/$(PACKAGE)/test
pfx=$(t)/i

# Verify that a twisted use of --program-transform-name=PROGRAM works.
define install-transform-check
  rm -rf $(pfx);					\
  $(MAKE) program_transform_name='s/.*/zyx/'		\
      prefix=$(pfx) install				\
    && test "$$(echo $(pfx)/bin/*)" = "$(pfx)/bin/zyx"	\
    && test "$$(echo $(pfx)/share/man/man1/*)" =	\
                    "$(pfx)/share/man/man1/zyx.1"
endef

# Install, then verify that all binaries and man pages are in place.
# Note that neither the binary, ginstall, nor the ].1 man page is installed.
define my-instcheck
  $(MAKE) prefix=$(pfx) install				\
    && test ! -f $(pfx)/bin/ginstall			\
    && { fail=0;					\
      for i in $(built_programs); do			\
        test "$$i" = ginstall && i=install;		\
        for j in "$(pfx)/bin/$$i"			\
                 "$(pfx)/share/man/man1/$$i.1"; do	\
          case $$j in *'[.1') continue;; esac;		\
          test -f "$$j" && :				\
            || { echo "$$j not installed"; fail=1; };	\
        done;						\
      done;						\
      test $$fail = 1 && exit 1 || :;			\
    }
endef

define coreutils-path-check
  {							\
    if test -f $(srcdir)/src/true.c; then		\
      fail=1;						\
      mkdir $(bin)					\
	&& ($(write_loser)) > $(bin)/loser		\
	&& chmod a+x $(bin)/loser			\
	&& for i in $(built_programs); do		\
	       case $$i in				\
		 rm|expr|basename|echo|sort|ls|tr);;	\
		 cat|dirname|mv|wc);;			\
		 *) ln $(bin)/loser $(bin)/$$i;;	\
	       esac;					\
	     done					\
	  && ln -sf ../src/true $(bin)/false		\
	  && PATH=`pwd`/$(bin):$$PATH $(MAKE) -C tests check \
	  && { test -d gnulib-tests			\
	         && $(MAKE) -C gnulib-tests check	\
	         || :; }				\
	  && rm -rf $(bin)				\
	  && fail=0;					\
    else						\
      fail=0;						\
    fi;							\
    test $$fail = 1 && exit 1 || :;			\
  }
endef

# Use -Wformat -Werror to detect format-string/arg-list mismatches.
# Also, check for shadowing problems with -Wshadow, and for pointer
# arithmetic problems with -Wpointer-arith.
# These CFLAGS are pretty strict.  If you build this target, you probably
# have to have a recent version of gcc and glibc headers.
# The hard-linking for-loop below ensures that there is a bin/ directory
# full of all of the programs under test (except the ones that are required
# for basic Makefile rules), all symlinked to the just-built "false" program.
# This is to ensure that if ever a test neglects to make PATH include
# the build srcdir, these always-failing programs will run.
# Otherwise, it is too easy to test the wrong programs.
# Note that "false" itself is a symlink to true, so it too will malfunction.
my-distcheck: $(DIST_ARCHIVES) $(local-check)
	$(MAKE) syntax-check
	$(MAKE) check
	-rm -rf $(t)
	mkdir -p $(t)
	GZIP=$(GZIP_ENV) $(AMTAR) -C $(t) -zxf $(distdir).tar.gz
	cd $(t)/$(distdir)				\
	  && ./configure --disable-nls			\
	  && $(MAKE) CFLAGS='$(warn_cflags)'		\
	      AM_MAKEFLAGS='$(null_AM_MAKEFLAGS)'	\
	  && $(MAKE) dvi				\
	  && $(install-transform-check)			\
	  && $(my-instcheck)				\
	  && $(coreutils-path-check)			\
	  && $(MAKE) distclean
	(cd $(t) && mv $(distdir) $(distdir).old	\
	  && $(AMTAR) -zxf - ) < $(distdir).tar.gz
	diff -ur $(t)/$(distdir).old $(t)/$(distdir)
	-rm -rf $(t)
	@echo "========================"; \
	echo "$(distdir).tar.gz is ready for distribution"; \
	echo "========================"

WGET = wget
WGETFLAGS = -C off

rel-check:
	tarz=/tmp/rel-check-tarz-$$$$; \
	md5_tmp=/tmp/rel-check-md5-$$$$; \
	set -e; \
	trap 'status=$$?; rm -f $$tarz $$md5_tmp; exit $$status' 0 1 2 3 15; \
	$(WGET) $(WGETFLAGS) -q --output-document=$$tarz $(url); \
	echo "$(md5)  -" > $$md5_tmp; \
	md5sum -c $$md5_tmp < $$tarz

rel-files = $(DIST_ARCHIVES)

gnulib-version = $$(cd $(gnulib_dir) && git describe)

announcement: NEWS ChangeLog $(rel-files)
	@./build-aux/announce-gen					\
	    --release-type=$(RELEASE_TYPE)				\
	    --package=$(PACKAGE)					\
	    --prev=$(PREV_VERSION)					\
	    --curr=$(VERSION)						\
	    --gpg-key-id=$(gpg_key_ID)					\
	    --news=NEWS							\
	    --bootstrap-tools=autoconf,automake,bison,gnulib		\
	    --gnulib-version=$(gnulib-version)				\
	    $(addprefix --url-dir=, $(url_dir_list))

## ---------------- ##
## Updating files.  ##
## ---------------- ##

ftp-gnu = ftp://ftp.gnu.org/gnu
www-gnu = http://www.gnu.org

# Use mv, if you don't have/want move-if-change.
move_if_change ?= move-if-change

emit_upload_commands:
	@echo =====================================
	@echo =====================================
	@echo "$(srcdir)/build-aux/gnupload $(GNUPLOADFLAGS) \\"
	@echo "    --to $(gnu_rel_host):$(PACKAGE) \\"
	@echo "  $(rel-files)"
	@echo '# send the /tmp/announcement e-mail'
	@echo =====================================
	@echo =====================================

noteworthy = * Noteworthy changes in release ?.? (????-??-??) [?]
define emit-commit-log
  printf '%s\n' 'post-release administrivia' '' \
    '* NEWS: Add header line for next release.' \
    '* .prev-version: Record previous version.' \
    '* cfg.mk (old_NEWS_hash): Auto-update.'
endef

.PHONY: alpha beta major
alpha beta major: $(local-check) writable-files
	test $@ = major						\
	  && { echo $(VERSION) | grep -E '^[0-9]+(\.[0-9]+)+$$'	\
	       || { echo "invalid version string: $(VERSION)" 1>&2; exit 1;};}\
	  || :
	$(MAKE) vc-dist
	$(MAKE) news-date-check
	$(MAKE) -s announcement RELEASE_TYPE=$@ > /tmp/announce-$(my_distdir)
	if test -d $(release_archive_dir); then			\
	  ln $(rel-files) $(release_archive_dir);		\
	  chmod a-w $(rel-files);				\
	fi
	$(MAKE) -s emit_upload_commands RELEASE_TYPE=$@
	echo $(VERSION) > $(prev_version_file)
	$(MAKE) update-NEWS-hash
	perl -pi -e '$$. == 3 and print "$(noteworthy)\n\n\n"' NEWS
	$(emit-commit-log) > .ci-msg
	$(VC) commit -F .ci-msg -a
