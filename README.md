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
- Being a good companion alongside [selectolax](https://github.com/rushter/selectolax) or beautiful-soup the choice is yours...
- License friendly, after abandoning pyduktape due to the backend no longer being maintained but also having a pretty poor license all together, It inspired me to try something new for a change that could run newer HTML5 Javascript for any puzzle that is thrown your way.

## Quick Example


```python
from cyjs import Context, Runtime


def main():
    # You can also provide a runtime if needed it's usage before making multiple contexts however 
    # is completely optional
    rt = Runtime()

    ctx = Context(rt)

    ctx.eval("function add(a, b){ return a + b; }; globalThis.add = add;")
    add_func = ctx.get_global().get("add")

    # 3 
    print(add_func(1, 2))

if __name__ == "__main__":
    main()
```

Example of use with external html parser tools.

```python
from cyjs import Context
from selectolax.lexbor import LexborHTMLParser

# This example demonstates ways of cracking javascript out of webpages
# with an expernal HTML Parser and cyjs to handle the javascript logic.

# Know that A True HTML5 Dom-API Might require you to make your own 
# functions and imagination but also reverse engineering the target page.

HTML_PAGE = b"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Document</title>
</head>
<body>
<div class="captcha">
    <script>
function fake_captcha(name) {
    return name + "-key";
}
    </script>
    <!-- Use your imagination a little... -->
</div>
<div>
    <script>
    this.captcha = fake_captcha('123')    
    </script>
</div>
</body>
</html>
"""

def main():
    html = LexborHTMLParser(HTML_PAGE)
    captcha = html.css_first("div.captcha > script").text(strip=True)
    
    fake_solver = Context()
    fake_solver.eval(captcha + "\nglobalThis.fake_captcha = fake_captcha;")
    result = fake_solver.get_global().invoke("fake_captcha", "123")
    # should print
    # "123-key"
    print(result)

if __name__ == "__main__":
    main()

```

There will be more examples in a future update.





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

- [ ] Reporting and fixing bugs.

- [ ] JSCFunction I haven't figured out a good solution for this one just yet since I'm trying to limit the number of cdef classes to keep the code small and easy to compile. We need a way to bind an opaque Python Object and trying the old quickjs method seems to trigger crashes (believe me when I say I tried doing that already).

- [ ] JSClass cdef class extension that can be subclassed in python and cython along with the hooks for all the JSClassExoticMethods (we need an approch to passing off a cdef class as an opaque value which I have not figured out how to do yet)
    - [ ] JSClassFinalizer Hook
    - [ ] JSClassGCMark Hook
    - [ ] A safe approch for handling JSClass to python object conversion and vice versa (if possible)


