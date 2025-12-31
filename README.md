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





