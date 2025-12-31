
from setuptools import Extension, setup
from setuptools.command.build_ext import build_ext
import os
from pathlib import Path
import sys

use_system_lib = bool(int(os.environ.get("QUICKJS_USE_SYSTEM_LIB", 0)))

PARENT_DIR = Path(__file__).parent
QUICKJS_DIR = PARENT_DIR / "quickjs"

quickjs_sources = list(map(str, [
    QUICKJS_DIR / "cutils.c",
    QUICKJS_DIR / "dtoa.c",
    QUICKJS_DIR / "libregexp.c",
    QUICKJS_DIR / "libunicode.c",
    QUICKJS_DIR / "quickjs.c"
]))

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
                import Cython # type: ignore  # noqa: F401
            except ImportError:
                raise RuntimeError(
                    "please install cython to compile cyjs from source"
                )

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


def pyx_ext(file:str):
    return Extension(
        f"cyjs.{file}", 
        [f"cyjs/{file}.pyx"] + quickjs_sources, 
        include_dirs=[str(PARENT_DIR / "quickjs")],
        define_macros=[
            ('WIN32_LEAN_AND_MEAN', '1'), 
            ('_WIN32_WINNT','0x0601')] if sys.platform == "win32" else [],
        extra_compile_args=[
            "/std:c11",
            "/experimental:c11atomics"
        ] if sys.platform == "win32" else []
    )


if __name__ == "__main__":
    setup(
        ext_modules=[
            pyx_ext("cyjs"),
            pyx_ext("context"),
            pyx_ext("mem"),
            pyx_ext("runtime"),
            pyx_ext("value")
        ],
        cmdclass={"build_ext": quickjs_build_ext},
    )
