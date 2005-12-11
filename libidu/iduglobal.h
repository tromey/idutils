#ifndef _iduglobal_h
#define _iduglobal_h

/* iduglobal.h -- global definitions for libidu
   Copyright (C) 1995, 1999, 2005 Free Software Foundation, Inc.
   Written by Claudio Fontana <sick_soul@users.sourceforge.net>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program (look for the file called COPYING).
   If not, write to the Free Software Foundation, Inc.,
        51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#ifndef offsetof
#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)
#endif

#ifndef cardinalityof
#define cardinalityof(ARRAY) (sizeof (ARRAY) / sizeof ((ARRAY)[0]))
#endif

#ifndef strequ
#define strequ(s1, s2)          (strcmp ((s1), (s2)) == 0)
#define strnequ(s1, s2, n)      (strncmp ((s1), (s2), (n)) == 0)
#endif

#ifndef obstack_chunk_alloc
#define obstack_chunk_alloc xmalloc
#endif
#ifndef obstack_chunk_free
#define obstack_chunk_free free
#endif

#define CLONE(o, t, n) ((t *) memcpy (xmalloc (sizeof(t) * (n)), (o), sizeof (t) * (n)))

#define DEBUG(args) /* printf args */

#ifndef FNM_FILE_NAME
#define FNM_FILE_NAME FNM_PATHNAME
#endif

#if HAVE_LINK
#define MAYBE_FNM_CASEFOLD 0
#else
#define MAYBE_FNM_CASEFOLD FNM_CASEFOLD
#endif

#if HAVE_LINK
#define IS_ABSOLUTE(_dir_) ((_dir_)[0] == '/')
#define SLASH_STRING "/"
#define SLASH_CHAR '/'
#define DOT_DOT_SLASH "../"
#else
/* NEEDSWORK: prefer forward-slashes as a user-configurable option.  */
#define IS_ABSOLUTE(_dir_) ((_dir_)[1] == ':')
#define SLASH_STRING "\\/"
#define SLASH_CHAR '\\'
#define DOT_DOT_SLASH "..\\"
#endif

/* vvv fix me: does not solve off_t printing problem, only a workaround vvv */

#if SIZEOF_OFF_T == SIZEOF_INT
# define OFF_FMT "%d"
#elif SIZEOF_OFF_T == SIZEOF_LONG
# define OFF_FMT "%ld"
#else
# define OFF_FMT "%lld"
#endif

#endif /* _iduglobal_h */
