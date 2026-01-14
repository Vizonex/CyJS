from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext
import os
from pathlib import Path
import sys

use_system_lib = bool(int(os.environ.get("QUICKJS_USE_SYSTEM_LIB", 0)))


QUICKJS_DIR = Path("quickjs")

quickjs_sources = list(
    map(
        str,
        [
            QUICKJS_DIR / "cutils.c",
            QUICKJS_DIR / "dtoa.c",
            QUICKJS_DIR / "libregexp.c",
            QUICKJS_DIR / "libunicode.c",
            QUICKJS_DIR / "quickjs.c",
        ],
    )
)

DEFINE_MACROS = (
    [("WIN32_LEAN_AND_MEAN", "1"), ("_WIN32_WINNT", "0x0601")]
    if sys.platform == "win32"
    else []
)
EXTRA_COMPILE_ARGS = (
    ["/std:c11", "/experimental:c11atomics"] if sys.platform == "win32" else []
)

# Added so that things can compile a bit faster (hopefully)
EXTRA_IGNORE_COMPILE_ARGS = (
    [
        "/wd4018",  # -Wno-sign-conversion
        "/wd4061",  # -Wno-implicit-fallthrough
        "/wd4100",  # -Wno-unused-parameter
        "/wd4200",  # -Wno-zero-length-array
        "/wd4242",  # -Wno-shorten-64-to-32
        "/wd4244",  # -Wno-shorten-64-to-32
        "/wd4245",  # -Wno-sign-compare
        "/wd4267",  # -Wno-shorten-64-to-32
        "/wd4388",  # -Wno-sign-compare
        "/wd4389",  # -Wno-sign-compare
        "/wd4456",  # Hides previous local declaration
        "/wd4457",  # Hides function parameter
        "/wd4710",  # Function not inlined
        "/wd4711",  # Function was inlined
        "/wd4820",  # Padding added after construct
        "/wd4996",  # -Wdeprecated-declarations
        "/wd5045",  # Compiler will insert Spectre mitigation for memory load if /Qspectre switch specified
    ]
    if sys.platform == "win32"
    else [
        # IDK How to do all these flags yet but I am reviewing CMakeLists.txt in quickjs for clues...
        "-Wno-implicit-fallthrough",
        "-Wno-sign-compare",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-but-set-variable",
        "-Wno-unused-result",
        "-Wno-stringop-truncation",
        "-Wno-array-bounds",
    ]
)

EXTRA_COMPILE_ARGS += EXTRA_IGNORE_COMPILE_ARGS


class quickjs_build_ext(build_ext):
    # Brought over from winloop since these can be very useful.

    user_options = build_ext.user_options + [
        ("cython-always", None, "run cythonize() even if .c files are present"),
        (
            "cython-annotate",
            None,
            "Produce a colorized HTML version of the Cython source.",
        ),
        ("cython-directives=", None, "Cythion compiler directives"),
    ]

    def initialize_options(self):
        self.cython_always = False
        self.cython_annotate = False
        self.cython_directives = None
        self.parallel = True
        super().initialize_options()

    # Copied from winloop
    def finalize_options(self):
        need_cythonize = self.cython_always
        cfiles = {}

        for extension in self.distribution.ext_modules:
            for i, sfile in enumerate(extension.sources):
                if sfile.endswith(".pyx"):
                    prefix, _ = os.path.splitext(sfile)
                    cfile = prefix + ".c"

                    if os.path.exists(cfile) and not self.cython_always:
                        extension.sources[i] = cfile
                    else:
                        if os.path.exists(cfile):
                            cfiles[cfile] = os.path.getmtime(cfile)
                        else:
                            cfiles[cfile] = 0
                        need_cythonize = True

        # from winloop & cyares
        if need_cythonize:
            # import pkg_resources

            # Double check Cython presence in case setup_requires
            # didn't go into effect (most likely because someone
            # imported Cython before setup_requires injected the
            # correct egg into sys.path.
            try:
                import Cython  # type: ignore  # noqa: F401
            except ImportError:
                raise RuntimeError("please install cython to compile cyjs from source")

            from Cython.Build import cythonize

            directives = {}
            if self.cython_directives:
                for directive in self.cython_directives.split(","):
                    k, _, v = directive.partition("=")
                    if v.lower() == "false":
                        v = False
                    if v.lower() == "true":
                        v = True
                    directives[k] = v
                self.cython_directives = directives

            self.distribution.ext_modules[:] = cythonize(
                self.distribution.ext_modules,
                compiler_directives=directives,
                annotate=self.cython_annotate,
                emit_linenums=self.debug,
                # Try using a cache to help with compiling as well...
                cache=True,
            )

        return super().finalize_options()


def pyx_ext(file: str):
    return Extension(
        f"cyjs.{file}",
        [f"cyjs/{file}.pyx"] + quickjs_sources,
        include_dirs=["quickjs"],
        define_macros=DEFINE_MACROS,
        # NOTE: You will need to fix stdalign.h like I did if yours didn't exist - Vizonex
        extra_compile_args=EXTRA_COMPILE_ARGS,
    )


if __name__ == "__main__":
    setup(
        ext_modules=[
            pyx_ext("_cyjs"),
        ],
        cmdclass={"build_ext": quickjs_build_ext},
    )
