// Action Click

(function () {
    const el = document.querySelector("{{ selector }}");
    let timeout = ('{{ timeout }}' === 'nil') ? 0 : Number('{{ timeout }}');
    let clickEvent = new Event('click',
        {
            bubbles: true,
            cancelable: true,
        });
    console.log(el)
    if (el) {
        if (timeout === 0) {
            el.dispatchEvent(clickEvent)
        } else {
            setTimeout(function () {
                el.dispatchEvent(clickEvent)
            }, timeout)
        }
    } else {
        console.log("no item to click")
    }
})();
