#ifndef PST_C23_H
#define PST_C23_H

/*
 * Every portable permstrap translation unit includes this header.  Checking the
 * published C23 value prevents a compiler from silently accepting selected C23
 * extensions while compiling the rest of the file in an older language mode.
 */
#if !defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L
#error                                                                                 \
    "permstrap portable code requires ISO/IEC 9899:2024 (__STDC_VERSION__ >= 202311L)"
#endif

static_assert(__STDC_VERSION__ >= 202311L,
              "the portable core must be translated as ISO C23");

/* Keep fixed-table traversal declarative and consistent at call sites. */
#define PST_ARRAY_COUNT(array) (sizeof(array) / sizeof((array)[0]))

#endif
