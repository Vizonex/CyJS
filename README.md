<img src="cyjs-logo.png" style="width: 30%;"/>

------
# CYJS

ECMAScript interpreter for Cython & Python built for 
- Solving & Decrypting Annoying Puzzles and Captchas at immense speeds.
- Calling upon different Javascript libraries Examples might include:
    - llparse (Even though I maintain a python version but you could easily call upon llparse from javascript using this extension)
    - yt-dlp-ejs (Decrypting challenges might take a while but that was why I wrote this library so we could start optimizing these things
    )
- Being tiny and easy to use
- Having ECMA6 Support
- Having a maintained backend (QuickJS-NG)
- Being a good companion alongside [selectolax](https://github.com/rushter/selectolax).

## NOTE
The code is still currently under construction as it's taking me a while to brainstorm how to best approch python to js value 
converstions and vice versa. as well as how `Context` varaibles should work.

## Alternative Python Javascript Interpreters

| Library | ECMA-6 Support                    | Size | Performance | Typestubs And Readability | Cython cimportable |
|---------|-----------------------------------|------|-------------|-----------|----|
|  [js2py](https://github.com/PiotrDabkowski/Js2Py)  | has to translate ECMA6 to 5 | Medium | Decent at ECMA5 and html5 scripts that use Emca-5 but starts suffering when trying to do ECMA-6 |  Lacks proper typehinting making everything into an unwanted guessing game | No and it's pure python
|  [quickjs (python library)](https://github.com/PetterS/quickjs) | Yes |  Small | Has to convert some objects back and forth but lacks typestubs and documentation | Lacks typestubs | CPython Extension that could've used a C-API Capsule to help it gain a bit of lubricant with other projects.
| pyduktape | No |  Small | somewhat fast but the backend is unmaintained and lacks proper type-hinting | None | Impossible
| pyduktape2 | No |  Small | somewhat fast but the backend is unmaintained and lacks proper type-hinting | Because this one didn't have that and my pull requests kept being laid dormant I wrote __pyduktape3__ | can't be done
| [pyduktape3](https://github.com/Vizonex/pyduktape3) | No |  Small | Very fast but the backend made by me but the C backend is unmaintained which is why the project was soon abandoned in favor of __cyjs__ | I did add typestubs to this library. | The Last cherry on top this was cimporting pyducktape3
| strv8 |  I haven't tried this one yet (Might be due to lack of windows support but I don't remeber)  |  Large due to V8  | Probably very fast becuase v8 is built by google. | I don't know, I sure hope a project like this has that. | I haven't seen the sourcecode yet...



## How to Contribute
There's a few things I didn't get to becuase they are more or less puzzles to implement than they need to be
but if anybody can figure these out feel free to fork and send a pull request along with a test added to pytest
for eatch to ensure it works correctly. I may be uploading this library to pypi after the other things are implemented but these seem more of a chore for me to solve than really anything else.

- [ ] If anybody finds a smarter approch to anything that has already been written throw me an issue or pull request.

- [ ] JSCFunction I haven't figured out a good solution for this one just yet since I'm trying to limit the number of cdef classes to keep the code small and easy to compile. We need a way to bind an opaque Python Object and trying the old quickjs method seems to trigger crashes (believe me when I say I tried doing that already).

- [ ] JSClass cdef class extension that can be subclassed in python and cython along with the hooks for all the JSClassExoticMethods (we need an approch to passing off a cdef class as an opaque value which I have not figured out how to do yet)
    - [ ] JSClassFinalizer Hook
    - [ ] JSClassGCMark Hook
    - [ ] A safe approch for handling JSClass to python object conversion and vice versa (if possible)

- [ ] A Way to cancel a Promise Object which could lead to the creation of an __aiojs library__ extension built off this library for quickjs with callbacks from Promise to asyncio.Future while taking cancellation into consideration and adding Python Coroutine Support for quickjs-ng to be able figure out how to handle correctly.
- [ ] Maybe an easier way to pass off arguments from quickjs to python functions without making the code feel like we are fluking it.
- [ ] A Way to raise python exceptions from quickjs if possible.
- [ ] Better typehinting would be a bonus if someone could pull that off.
- [ ] A couple examples would be nice. If you need inspiration or an example yt-dlp-ejs might be a good freebie.
- [ ] C Extension Modules from python functions or modules have not been implemented yet due to the same problems as JSCFunction and JSClass being more or less puzzles to bind to python than they need to be.
- [ ] If anybody can figure out a way to make JS Arrays convert to any Python array or List (Preferrably array.array if the JS Array isn't typed but a list if it is typed) Feel free to figure this out for me.

